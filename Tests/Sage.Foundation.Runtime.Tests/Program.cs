using Sage.Foundation.Contracts;
using Sage.Foundation.Runtime;

var suite = new BrokerTests();
await suite.RunAsync();

sealed class BrokerTests
{
    private int _passed;

    public async Task RunAsync()
    {
        await Run("read-only inspection does not create a journal", ReadOnlyInspectionAsync);
        await Run("unknown compatibility fails closed", UnknownCompatibilityFailsClosedAsync);
        await Run("policy denial blocks preview", PolicyDenialBlocksPreviewAsync);
        await Run("approval is required before mutation", MissingApprovalBlocksApplyAsync);
        await Run("valid preview and approval allow verified apply", ValidApplyCommitsAsync);
        await Run("failed verification triggers verified rollback", VerificationFailureRollsBackAsync);
        await Run("unverified rollback reports recovery incomplete", FailedRollbackReportsIncompleteAsync);
        await Run("expired preview cannot be applied", ExpiredPreviewIsRejectedAsync);
        await Run("changed compatibility snapshot invalidates preview", StalePreviewIsRejectedAsync);
        await Run("read-only apply request is rejected", ReadOnlyApplyIsRejectedAsync);
        Console.WriteLine($"PASS: {_passed}/10 broker safety tests");
    }

    private async Task Run(string name, Func<Task> test)
    {
        await test();
        _passed++;
        Console.WriteLine($"PASS: {name}");
    }

    private async Task ReadOnlyInspectionAsync()
    {
        var env = new TestEnvironment();
        var request = env.Request(OperationAction.Inspect, OperationMode.ReadOnly);
        var result = await env.Broker.InspectAsync(request);
        Assert(result.State == "succeeded", "inspection should succeed");
        Assert(env.Handler.InspectCalls == 1, "handler should be called once");
        Assert(!env.Journal.Prepared, "read-only inspection must not create a mutation journal");
    }

    private async Task UnknownCompatibilityFailsClosedAsync()
    {
        var env = new TestEnvironment(compatibility: CompatibilityVerdict.Unknown);
        var request = env.Request(OperationAction.Preview, OperationMode.Mutating);
        var result = await env.Broker.CreatePreviewAsync(request);
        Assert(result.State == "incompatible", "unknown compatibility must not pass");
        Assert(env.Handler.PreviewCalls == 0, "handler must not create a preview");
    }

    private async Task PolicyDenialBlocksPreviewAsync()
    {
        var env = new TestEnvironment(previewDecision: new(false, false, false, ["POLICY_DENIED"]));
        var request = env.Request(OperationAction.Preview, OperationMode.Mutating);
        var result = await env.Broker.CreatePreviewAsync(request);
        Assert(result.State == "denied", "policy denial expected");
        Assert(env.Handler.PreviewCalls == 0, "denied feature must not prepare preview");
    }

    private async Task MissingApprovalBlocksApplyAsync()
    {
        var env = new TestEnvironment(
            previewDecision: new(false, true, false, ["APPROVAL_REQUIRED"]),
            applyDecision: new(false, true, false, ["APPROVAL_REQUIRED"]));
        var preview = await env.CreatePreviewAsync();
        var request = env.Request(OperationAction.Apply, OperationMode.Mutating, preview.PreviewReference);
        var result = await env.Broker.ApplyAsync(request, approval: null);
        Assert(result.State == "denied", "missing approval must be denied");
        Assert(env.Handler.ApplyCalls == 0, "handler must not mutate without approval");
        Assert(!env.Journal.Prepared, "journal should not be prepared before approval");
    }

    private async Task ValidApplyCommitsAsync()
    {
        var env = new TestEnvironment(
            previewDecision: new(false, true, false, ["APPROVAL_REQUIRED"]),
            applyDecision: new(true, true, true, []));
        var preview = await env.CreatePreviewAsync();
        var proof = env.Approval(preview);
        var request = env.Request(OperationAction.Apply, OperationMode.Mutating, preview.PreviewReference);
        var result = await env.Broker.ApplyAsync(request, proof);
        Assert(result.State == "succeeded", "verified apply should succeed");
        Assert(env.Handler.ApplyCalls == 1, "apply handler should be called once");
        Assert(env.Handler.SawPreparedJournal, "journal must be prepared before mutation");
        Assert(env.Journal.State == "committed", "journal should commit only after verification");
    }

