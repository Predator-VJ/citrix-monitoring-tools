# Get-CitrixSessionInfo.ps1
# Reports active, disconnected, and idle ICA sessions on Citrix Virtual Apps and Desktops
# Requires: Citrix.Broker.Admin.V2 snap-in on Delivery Controller
# Run as Administrator

param (
    [string]$DeliveryGroup = "",
    [switch]$DisconnectedOnly
)

Write-Host "===== Citrix Session Information =====" -ForegroundColor Cyan
Write-Host "Checked at: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Check if Citrix Broker snap-in is available
try {
    $snapins = Get-PSSnapin -Registered -Name Citrix.Broker.Admin.V2 -ErrorAction SilentlyContinue
    if ($null -eq $snapins) {
        $loaded = Get-PSSnapin -Name Citrix.Broker.Admin.V2 -ErrorAction SilentlyContinue
        if ($null -eq $loaded) {
            Write-Host "Loading Citrix.Broker.Admin.V2 snap-in..." -ForegroundColor Yellow
            Add-PSSnapin Citrix.Broker.Admin.V2 -ErrorAction Stop
        }
    }
} catch {
    Write-Host "Error: Citrix.Broker.Admin.V2 snap-in not found." -ForegroundColor Red
    Write-Host "Make sure this script runs on a Citrix Delivery Controller." -ForegroundColor Yellow
    exit
}

try {
    # Build the filter based on parameters
    $filter = @{}
    if ($DisconnectedOnly) {
        $filter["SessionState"] = "Disconnected"
    }
    if ($DeliveryGroup -ne "") {
        $filter["DesktopGroupName"] = $DeliveryGroup
    }

    # Get all sessions
    Write-Host "--- Session Details ---" -ForegroundColor Yellow
    $sessions = Get-BrokerSession -Filter $filter -ErrorAction Stop |
        Select-Object UserName, SessionState, ClientAddress, ConnectionState, 
                      @{N="LogonTime";E={$_.LogonTime}},
                      @{N="DisconnectTime";E={$_.DisconnectTime}},
                      DesktopGroupName, ClientName | Sort-Object SessionState

    if ($sessions) {
        $total = $sessions.Count
        $active = ($sessions | Where-Object SessionState -eq Active).Count
        $disconnected = ($sessions | Where-Object SessionState -eq Disconnected).Count
        $connecting = ($sessions | Where-Object ConnectionState -eq Connected).Count

        Write-Host "Total Sessions: $total" -ForegroundColor White
        Write-Host "Active: $active | Disconnected: $disconnected | Connecting: $connecting" -ForegroundColor Gray
        Write-Host ""

        $sessions | Format-Table UserName, SessionState, ConnectionState, DesktopGroupName, ClientAddress -AutoSize
    } else {
        if ($DisconnectedOnly) {
            Write-Host "No disconnected sessions found." -ForegroundColor Green
        } else {
            Write-Host "No sessions found." -ForegroundColor DarkGray
        }
    }

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

Write-Host "`n--- Session Summary ---" -ForegroundColor Yellow
$summary = Get-BrokerSession | Group-Object SessionState | Select-Object Name, Count
$summary | Format-Table Name, Count -AutoSize
