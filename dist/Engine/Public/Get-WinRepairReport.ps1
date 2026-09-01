# WinRepairKit - Public Cmdlet: Get-WinRepairReport
# Generates reports in Text, JSON, or HTML format

function Get-WinRepairReport {
    <#
    .SYNOPSIS
        Generates a human-readable or structured report from scan/repair results.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [RepairResult[]]$Results,

        [Parameter()]
        [ValidateSet('Text', 'Json', 'Html')]
        [string]$Format = 'Text'
    )

    if ($Format -eq 'Json') {
        return ($Results | ConvertTo-Json -Depth 6)
    }

    if ($Format -eq 'Html') {
        $htmlSb = [System.Text.StringBuilder]::new()
        [void]$htmlSb.AppendLine("<!DOCTYPE html><html><head><meta charset='utf-8'><title>WinRepairKit Report</title>")
        [void]$htmlSb.AppendLine("<style>body{font-family:Segoe UI,sans-serif;margin:20px;background:#f9f9f9;color:#333;}.card{background:#fff;padding:15px;margin-bottom:15px;border-radius:8px;box-shadow:0 2px 4px rgba(0,0,0,0.1);}.healthy{color:#2e7d32;}.problem{color:#c62828;}.badge{padding:3px 8px;border-radius:4px;font-size:12px;font-weight:bold;color:#fff;background:#757575;}</style></head><body>")
        [void]$htmlSb.AppendLine("<h1>WinRepairKit Diagnostic &amp; Repair Report</h1>")
        [void]$htmlSb.AppendLine("<p>Generated: $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) UTC</p>")

        foreach ($res in $Results) {
            $statusClass = if ($res.Status -eq [RepairStatus]::Healthy) { "healthy" } else { "problem" }
            [void]$htmlSb.AppendLine("<div class='card'>")
            [void]$htmlSb.AppendLine("<h2>Module: $($res.ModuleName) - <span class='$statusClass'>$($res.Status)</span></h2>")
            [void]$htmlSb.AppendLine("<p><strong>Risk Level:</strong> $($res.RiskLevel) | <strong>Duration:</strong> $($res.DurationMs) ms</p>")

            if ($res.Findings.Count -gt 0) {
                [void]$htmlSb.AppendLine("<h3>Findings ($($res.Findings.Count)):</h3><ul>")
                foreach ($f in $res.Findings) {
                    [void]$htmlSb.AppendLine("<li><strong>$($f.Id)</strong>: $($f.Title)<br><small>$($f.Detail)</small></li>")
                }
                [void]$htmlSb.AppendLine("</ul>")
            }

            if ($res.Verification) {
                [void]$htmlSb.AppendLine("<h3>Verification:</h3>")
                [void]$htmlSb.AppendLine("<p>$($res.Verification.Message)</p>")
            }

            [void]$htmlSb.AppendLine("</div>")
        }
        [void]$htmlSb.AppendLine("</body></html>")
        return $htmlSb.ToString()
    }

    # Text format
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("================================================================")
    [void]$sb.AppendLine("  WinRepairKit Report")
    [void]$sb.AppendLine("================================================================")
    [void]$sb.AppendLine("Generated: $([datetime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')) UTC")
    [void]$sb.AppendLine("")

    foreach ($res in $Results) {
        $statusLabel = switch ($res.Status) {
            ([RepairStatus]::Healthy)         { "[OK] Healthy" }
            ([RepairStatus]::ProblemFound)    { "[WARN] Problem Detected" }
            ([RepairStatus]::RepairSucceeded) { "[OK] Repair Succeeded" }
            ([RepairStatus]::RepairPartial)   { "[WARN] Repair Partial" }
            ([RepairStatus]::RepairFailed)    { "[FAIL] Repair Failed" }
            Default                           { $res.Status.ToString() }
        }

        [void]$sb.AppendLine("----------------------------------------------------------------")
        [void]$sb.AppendLine("Module: $($res.ModuleName)")
        [void]$sb.AppendLine("Status: $statusLabel (Risk: $($res.RiskLevel), Duration: $($res.DurationMs) ms)")
        [void]$sb.AppendLine("----------------------------------------------------------------")

        if ($res.Findings.Count -gt 0) {
            [void]$sb.AppendLine("Findings:")
            foreach ($f in $res.Findings) {
                [void]$sb.AppendLine("  * [$($f.Id)] $($f.Title)")
                if ($f.Detail) { [void]$sb.AppendLine("    $($f.Detail)") }
            }
        }

        if ($res.Verification) {
            [void]$sb.AppendLine("Verification:")
            [void]$sb.AppendLine("  $($res.Verification.Message)")
        }
        [void]$sb.AppendLine("")
    }

    return $sb.ToString()
}