    private async Task VerificationFailureRollsBackAsync()
    {
        var env = new TestEnvironment(
            previewDecision: new(false, true, false, ["APPROVAL_REQUIRED"]),
            applyDecision: new(true, true, true, []),
            verification: new(false, "VERIFY_FAILED", "post-apply verification failed"));
        var preview = await env.CreatePreviewAsync();
        var result = await env.Broker.ApplyAsync(
            env.Request(OperationAction.Apply, OperationMode.Mutating, preview.PreviewReference),
            env.Approval(preview));
        Assert(result.State == "rolled_back", "verified rollback should be reported");
        Assert(env.Handler.RollbackCalls == 1, "rollback should run once");
        Assert(env.Journal.State == "rolled_back", "journal should record rollback");
    }

    private async Task FailedRollbackReportsIncompleteAsync()
    {
        var env = new TestEnvironment(
            previewDecision: new(false, true, false, ["APPROVAL_REQUIRED"]),
            applyDecision: new(true, true, true, []),
            verification: new(false, "VERIFY_FAILED"),
            rollback: new(false, "RESTORE_FAILED", "could not verify restoration"));
        var preview = await env.CreatePreviewAsync();
        var result = await env.Broker.ApplyAsync(
            env.Request(OperationAction.Apply, OperationMode.Mutating, preview.PreviewReference),
            env.Approval(preview));
        Assert(result.State == "recovery_incomplete", "failed rollback must remain visible");
        Assert(env.Journal.State == "recovery_incomplete", "journal should retain incomplete state");
    }

    private async Task ExpiredPreviewIsRejectedAsync()
    {
        var env = new TestEnvironment(
            previewDecision: new(false, true, false, ["APPROVAL_REQUIRED"]),
            applyDecision: new(true, true, true, []));
        var preview = await env.CreatePreviewAsync();
        env.Clock.Advance(TimeSpan.FromMinutes(20));
        var result = await env.Broker.ApplyAsync(
            env.Request(OperationAction.Apply, OperationMode.Mutating, preview.PreviewReference),
            env.Approval(preview));
        Assert(result.ResultCode == "PREVIEW_EXPIRED", "expired preview should be rejected");
        Assert(!env.Journal.Prepared, "expired preview must not prepare a transaction");
    }

    private async Task StalePreviewIsRejectedAsync()
    {
        var env = new TestEnvironment(
            previewDecision: new(false, true, false, ["APPROVAL_REQUIRED"]),
            applyDecision: new(true, true, true, []));
        var preview = await env.CreatePreviewAsync();
        env.Compatibility.SnapshotId = "different-capability-snapshot";
        var result = await env.Broker.ApplyAsync(
            env.Request(OperationAction.Apply, OperationMode.Mutating, preview.PreviewReference),
            env.Approval(preview));
        Assert(result.ResultCode == "PREVIEW_STALE_COMPATIBILITY", "stale snapshot should invalidate preview");
        Assert(!env.Journal.Prepared, "stale preview must not start a transaction");
    }

    private async Task ReadOnlyApplyIsRejectedAsync()
    {
        var env = new TestEnvironment();
        var result = await env.Broker.ApplyAsync(
            env.Request(OperationAction.Apply, OperationMode.ReadOnly, previewReference: "preview-1"),
            approval: null);
        Assert(result.ResultCode == "INVALID_APPLY_REQUEST", "read-only apply must be rejected");
        Assert(env.Handler.ApplyCalls == 0, "no handler mutation should occur");
    }

    private static void Assert(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }
}

sealed class TestEnvironment
{
    public MutableClock Clock { get; } = new();
    public FakeJournal Journal { get; } = new();
    public FakeHandler Handler { get; }
    public FakeCompatibility Compatibility { get; }
    public OperationBroker Broker { get; }

