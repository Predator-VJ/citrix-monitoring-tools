# Get-CitrixMachineStatus.ps1
# Monitors VDA machine availability and health in Citrix Virtual Apps and Desktops.
# Requires: Citrix.Broker.Admin.V2 snap-in
# Run as Administrator

param (
    [string]$DeliveryGroup = "",
    [ValidateSet("", "Registered", "Unregistered", "Initializing", "AgentError")]
    [string]$RegistrationState = ""
)

Write-Host "===== Citrix Machine Status Report =====" -ForegroundColor Cyan
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
    return
}

try {
    # ---- Delivery Groups overview (only when no specific group is asked) ----
    if ([string]::IsNullOrWhiteSpace($DeliveryGroup)) {
        Write-Host "--- Delivery Groups Overview ---" -ForegroundColor Yellow
        $dgs = Get-BrokerDesktopGroup -ErrorAction SilentlyContinue |
            Sort-Object Name |
            Select-Object Name,
                          DesktopKind,
                          TotalDesktops,
                          DesktopsAvailable,
                          DesktopsUnregistered,
                          DesktopsInUse,
                          Sessions,
                          InMaintenanceMode
        if ($dgs) {
            $dgs | Format-Table -AutoSize
        } else {
            Write-Host "No delivery groups found." -ForegroundColor DarkGray
        }
        Write-Host ""
    }

    # ---- Machine details ---------------------------------------------------
    # Build cmdlet parameters only when caller actually filters.
    $params = @{ ErrorAction = 'SilentlyContinue' }
    if (-not [string]::IsNullOrWhiteSpace($DeliveryGroup))    { $params['DesktopGroupName']  = $DeliveryGroup }
    if (-not [string]::IsNullOrWhiteSpace($RegistrationState)) { $params['RegistrationState'] = $RegistrationState }

    Write-Host "--- Machine Status Details ---" -ForegroundColor Yellow
    $machinesRaw = @(Get-BrokerMachine @params)

    if ($machinesRaw.Count -eq 0) {
        Write-Host "No machines found matching the filter." -ForegroundColor DarkGray
    } else {
        $machines = $machinesRaw |
            Sort-Object RegistrationState, DesktopGroupName, HostedMachineName |
            Select-Object HostedMachineName,
                          DNSName,
                          DesktopGroupName,
                          RegistrationState,
                          PowerState,
                          InMaintenanceMode,
                          SessionCount,
                          OSType,
                          AgentVersion

        $total        = $machines.Count
        $registered   = @($machines | Where-Object { $_.RegistrationState -eq 'Registered' }).Count
        $unregistered = @($machines | Where-Object { $_.RegistrationState -eq 'Unregistered' }).Count
        $maintenance  = @($machines | Where-Object { $_.InMaintenanceMode -eq $true }).Count
        $poweredOff   = @($machines | Where-Object { $_.PowerState -eq 'Off' }).Count

        Write-Host "Total Machines: $total" -ForegroundColor White
        Write-Host ("Registered: {0} | Unregistered: {1} | In Maintenance: {2} | Powered Off: {3}" -f `
                   $registered, $unregistered, $maintenance, $poweredOff) -ForegroundColor Gray
        Write-Host ""

        $machines |
            Format-Table HostedMachineName, DesktopGroupName, RegistrationState,
                         PowerState, InMaintenanceMode, SessionCount, OSType `
                         -AutoSize -Wrap
    }

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# ---- Health summary across the whole site ---------------------------------
Write-Host "`n--- Machine Health Summary ---" -ForegroundColor Yellow
try {
    $summary = Get-BrokerMachine -ErrorAction SilentlyContinue |
        Group-Object RegistrationState |
        Select-Object @{N='RegistrationState'; E={$_.Name}},
                      @{N='Count';            E={$_.Count}} |
        Sort-Object Count -Descending
    if ($summary) {
        $summary | Format-Table -AutoSize
    } else {
        Write-Host "No machines registered to summarize." -ForegroundColor DarkGray
    }
} catch {
    Write-Host "Could not produce health summary: $($_.Exception.Message)" -ForegroundColor DarkYellow
}
