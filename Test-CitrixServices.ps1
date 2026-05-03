# Test-CitrixServices.ps1
# Checks status of critical Citrix services on Delivery Controller
# Run as Administrator

Write-Host "===== Citrix Services Status Check =====" -ForegroundColor Cyan
Write-Host "Checked at: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

$citrixServices = @(
    "CitrixBrokerService",
    "CitrixLicenseService",
    "CitrixSterlingService",
    "CitrixConfigSyncService",
    "CitrixGroupPolicyManagement",
    "CitrixTelemetryService",
    "CitrixLogMonitor",
    "Ctx_CentralConfigService",
    "CitrixAnalytics",
    "CitrixDirectorService"
)

$running = 0
$stopped = 0
$notFound = 0

$results = foreach ($svcName in $citrixServices) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        $status = $svc.Status
        $color = if ($status -eq "Running") {
            $running++
            "Green"
        } else {
            $stopped++
            "Red"
        }
    } else {
        $status = "Not Found"
        $color = "DarkGray"
        $notFound++
    }
    
    [PSCustomObject]@{
        Service     = $svcName
        Status      = $status
        DisplayName = if ($svc) { $svc.DisplayName } else { "N/A" }
    }
}

Write-Host "--- Service Status ---" -ForegroundColor Yellow
$results | Format-Table -AutoSize

Write-Host "--- Summary ---" -ForegroundColor Magenta
Write-Host "Running:   $running" -ForegroundColor Green
Write-Host "Stopped:   $stopped" -ForegroundColor Red
Write-Host "Not Found: $notFound" -ForegroundColor DarkGray
Write-Host "Total:     $($citrixServices.Count)" -ForegroundColor White

if ($stopped -gt 0) {
    Write-Host "`nWARNING: Some Citrix services are stopped!" -ForegroundColor Yellow
    Write-Host "Check Event Viewer for service-specific errors." -ForegroundColor Gray
} elseif ($notFound -gt 0) {
    Write-Host "`nNOTE: Some services not found - may not apply to your deployment." -ForegroundColor DarkYellow
} else {
    Write-Host "`nAll critical Citrix services are running." -ForegroundColor Green
}