    public TestEnvironment(
        CompatibilityVerdict compatibility = CompatibilityVerdict.Compatible,
        PolicyDecision? previewDecision = null,
        PolicyDecision? applyDecision = null,
        OperationVerification? verification = null,
        OperationVerification? rollback = null)
    {
        Handler = new FakeHandler(Journal, verification, rollback);
        Compatibility = new FakeCompatibility(compatibility);
        var registry = new FakeRegistry(Handler);
        var policy = new FakePolicy(
            previewDecision ?? new(true, false, true, []),
            applyDecision ?? new(true, false, true, []));
        Broker = new OperationBroker(
            Compatibility,
            policy,
            new FakeApprovalVerifier(Clock),
            new FakePreviewStore(),
            Journal,
            registry,
            Clock);
    }

    public OperationRequest Request(
        OperationAction action,
        OperationMode mode,
        string? previewReference = null) =>
        new(
            Guid.Parse("11111111-1111-4111-8111-111111111111"),
            "optimizer.temp-quarantine",
            new OperationCaller("C1", "S1"),
            action,
            mode,
            new OperationTarget("user", "temp-files"),
            RiskTier.Medium,
            previewReference);

    public async Task<OperationResult> CreatePreviewAsync()
    {
        var result = await Broker.CreatePreviewAsync(
            Request(OperationAction.Preview, OperationMode.Mutating));
        Assert(result.State is "preview_ready" or "awaiting_approval", "preview should be created");
        return result;
    }

    public ApprovalProof Approval(OperationResult preview) =>
        new("test-user", Handler.LastPreview!.PreviewHash,
            Clock.UtcNow.AddMinutes(5), ["user"]);
}

sealed class MutableClock : IClock
{
    public DateTimeOffset UtcNow { get; private set; } =
        new DateTimeOffset(2026, 11, 3, 19, 0, 0, TimeSpan.Zero);

    public void Advance(TimeSpan interval) => UtcNow += interval;
}

sealed class FakeCompatibility : ICompatibilityGate
{
    private readonly CompatibilityVerdict _verdict;
    public string SnapshotId { get; set; } = "capability-snapshot-1";

    public FakeCompatibility(CompatibilityVerdict verdict) => _verdict = verdict;

    public Task<CompatibilityResult> CheckAsync(
        OperationRequest request,
        CancellationToken cancellationToken) =>
        Task.FromResult(new CompatibilityResult(_verdict, SnapshotId, []));
}

sealed class FakePolicy : IPolicyEvaluator
{
    private readonly PolicyDecision _preview;
    private readonly PolicyDecision _apply;

    public FakePolicy(PolicyDecision preview, PolicyDecision apply)
    {
        _preview = preview;
        _apply = apply;
    }

    public Task<PolicyDecision> EvaluateAsync(
        OperationRequest request,
        CompatibilityResult compatibility,
        OperationPreview? preview,
        ApprovalProof? approval,
        CancellationToken cancellationToken) =>
        Task.FromResult(preview is null ? _preview : _apply);
}

sealed class FakeApprovalVerifier : IApprovalVerifier
{
    private readonly IClock _clock;
    public FakeApprovalVerifier(IClock clock) => _clock = clock;

    public Task<bool> VerifyAsync(
        ApprovalProof proof,
        OperationRequest request,
        OperationPreview preview,
        CancellationToken cancellationToken) =>
        Task.FromResult(
            proof.ExpiresAt > _clock.UtcNow &&
            proof.PreviewHash == preview.PreviewHash &&
            proof.ApprovedScopes.Contains(request.Target.Scope));
}

sealed class FakePreviewStore : IPreviewStore
{
    private readonly Dictionary<string, OperationPreview> _items = new();

    public Task SaveAsync(OperationPreview preview, CancellationToken cancellationToken)
    {
        _items[preview.Reference] = preview;
        return Task.CompletedTask;
    }

    public Task<OperationPreview?> GetAsync(string reference, CancellationToken cancellationToken)
    {
        _items.TryGetValue(reference, out var preview);
        return Task.FromResult(preview);
    }
}

