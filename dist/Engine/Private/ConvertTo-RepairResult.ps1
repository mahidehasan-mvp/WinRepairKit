# WinRepairKit - Private Helper: ConvertTo-RepairResult
# Converts a raw hashtable or custom object into a typed RepairResult

function ConvertTo-RepairResult {
    [CmdletBinding()]
    [OutputType([RepairResult])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject
    )

    if ($InputObject -is [RepairResult]) {
        return $InputObject
    }

    $result = [RepairResult]::new()

    if ($InputObject.ModuleName) { $result.ModuleName = $InputObject.ModuleName }
    if ($InputObject.Status) { $result.Status = [RepairStatus]$InputObject.Status }
    if ($InputObject.RiskLevel) { $result.RiskLevel = [RiskLevel]$InputObject.RiskLevel }
    if ($null -ne $InputObject.RequiresAdmin) { $result.RequiresAdmin = [bool]$InputObject.RequiresAdmin }
    if ($null -ne $InputObject.CanRepair) { $result.CanRepair = [bool]$InputObject.CanRepair }
    if ($null -ne $InputObject.SupportsDryRun) { $result.SupportsDryRun = [bool]$InputObject.SupportsDryRun }
    if ($null -ne $InputObject.DataDestructive) { $result.DataDestructive = [bool]$InputObject.DataDestructive }
    if ($InputObject.Timestamp) { $result.Timestamp = [datetime]$InputObject.Timestamp }
    if ($InputObject.DurationMs) { $result.DurationMs = [int64]$InputObject.DurationMs }

    if ($InputObject.Findings) {
        foreach ($f in $InputObject.Findings) {
            if ($f -is [Finding]) {
                $result.Findings.Add($f)
            }
            else {
                $findingObj = [Finding]::new()
                if ($f.Id) { $findingObj.Id = $f.Id }
                if ($f.Severity) { $findingObj.Severity = [SeverityLevel]$f.Severity }
                if ($f.Title) { $findingObj.Title = $f.Title }
                if ($f.Detail) { $findingObj.Detail = $f.Detail }
                if ($f.Path) { $findingObj.Path = $f.Path }
                if ($f.SizeBytes) { $findingObj.SizeBytes = [int64]$f.SizeBytes }
                if ($f.FileCount) { $findingObj.FileCount = [int64]$f.FileCount }
                if ($f.ExtraData) { $findingObj.ExtraData = $f.ExtraData }
                $result.Findings.Add($findingObj)
            }
        }
    }

    if ($InputObject.Plan) {
        $result.Plan = $InputObject.Plan
    }

    if ($InputObject.Recommendations) {
        foreach ($r in $InputObject.Recommendations) {
            $result.Recommendations.Add($r.ToString())
        }
    }

    return $result
}
