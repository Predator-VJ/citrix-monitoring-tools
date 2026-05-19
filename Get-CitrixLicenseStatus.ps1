# Get-CitrixLicenseStatus.ps1
# Checks Citrix License Server status and usage.
# Requires:
#   - Citrix.Broker.Admin.V2          (to read site/license-server config)
#   - Citrix.Licensing.Admin.V1       (to query actual license usage)
# Run as Administrator on a Delivery Controller.

Write-Host "===== Citrix License Server Status =====" -ForegroundColor Cyan
Write-Host "Checked at: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# ---- Load required snap-ins -------------------------------------------------
function Ensure-Snapin {
    param([string]$Name)
    $loaded = Get-PSSnapin -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $loaded) {
        Write-Host "Loading $Name snap-in..." -ForegroundColor Yellow
        Add-PSSnapin $Name -ErrorAction Stop
    }
}

try {
    Ensure-Snapin -Name 'Citrix.Broker.Admin.V2'
} catch {
    Write-Host "Error: Citrix.Broker.Admin.V2 snap-in not found." -ForegroundColor Red
    Write-Host "Make sure this script runs on a Citrix Delivery Controller." -ForegroundColor Yellow
    return
}

$licensingAvailable = $true
try {
    Ensure-Snapin -Name 'Citrix.Licensing.Admin.V1'
} catch {
    Write-Host "Warning: Citrix.Licensing.Admin.V1 snap-in not available." -ForegroundColor DarkYellow
    Write-Host "License-usage details will be skipped. Install the Citrix Licensing PowerShell SDK to enable them." -ForegroundColor DarkYellow
    $licensingAvailable = $false
}

try {
    # ---- License server configured on this site -------------------------
    $site = Get-BrokerSite -ErrorAction SilentlyContinue

    if ($null -eq $site -or [string]::IsNullOrWhiteSpace($site.LicenseServerName)) {
        Write-Host "No license server configured in this deployment." -ForegroundColor Yellow
        return
    }

    $licServer = $site.LicenseServerName
    $licPort   = $site.LicenseServerPort
    $edition   = $site.ProductEdition
    $product   = $site.ProductCode
    $licModel  = $site.LicensingModel

    Write-Host "--- License Server Details ---" -ForegroundColor Yellow
    Write-Host "Server:          $licServer"
    Write-Host "Port:            $licPort"
    Write-Host "Product:         $product"
    Write-Host "Edition:         $edition"
    Write-Host "Licensing model: $licModel"
    Write-Host ""

    if (-not $licensingAvailable) { return }

    # ---- License usage from the License Server --------------------------
    # The licensing SDK requires an HTTPS admin URL like
    # https://<server>:8083 and certificate-hash auth.
    $adminAddress = "https://$licServer:8083"

    try {
        $cert = Get-LicCertificate -AdminAddress $adminAddress -ErrorAction Stop
    } catch {
        Write-Host "Error retrieving license server certificate from $adminAddress." -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkYellow
        return
    }

    try {
        $usage = Get-LicInventory -AdminAddress $adminAddress -CertHash $cert.CertHash -ErrorAction Stop
    } catch {
        Write-Host "Error retrieving license inventory: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    if (-not $usage) {
        Write-Host "License Server returned no inventory data." -ForegroundColor DarkGray
        return
    }

    Write-Host "--- License Usage Summary ---" -ForegroundColor Yellow
    $usage |
        Select-Object LocalizedLicenseProductName, LocalizedLicenseModel,
                      LicensesInUse, LicensesAvailable, Count, ExpirationDate |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "--- License Usage Per Product ---" -ForegroundColor Yellow
    foreach ($item in $usage) {
        $total     = [int]$item.Count
        $inUse     = [int]$item.LicensesInUse
        $available = [int]$item.LicensesAvailable
        $pct = if ($total -gt 0) { [math]::Round(($inUse / $total) * 100, 1) } else { 0 }

        # Visual usage bar (each '#' = ~5%)
        $barLen = [int]([math]::Min(20, [math]::Floor($pct / 5)))
        $bar    = ('#' * $barLen).PadRight(20, '.')

        $color = if ($pct -ge 90) { 'Red' } elseif ($pct -ge 70) { 'Yellow' } else { 'Green' }
        $line  = "{0,-45} {1,5}/{2,-5}  Avail: {3,-5}  [{4}] {5}%" -f `
                    $item.LocalizedLicenseProductName, $inUse, $total, $available, $bar, $pct
        Write-Host $line -ForegroundColor $color
    }

    # ---- Warnings -------------------------------------------------------
    Write-Host ""
    Write-Host "--- License Warnings ---" -ForegroundColor Magenta
    $warnings = @()

    $lowAvail = $usage | Where-Object { [int]$_.LicensesAvailable -lt 5 -and [int]$_.Count -gt 0 }
    foreach ($c in $lowAvail) {
        $warnings += "LOW: '$($c.LocalizedLicenseProductName)' has only $($c.LicensesAvailable) licenses remaining."
    }

    $expiringSoon = $usage | Where-Object {
        $_.ExpirationDate -and ($_.ExpirationDate -is [datetime]) -and
        $_.ExpirationDate -lt (Get-Date).AddDays(30)
    }
    foreach ($e in $expiringSoon) {
        $warnings += "EXPIRING: '$($e.LocalizedLicenseProductName)' expires on $($e.ExpirationDate.ToShortDateString())."
    }

    if ($warnings.Count -gt 0) {
        $warnings | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    } else {
        Write-Host "No license warnings. Sufficient licenses available." -ForegroundColor Green
    }

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    return
}
