# Test-CitrixServices.ps1
# Checks the status of critical Citrix services on a Delivery Controller.
# Run as Administrator.

Write-Host "===== Citrix Services Status Check =====" -ForegroundColor Cyan
Write-Host "Checked at: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Real DDC service names (CVAD/XenDesktop 7.x). Some may not exist on every
# deployment; missing ones are reported as "Not Found" rather than failing.
$citrixServices = @(
    'CitrixBrokerService'              # Citrix Broker Service
    'CitrixConfigurationService'       # Citrix Configuration Service
    'CitrixConfigSyncService'          # Citrix Configuration Sync Service
    'CitrixADIdentityService'          # Citrix AD Identity Service
    'CitrixDelegatedAdmin'             # Citrix Delegated Administration Service
    'CitrixHighAvailabilityService'    # Citrix High Availability Service
    'CitrixHostService'                # Citrix Host Service
    'CitrixMachineCreationService'     # Citrix Machine Creation Service
    'CitrixMonitor'                    # Citrix Monitor Service
    'CitrixAnalytics'                  # Citrix Analytics
    'CitrixEnvTest'                    # Citrix Environment Test Service
    'CitrixTelemetryService'           # Citrix Telemetry Service
)

$running  = 0
$stopped  = 0
$notFound = 0

$results = foreach ($svcName in $citrixServices) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue

    if ($null -eq $svc) {
        $notFound++
        $status      = 'Not Found'
        $displayName = 'N/A'
    } else {
        $status      = [string]$svc.Status
        $displayName = $svc.DisplayName
        if ($status -eq 'Running') { $running++ } else { $stopped++ }
    }

    [PSCustomObject]@{
        Service     = $svcName
        DisplayName = $displayName
        Status      = $status
    }
}

Write-Host "--- Service Status ---" -ForegroundColor Yellow
foreach ($row in $results) {
    $color = switch ($row.Status) {
        'Running'    { 'Green' }
        'Not Found'  { 'DarkGray' }
        default      { 'Red' }
    }
    Write-Host ("{0,-32} {1,-12} {2}" -f $row.Service, $row.Status, $row.DisplayName) -ForegroundColor $color
}

Write-Host ""
Write-Host "--- Summary ---" -ForegroundColor Magenta
Write-Host "Running:   $running"  -ForegroundColor Green
Write-Host "Stopped:   $stopped"  -ForegroundColor Red
Write-Host "Not Found: $notFound" -ForegroundColor DarkGray
Write-Host "Total:     $($citrixServices.Count)" -ForegroundColor White

if ($stopped -gt 0) {
    Write-Host "`nWARNING: Some Citrix services are stopped!" -ForegroundColor Yellow
    Write-Host "Check Event Viewer for service-specific errors." -ForegroundColor Gray
} elseif ($notFound -gt 0) {
    Write-Host "`nNOTE: Some services were not found - they may not apply to this deployment role." -ForegroundColor DarkYellow
} else {
    Write-Host "`nAll critical Citrix services are running." -ForegroundColor Green
}
