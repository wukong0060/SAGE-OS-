using Sage.Foundation.Contracts;

namespace Sage.Foundation.Runtime;

/// <summary>
/// Safety-oriented orchestration reference implementation.
///
/// This broker does not execute operating-system commands itself. Platform
/// adapters, durable preview storage, journal persistence, policy evaluation,
/// and approval verification must be supplied by the host application.
/// </summary>
public sealed class OperationBroker
{
    private readonly ICompatibilityGate _compatibility;
    private readonly IPolicyEvaluator _policy;
    private readonly IApprovalVerifier _approvalVerifier;
    private readonly IPreviewStore _previews;
    private readonly ITransactionJournal _journal;
    private readonly IOperationHandlerRegistry _handlers;
    private readonly IClock _clock;

    public OperationBroker(
        ICompatibilityGate compatibility,
        IPolicyEvaluator policy,
        IApprovalVerifier approvalVerifier,
        IPreviewStore previews,
        ITransactionJournal journal,
        IOperationHandlerRegistry handlers,
        IClock clock)
    {
        _compatibility = compatibility ?? throw new ArgumentNullException(nameof(compatibility));
        _policy = policy ?? throw new ArgumentNullException(nameof(policy));
        _approvalVerifier = approvalVerifier ?? throw new ArgumentNullException(nameof(approvalVerifier));
        _previews = previews ?? throw new ArgumentNullException(nameof(previews));
        _journal = journal ?? throw new ArgumentNullException(nameof(journal));
        _handlers = handlers ?? throw new ArgumentNullException(nameof(handlers));
        _clock = clock ?? throw new ArgumentNullException(nameof(clock));
    }

    public async Task<OperationResult> InspectAsync(
        OperationRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.Action != OperationAction.Inspect || request.Mode != OperationMode.ReadOnly)
            return Result(request, "rejected", "INVALID_READ_ONLY_REQUEST");

        if (!TryResolveHandler(request, out var handler))
            return Result(request, "rejected", "HANDLER_NOT_FOUND");

        var compatibility = await _compatibility.CheckAsync(request, cancellationToken);
        if (compatibility.Verdict != CompatibilityVerdict.Compatible)
            return Result(request, "incompatible", "COMPATIBILITY_NOT_CONFIRMED",
                string.Join("; ", compatibility.Reasons));

        var decision = await _policy.EvaluateAsync(
            request, compatibility, preview: null, approval: null, cancellationToken);

        if (!decision.Allowed || decision.ApprovalRequired)
            return Result(request, "denied", "POLICY_DENIED",
                string.Join("; ", decision.Reasons));