sealed class FakeRegistry : IOperationHandlerRegistry
{
    private readonly IOperationHandler _handler;
    public FakeRegistry(IOperationHandler handler) => _handler = handler;

    public bool TryGet(string featureId, out IOperationHandler? handler)
    {
        handler = featureId == _handler.FeatureId ? _handler : null;
        return handler is not null;
    }
}

sealed class FakeJournal : ITransactionJournal
{
    public bool Prepared { get; private set; }
    public string? State { get; private set; }

    public Task PrepareAsync(OperationRequest request, OperationPreview preview, CancellationToken cancellationToken)
    {
        Prepared = true;
        State = "prepared";
        return Task.CompletedTask;
    }

    public Task MarkRunningAsync(Guid operationId, CancellationToken cancellationToken)
    {
        State = "running";
        return Task.CompletedTask;
    }

    public Task MarkCommittedAsync(Guid operationId, CancellationToken cancellationToken)
    {
        State = "committed";
        return Task.CompletedTask;
    }

    public Task MarkRollbackRequiredAsync(Guid operationId, string reason, CancellationToken cancellationToken)
    {
        State = "rollback_required";
        return Task.CompletedTask;
    }

    public Task MarkRollbackStartedAsync(Guid operationId, CancellationToken cancellationToken)
    {
        State = "rolling_back";
        return Task.CompletedTask;
    }

    public Task MarkRolledBackAsync(Guid operationId, CancellationToken cancellationToken)
    {
        State = "rolled_back";
        return Task.CompletedTask;
    }

    public Task MarkRecoveryIncompleteAsync(Guid operationId, string reason, CancellationToken cancellationToken)
    {
        State = "recovery_incomplete";
        return Task.CompletedTask;
    }
}

sealed class FakeHandler : IOperationHandler
{
    private readonly FakeJournal _journal;
    private readonly OperationVerification _verification;
    private readonly OperationVerification _rollback;

    public string FeatureId => "optimizer.temp-quarantine";
    public int InspectCalls { get; private set; }
    public int PreviewCalls { get; private set; }
    public int ApplyCalls { get; private set; }
    public int RollbackCalls { get; private set; }
    public bool SawPreparedJournal { get; private set; }
    public OperationPreview? LastPreview { get; private set; }

    public FakeHandler(
        FakeJournal journal,
        OperationVerification? verification,
        OperationVerification? rollback)
    {
        _journal = journal;
        _verification = verification ?? new(true, "VERIFIED");
        _rollback = rollback ?? new(true, "RESTORED");
    }

    public Task<OperationExecution> InspectAsync(OperationRequest request, CancellationToken cancellationToken)
    {
        InspectCalls++;
        return Task.FromResult(new OperationExecution(true, "INSPECTED"));
    }

    public Task<OperationPreview> CreatePreviewAsync(
        OperationRequest request,
        CompatibilityResult compatibility,
        CancellationToken cancellationToken)
    {
        PreviewCalls++;
        LastPreview = new OperationPreview(
            "preview-1",
            request.OperationId,
            request.FeatureId,
            request.Target,
            compatibility.SnapshotId,
            "sha256-preview-hash",
            new DateTimeOffset(2026, 11, 3, 20, 0, 0, TimeSpan.Zero),
            ["Quarantine selected eligible temporary files"]);
        return Task.FromResult(LastPreview);
    }

    public Task<OperationExecution> ApplyAsync(
        OperationRequest request,
        OperationPreview preview,
        CancellationToken cancellationToken)
    {
        ApplyCalls++;
        SawPreparedJournal = _journal.Prepared;
        return Task.FromResult(new OperationExecution(true, "APPLIED"));
    }

    public Task<OperationVerification> VerifyAsync(
        OperationRequest request,
        OperationPreview preview,
        CancellationToken cancellationToken) =>
        Task.FromResult(_verification);

    public Task<OperationVerification> RollbackAsync(
        OperationRequest request,
        OperationPreview preview,
        CancellationToken cancellationToken)
    {
        RollbackCalls++;
        return Task.FromResult(_rollback);
    }
}
