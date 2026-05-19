# Get-CitrixSessionInfo.ps1
# Reports active, disconnected, and idle ICA sessions on Citrix Virtual Apps and Desktops.
# Requires: Citrix.Broker.Admin.V2 snap-in on a Delivery Controller.
# Run as Administrator.

param (
    [string]$DeliveryGroup = "",
    [switch]$DisconnectedOnly
)

Write-Host "===== Citrix Session Information =====" -ForegroundColor Cyan
Write-Host "Checked at: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Check if Citrix Broker snap-in is available
try {
    $loaded = Get-PSSnapin -Name Citrix.Broker.Admin.V2 -ErrorAction SilentlyContinue
    if ($null -eq $loaded) {
        $registered = Get-PSSnapin -Registered -Name Citrix.Broker.Admin.V2 -ErrorAction SilentlyContinue
        if ($null -eq $registered) {
            throw "Citrix.Broker.Admin.V2 is not registered on this host."
        }
        Write-Host "Loading Citrix.Broker.Admin.V2 snap-in..." -ForegroundColor Yellow
        Add-PSSnapin Citrix.Broker.Admin.V2 -ErrorAction Stop
    }
} catch {
    Write-Host "Error: Citrix.Broker.Admin.V2 snap-in not found." -ForegroundColor Red
    Write-Host "Make sure this script runs on a Citrix Delivery Controller." -ForegroundColor Yellow
    return
}

try {
    # Build cmdlet parameters via splat (avoids passing an empty -Filter hashtable).
    $params = @{ ErrorAction = 'Stop' }
    if ($DisconnectedOnly)                              { $params['SessionState']     = 'Disconnected' }
    if (-not [string]::IsNullOrWhiteSpace($DeliveryGroup)) { $params['DesktopGroupName'] = $DeliveryGroup }

    Write-Host "--- Session Details ---" -ForegroundColor Yellow
    $sessions = @(
        Get-BrokerSession @params |
            Sort-Object SessionState, DesktopGroupName, UserName |
            Select-Object UserName,
                          SessionState,
                          ConnectionState,
                          DesktopGroupName,
                          ClientName,
                          ClientAddress,
                          LogonTime,
                          SessionStateChangeTime
    )

    if ($sessions.Count -gt 0) {
        $total        = $sessions.Count
        $active       = @($sessions | Where-Object { $_.SessionState -eq 'Active' }).Count
        $disconnected = @($sessions | Where-Object { $_.SessionState -eq 'Disconnected' }).Count
        $other        = $total - $active - $disconnected   # PreLogon, Reconnecting, etc.

        Write-Host "Total Sessions: $total" -ForegroundColor White
        Write-Host ("Active: {0} | Disconnected: {1} | Other: {2}" -f $active, $disconnected, $other) -ForegroundColor Gray
        Write-Host ""

        $sessions |
            Format-Table UserName, SessionState, ConnectionState, DesktopGroupName,
                         ClientName, ClientAddress, LogonTime -AutoSize
    } else {
        if ($DisconnectedOnly) {
            Write-Host "No disconnected sessions found." -ForegroundColor Green
        } else {
            Write-Host "No sessions found." -ForegroundColor DarkGray
        }
    }

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# ---- Site-wide summary -----------------------------------------------------
Write-Host "`n--- Session Summary (entire site) ---" -ForegroundColor Yellow
try {
    $summary = Get-BrokerSession -ErrorAction SilentlyContinue |
        Group-Object SessionState |
        Select-Object @{N='SessionState'; E={$_.Name}},
                      @{N='Count';        E={$_.Count}} |
        Sort-Object Count -Descending
    if ($summary) {
        $summary | Format-Table -AutoSize
    } else {
        Write-Host "No sessions to summarize." -ForegroundColor DarkGray
    }
} catch {
    Write-Host "Could not produce summary: $($_.Exception.Message)" -ForegroundColor DarkYellow
}