        var execution = await handler.InspectAsync(request, cancellationToken);
        return execution.Succeeded
            ? Result(request, "succeeded", execution.ResultCode, execution.Message)
            : Result(request, "failed", execution.ResultCode, execution.Message);
    }

    public async Task<OperationResult> CreatePreviewAsync(
        OperationRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.Action != OperationAction.Preview || request.Mode != OperationMode.Mutating)
            return Result(request, "rejected", "INVALID_PREVIEW_REQUEST");

        if (!TryResolveHandler(request, out var handler))
            return Result(request, "rejected", "HANDLER_NOT_FOUND");

        var compatibility = await _compatibility.CheckAsync(request, cancellationToken);
        if (compatibility.Verdict != CompatibilityVerdict.Compatible)
            return Result(request, "incompatible", "COMPATIBILITY_NOT_CONFIRMED",
                string.Join("; ", compatibility.Reasons));

        // A policy may require approval for the eventual mutation. Previewing
        // is non-mutating, so it may proceed to show the exact proposed changes.
        var preflight = await _policy.EvaluateAsync(
            request, compatibility, preview: null, approval: null, cancellationToken);

        if (!preflight.Allowed && !preflight.ApprovalRequired)
            return Result(request, "denied", "POLICY_DENIED",
                string.Join("; ", preflight.Reasons));

        var preview = await handler.CreatePreviewAsync(request, compatibility, cancellationToken);
        if (!PreviewMatchesRequest(preview, request, compatibility))
            return Result(request, "rejected", "INVALID_PREVIEW_CONTRACT");

        if (preview.ExpiresAt <= _clock.UtcNow)
            return Result(request, "rejected", "PREVIEW_ALREADY_EXPIRED");

        await _previews.SaveAsync(preview, cancellationToken);
        return new OperationResult(
            request.OperationId,
            preflight.ApprovalRequired ? "awaiting_approval" : "preview_ready",
            "PREVIEW_CREATED",
            string.Join("; ", preview.PlannedChanges),
            preview.Reference);
    }

    public async Task<OperationResult> ApplyAsync(
        OperationRequest request,
        ApprovalProof? approval,
        CancellationToken cancellationToken = default)
    {
        if (request.Action != OperationAction.Apply ||
            request.Mode != OperationMode.Mutating ||
            string.IsNullOrWhiteSpace(request.PreviewReference))
        {
            return Result(request, "rejected", "INVALID_APPLY_REQUEST");
        }

        if (!TryResolveHandler(request, out var handler))
            return Result(request, "rejected", "HANDLER_NOT_FOUND");

        var preview = await _previews.GetAsync(request.PreviewReference, cancellationToken);
        if (preview is null || !PreviewMatchesRequest(preview, request, expectedCompatibility: null))
            return Result(request, "rejected", "PREVIEW_NOT_FOUND_OR_MISMATCHED");

        if (preview.ExpiresAt <= _clock.UtcNow)
            return Result(request, "rejected", "PREVIEW_EXPIRED");

        var compatibility = await _compatibility.CheckAsync(request, cancellationToken);
        if (compatibility.Verdict != CompatibilityVerdict.Compatible)
            return Result(request, "incompatible", "COMPATIBILITY_NOT_CONFIRMED",
                string.Join("; ", compatibility.Reasons));

        // A preview is invalidated when the compatibility snapshot changes.
        if (!string.Equals(
                preview.CompatibilitySnapshotId,
                compatibility.SnapshotId,
                StringComparison.Ordinal))
        {
            return Result(request, "rejected", "PREVIEW_STALE_COMPATIBILITY");
        }

        if (approval is not null)
        {
            if (approval.OperationId != request.OperationId ||
                !string.Equals(approval.FeatureId, request.FeatureId, StringComparison.Ordinal) ||
                approval.Target != request.Target ||
                !string.Equals(approval.PreviewHash, preview.PreviewHash, StringComparison.Ordinal) ||
                approval.ExpiresAt <= _clock.UtcNow ||
                !approval.ApprovedScopes.Contains(request.Target.Scope, StringComparer.Ordinal) ||
                !await _approvalVerifier.VerifyAsync(approval, request, preview, cancellationToken))
            {
                return Result(request, "denied", "APPROVAL_INVALID");
            }
        }

        var decision = await _policy.EvaluateAsync(
            request, compatibility, preview, approval, cancellationToken);

        if (!decision.Allowed ||
            (decision.ApprovalRequired && (!decision.ApprovalGranted || approval is null)))
        {
            return Result(request, "denied", "POLICY_DENIED",
                string.Join("; ", decision.Reasons));
        }

        // Consume exactly once immediately before durable preparation. The
        // repository implementation must make this operation atomic.
        if (!await _previews.ConsumeAsync(preview.Reference, cancellationToken))
            return Result(request, "rejected", "PREVIEW_ALREADY_CONSUMED");

        // Durable preparation must finish before the handler can mutate state.
        await _journal.PrepareAsync(request, preview, cancellationToken);

        try
        {
            await _journal.MarkRunningAsync(request.OperationId, cancellationToken);

            var execution = await handler.ApplyAsync(request, preview, cancellationToken);
            if (!execution.Succeeded)
            {
                return await RollbackAfterFailureAsync(
                    request, preview, handler, execution.ResultCode, execution.Message);
            }

            var verification = await handler.VerifyAsync(request, preview, cancellationToken);
            if (!verification.Verified)
            {
                return await RollbackAfterFailureAsync(
                    request, preview, handler, verification.ResultCode, verification.Message);
            }

            await _journal.MarkCommittedAsync(request.OperationId, cancellationToken);
            return Result(request, "succeeded", "OPERATION_VERIFIED", verification.Message,
                preview.Reference);
        }
        catch (Exception exception) when (exception is not StackOverflowException)
        {
            // Once prepared, failure/cancellation must attempt compensation.
            return await RollbackAfterFailureAsync(
                request,
                preview,
                handler,
                exception is OperationCanceledException ? "OPERATION_CANCELLED" : "EXECUTOR_EXCEPTION",
                exception.Message);
        }
    }

    private async Task<OperationResult> RollbackAfterFailureAsync(
        OperationRequest request,
        OperationPreview preview,
        IOperationHandler handler,
        string failureCode,
        string? failureMessage)
    {
        try
        {
            await _journal.MarkRollbackRequiredAsync(
                request.OperationId, failureCode, CancellationToken.None);
            await _journal.MarkRollbackStartedAsync(request.OperationId, CancellationToken.None);

            var rollback = await handler.RollbackAsync(
                request, preview, CancellationToken.None);

            if (rollback.Verified)
            {
                await _journal.MarkRolledBackAsync(request.OperationId, CancellationToken.None);
                return Result(request, "rolled_back", failureCode, failureMessage,
                    preview.Reference);
            }

            await _journal.MarkRecoveryIncompleteAsync(
                request.OperationId, rollback.ResultCode, CancellationToken.None);
            return Result(request, "recovery_incomplete", "ROLLBACK_NOT_VERIFIED",
                rollback.Message ?? failureMessage, preview.Reference);
        }
        catch (Exception rollbackException) when (rollbackException is not StackOverflowException)
        {
            try
            {
                await _journal.MarkRecoveryIncompleteAsync(
                    request.OperationId, rollbackException.Message, CancellationToken.None);
            }
            catch
            {
                // Preserve the original recovery failure in the returned result.
            }

            return Result(request, "recovery_incomplete", "ROLLBACK_EXCEPTION",
                rollbackException.Message, preview.Reference);
        }
    }

    private bool TryResolveHandler(
        OperationRequest request,
        out IOperationHandler handler)
    {
        if (!string.IsNullOrWhiteSpace(request.FeatureId) &&
            _handlers.TryGet(request.FeatureId, out var found) &&
            found is not null &&
            string.Equals(found.FeatureId, request.FeatureId, StringComparison.Ordinal))
        {
            handler = found;
            return true;
        }

        handler = null!;
        return false;
    }

    private static bool PreviewMatchesRequest(
        OperationPreview preview,
        OperationRequest request,
        CompatibilityResult? expectedCompatibility)
    {
        return preview.OperationId == request.OperationId &&
               string.Equals(preview.FeatureId, request.FeatureId, StringComparison.Ordinal) &&
               preview.Target == request.Target &&
               !string.IsNullOrWhiteSpace(preview.Reference) &&
               !string.IsNullOrWhiteSpace(preview.PreviewHash) &&
               (expectedCompatibility is null ||
                string.Equals(
                    preview.CompatibilitySnapshotId,
                    expectedCompatibility.SnapshotId,
                    StringComparison.Ordinal));
    }

    private static OperationResult Result(
        OperationRequest request,
        string state,
        string code,
        string? message = null,
        string? previewReference = null) =>
        new(request.OperationId, state, code, message, previewReference);
}
