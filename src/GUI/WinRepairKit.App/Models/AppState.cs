namespace WinRepairKit.App.Models;

public enum ApplicationState
{
    Idle,
    Scanning,
    ScanCompleted,
    ProblemSelected,
    Planning,
    PlanReady,
    DryRunning,
    AwaitingConfirmation,
    AwaitingElevation,
    Repairing,
    Verifying,
    RepairSucceeded,
    RepairPartiallySucceeded,
    RepairFailed,
    PlanStale,
    InterruptedTransaction,
    Error
}
