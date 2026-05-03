# Get-CitrixLicenseStatus.ps1
# Checks Citrix License Server status and usage
# Requires: Citrix.Broker.Admin.V2 snap-in
# Run as Administrator

Write-Host "===== Citrix License Server Status =====" -ForegroundColor Cyan
Write-Host "Checked at: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Check if Citrix Broker snap-in is available
try {
    $loaded = Get-PSSnapin -Name Citrix.Broker.Admin.V2 -ErrorAction SilentlyContinue
    if ($null -eq $loaded) {
        Write-Host "Loading Citrix.Broker.Admin.V2 snap-in..." -ForegroundColor Yellow
        Add-PSSnapin Citrix.Broker.Admin.V2 -ErrorAction Stop
    }
} catch {
    Write-Host "Error: Citrix.Broker.Admin.V2 snap-in not found." -ForegroundColor Red
    Write-Host "Make sure this script runs on a Citrix Delivery Controller." -ForegroundColor Yellow
    exit
}

try {
    # Get license server info
    $licenseServer = Get-BrokerLicenseServer -ErrorAction SilentlyContinue
    
    if ($null -eq $licenseServer) {
        Write-Host "No license server configured in this deployment." -ForegroundColor Yellow
        exit
    }

    Write-Host "--- License Server Details ---" -ForegroundColor Yellow
    Write-Host "Name: $($licenseServer.Name)"
    Write-Host "UID:  $($licenseServer.Uid)"
    Write-Host ""

    # Get license usage
    $usage = Get-BrokerLicenseUsage -ErrorAction SilentlyContinue
    
    Write-Host "--- License Usage Summary ---" -ForegroundColor Yellow
    $usage | Format-Table LicenseModel, Used, Total, Available -AutoSize

    Write-Host ""
    Write-Host "--- License Usage Per Product ---" -ForegroundColor Yellow
    foreach ($item in $usage) {
        $pct = if ($item.Total -gt 0) { [math]::Round(($item.Used / $item.Total) * 100, 1) } else { 0 }
        $bar = "" * ([int]($pct / 5))
        $color = if ($pct -ge 90) { "Red" } elseif ($pct -ge 70) { "Yellow" } else { "Green" }
        Write-Host "$($item.LicenseModel)`t$($item.Used)/$($item.Total)`tAvailable: $($item.Available)`tUsage: $pct%" -ForegroundColor $color
    }

    # Check for expired or critical licenses
    Write-Host ""
    Write-Host "--- License Warnings ---" -ForegroundColor Magenta
    $critical = $usage | Where-Object { $_.Available -lt 5 }
    if ($critical) {
        foreach ($c in $critical) {
            Write-Host "WARNING: License model '$($c.LicenseModel)' has only $($c.Available) licenses remaining!" -ForegroundColor Red
        }
    } else {
        Write-Host "No license warnings. Sufficient licenses available." -ForegroundColor Green
    }

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit
}
