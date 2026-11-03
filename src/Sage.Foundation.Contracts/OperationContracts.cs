namespace Sage.Foundation.Contracts;

public enum OperationAction
{
    Inspect,
    Preview,
    Apply
}

public enum OperationMode
{
    ReadOnly,
    Mutating
}

public enum RiskTier
{
    None,
    Low,
    Medium,
    High,
    Critical
}

public enum CompatibilityVerdict
{
    Compatible,
    Incompatible,
    Unknown
}

public sealed record OperationCaller(string CoreId, string SuiteId);

public sealed record OperationTarget(
    string Scope,
    string Resource,
    string? ResourceId = null);

public sealed record OperationRequest(
    Guid OperationId,
    string FeatureId,
    OperationCaller Caller,
    OperationAction Action,
    OperationMode Mode,
    OperationTarget Target,
    RiskTier RiskTier,
    string? PreviewReference = null);

public sealed record CompatibilityResult(
    CompatibilityVerdict Verdict,
    string SnapshotId,
    IReadOnlyList<string> Reasons);

public sealed record OperationPreview(
    string Reference,
    Guid OperationId,
    string FeatureId,
    OperationTarget Target,
    string CompatibilitySnapshotId,
    string PreviewHash,
    DateTimeOffset ExpiresAt,
    IReadOnlyList<string> PlannedChanges);

public sealed record ApprovalProof(
    string ActorId,
    string PreviewHash,
    DateTimeOffset ExpiresAt,
    IReadOnlyList<string> ApprovedScopes);

public sealed record PolicyDecision(
    bool Allowed,
    bool ApprovalRequired,
    bool ApprovalGranted,
    IReadOnlyList<string> Reasons);

public sealed record OperationExecution(
    bool Succeeded,
    string ResultCode,
    string? Message = null);

public sealed record OperationVerification(
    bool Verified,
    string ResultCode,
    string? Message = null);

public sealed record OperationResult(
    Guid OperationId,
    string State,
    string ResultCode,
    string? Message = null,
    string? PreviewReference = null);

public interface IClock
{
    DateTimeOffset UtcNow { get; }
}

public interface ICompatibilityGate
{
    Task<CompatibilityResult> CheckAsync(
        OperationRequest request,
        CancellationToken cancellationToken);
}

public interface IPolicyEvaluator
{
    Task<PolicyDecision> EvaluateAsync(
        OperationRequest request,
        CompatibilityResult compatibility,
        OperationPreview? preview,
        ApprovalProof? approval,
        CancellationToken cancellationToken);
}

public interface IApprovalVerifier
{
    Task<bool> VerifyAsync(
        ApprovalProof proof,
        OperationRequest request,
        OperationPreview preview,
        CancellationToken cancellationToken);
}

public interface IPreviewStore
{
    Task SaveAsync(OperationPreview preview, CancellationToken cancellationToken);

    Task<OperationPreview?> GetAsync(
        string reference,
        CancellationToken cancellationToken);
}

public interface ITransactionJournal
{
    Task PrepareAsync(
        OperationRequest request,
        OperationPreview preview,
        CancellationToken cancellationToken);

    Task MarkRunningAsync(Guid operationId, CancellationToken cancellationToken);

    Task MarkCommittedAsync(Guid operationId, CancellationToken cancellationToken);

    Task MarkRollbackRequiredAsync(
        Guid operationId,
        string reason,
        CancellationToken cancellationToken);

    Task MarkRollbackStartedAsync(Guid operationId, CancellationToken cancellationToken);

    Task MarkRolledBackAsync(Guid operationId, CancellationToken cancellationToken);

    Task MarkRecoveryIncompleteAsync(
        Guid operationId,
        string reason,
        CancellationToken cancellationToken);
}

public interface IOperationHandler
{
    string FeatureId { get; }

    Task<OperationExecution> InspectAsync(
        OperationRequest request,
        CancellationToken cancellationToken);

    Task<OperationPreview> CreatePreviewAsync(
        OperationRequest request,
        CompatibilityResult compatibility,
        CancellationToken cancellationToken);

    Task<OperationExecution> ApplyAsync(
        OperationRequest request,
        OperationPreview preview,
        CancellationToken cancellationToken);

    Task<OperationVerification> VerifyAsync(
        OperationRequest request,
        OperationPreview preview,
        CancellationToken cancellationToken);

    Task<OperationVerification> RollbackAsync(
        OperationRequest request,
        OperationPreview preview,
        CancellationToken cancellationToken);
}

public interface IOperationHandlerRegistry
{
    bool TryGet(string featureId, out IOperationHandler? handler);
}
