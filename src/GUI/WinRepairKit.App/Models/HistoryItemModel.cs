namespace WinRepairKit.App.Models;

public class HistoryItemModel
{
    public string TransactionId { get; set; } = string.Empty;
    public string ModuleName { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string FormattedDate { get; set; } = string.Empty;
    public string FilePath { get; set; } = string.Empty;

    public string StatusBadgeBackground => Status switch
    {
        "Completed" => "#E8F5E9",
        "PartialFailure" => "#FFF3E0",
        "Failed" => "#FFEBEE",
        _ => "#F3F3F3"
    };

    public string StatusBadgeColor => Status switch
    {
        "Completed" => "#006E06",
        "PartialFailure" => "#DA3C03",
        "Failed" => "#BA1A1A",
        _ => "#717783"
    };
}
