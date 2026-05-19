# Get-CitrixAppUsage.ps1
# Reports application usage statistics in Citrix Virtual Apps and Desktops.
# Requires: Citrix.Broker.Admin.V2 snap-in
# Run as Administrator

param (
    [int]$TopCount = 20
)

Write-Host "===== Citrix Application Usage Report =====" -ForegroundColor Cyan
Write-Host "Checked at: $(Get-Date)" -ForegroundColor Gray
Write-Host "Showing top $TopCount applications by current session count" -ForegroundColor Gray
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
    Write-Host "--- Published Applications Overview ---" -ForegroundColor Yellow

    $apps = @(Get-BrokerApplication -ErrorAction SilentlyContinue)
    if (-not $apps -or $apps.Count -eq 0) {
        Write-Host "No published applications found." -ForegroundColor DarkGray
        return
    }

    Write-Host "Total Published Applications: $($apps.Count)" -ForegroundColor White

    # Sessions are not exposed directly on Get-BrokerApplication. Derive
    # per-application session counts from active broker sessions: each
    # session's ApplicationsInUse contains the BrowserName(s) currently in use.
    $activeSessions = @(Get-BrokerSession -ErrorAction SilentlyContinue |
        Where-Object { $_.SessionState -eq 'Active' })

    $sessionCounts = @{}
    foreach ($s in $activeSessions) {
        if ($s.ApplicationsInUse) {
            foreach ($browserName in $s.ApplicationsInUse) {
                if (-not $sessionCounts.ContainsKey($browserName)) {
                    $sessionCounts[$browserName] = 0
                }
                $sessionCounts[$browserName]++
            }
        }
    }

    # Build a desktop-group lookup so we can resolve UIDs to friendly names.
    $dgLookup = @{}
    foreach ($dg in (Get-BrokerDesktopGroup -ErrorAction SilentlyContinue)) {
        $dgLookup[$dg.Uid] = $dg.Name
    }

    $appReport = foreach ($app in $apps) {
        $count = 0
        if ($app.BrowserName -and $sessionCounts.ContainsKey($app.BrowserName)) {
            $count = $sessionCounts[$app.BrowserName]
        }

        $dgNames = @()
        if ($app.AssociatedDesktopGroupUids) {
            foreach ($uid in $app.AssociatedDesktopGroupUids) {
                if ($dgLookup.ContainsKey($uid)) { $dgNames += $dgLookup[$uid] }
            }
        }

        [PSCustomObject]@{
            Name          = $app.Name
            PublishedName = $app.PublishedName
            BrowserName   = $app.BrowserName
            DesktopGroups = ($dgNames -join ', ')
            Sessions      = $count
            Enabled       = $app.Enabled
            Status        = if ($count -gt 0) { 'Active' } else { 'Inactive' }
        }
    }

    Write-Host "Top $TopCount by current session count:" -ForegroundColor Gray
    Write-Host ""
    $appReport |
        Sort-Object Sessions -Descending |
        Select-Object -First $TopCount |
        Format-Table Name, PublishedName, DesktopGroups, Sessions, Enabled, Status -AutoSize -Wrap

    # Application summary by desktop group (count of published apps per group)
    Write-Host ""
    Write-Host "--- Published Apps by Desktop Group ---" -ForegroundColor Yellow
    $byGroup = $appReport |
        Where-Object { $_.DesktopGroups } |
        ForEach-Object {
            foreach ($g in $_.DesktopGroups -split ',\s*') {
                [PSCustomObject]@{ DesktopGroup = $g; Sessions = $_.Sessions }
            }
        } |
        Group-Object DesktopGroup |
        Select-Object @{N='DesktopGroup'; E={$_.Name}},
                      @{N='AppCount';     E={$_.Count}},
                      @{N='TotalSessions';E={ ($_.Group | Measure-Object Sessions -Sum).Sum }} |
        Sort-Object TotalSessions -Descending

    if ($byGroup) { $byGroup | Format-Table -AutoSize }

    # Currently running sessions (snapshot)
    Write-Host ""
    Write-Host "--- Snapshot of Active Sessions (first 10) ---" -ForegroundColor Yellow
    if ($activeSessions.Count -gt 0) {
        $activeSessions |
            Select-Object -First 10 UserName, @{N='AppsInUse';E={ ($_.ApplicationsInUse -join ', ') }}, DesktopGroupName, ClientAddress |
            Format-Table -AutoSize
    } else {
        Write-Host "No active sessions found." -ForegroundColor DarkGray
    }

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    return
}
