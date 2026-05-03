# Get-CitrixMachineStatus.ps1
# Monitors VDA machine availability and health in Citrix Virtual Apps and Desktops
# Requires: Citrix.Broker.Admin.V2 snap-in
# Run as Administrator

param (
    [string]$DeliveryGroup = "",
    [string]$Status = ""  # Filter: Registered, Unregistered, Maintenance, etc.
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
    exit
}

try {
    # Build filter
    $filter = @{}
    if ($DeliveryGroup -ne "") {
        $filter["DesktopGroupName"] = $DeliveryGroup
    }
    if ($Status -ne "") {
        $filter["RegistrationState"] = $Status
    }

    # Get delivery groups if no specific group specified
    if ($DeliveryGroup -eq "") {
        Write-Host "--- Delivery Groups Overview ---" -ForegroundColor Yellow
        $dgs = Get-BrokerDesktopGroup -Fields Name, AvailableCount, TotalCount, PowerState, DesktopKind |
            Select-Object Name, AvailableCount, TotalCount, PowerState, DesktopKind | Sort-Object Name
        $dgs | Format-Table -AutoSize
        Write-Host ""
    }

    # Get machine details
    Write-Host "--- Machine Status Details ---" -ForegroundColor Yellow
    $machines = Get-BrokerDesktop -Filter $filter -ErrorAction SilentlyContinue |
        Select-Object HostedMachineName, DesktopGroupName, RegistrationState,
                      @{N="PowerState";E={$_.PowerState}},
                      @{N="MaintenanceMode";E={$_.InMaintenanceMode}},
                      @{N="Sessions";E={$_.SessionCount}},
                      @{N="OS";E={$_.OSDescription}} | Sort-Object RegistrationState, DesktopGroupName

    if ($machines) {
        $total = $machines.Count
        $registered = ($machines | Where-Object RegistrationState -eq Registered).Count
        $unregistered = ($machines | Where-Object RegistrationState -eq Unregistered).Count
        $maintenance = ($machines | Where-Object MaintenanceMode -eq $true).Count

        Write-Host "Total Machines: $total" -ForegroundColor White
        Write-Host "Registered: $registered | Unregistered: $unregistered | In Maintenance: $maintenance" -ForegroundColor Gray
        Write-Host ""

        $machines | Format-Table HostedMachineName, DesktopGroupName, RegistrationState, PowerState, Sessions, OS -AutoSize -Wrap
    } else {
        Write-Host "No machines found matching the filter." -ForegroundColor DarkGray
    }

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

Write-Host "`n--- Machine Health Summary ---" -ForegroundColor Yellow
$summary = Get-BrokerDesktop | Group-Object RegistrationState | Select-Object Name, Count
$summary | Format-Table Name, Count -AutoSize
