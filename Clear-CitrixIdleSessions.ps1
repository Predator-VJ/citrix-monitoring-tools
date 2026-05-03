# Clear-CitrixIdleSessions.ps1
# Logs off idle/disconnected Citrix sessions after a configurable time threshold
# Requires: Citrix.Broker.Admin.V2 snap-in
# Run as Administrator
# WARNING: This script terminates sessions. Use with caution.

param (
    [int]$IdleMinutes = 120,        # Default: 2 hours
    [switch]$DisconnectedOnly,      # Only clear disconnected sessions
    [switch]$WhatIf                  # Show what would be done without actually logging off
)

Write-Host "===== Citrix Idle Session Cleanup =====" -ForegroundColor Cyan
Write-Host "Checked at: $(Get-Date)" -ForegroundColor Gray
Write-Host "Idle threshold: $IdleMinutes minutes" -ForegroundColor Gray
if ($DisconnectedOnly) {
    Write-Host "Mode: Disconnected sessions only" -ForegroundColor Yellow
} else {
    Write-Host "Mode: Disconnected + Idle sessions" -ForegroundColor Yellow
}
if ($WhatIf) {
    Write-Host "Mode: DRY RUN - No sessions will be terminated" -ForegroundColor Magenta
}
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
    $now = Get-Date
    $threshold = $now.AddMinutes(-$IdleMinutes)
    
    Write-Host "--- Analyzing Sessions ---" -ForegroundColor Yellow
    
    # Get all disconnected sessions
    $disconnectedSessions = Get-BrokerSession -Filter @{ SessionState = "Disconnected" } -ErrorAction SilentlyContinue
    
    # Get all idle sessions (connected but idle)
    $idleSessions = Get-BrokerSession -Filter @{ SessionState = "Connected" } -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisconnectTime -lt $threshold }
    
    # Combine sessions based on mode
    if ($DisconnectedOnly) {
        $sessionsToClear = $disconnectedSessions
    } else {
        $sessionsToClear = @($disconnectedSessions + $idleSessions) | Sort-Object -Unique -Property Id
    }
    
    if ($sessionsToClear) {
        $count = $sessionsToClear.Count
        Write-Host "Found $count sessions exceeding the idle threshold." -ForegroundColor Red
        Write-Host ""
        Write-Host "--- Sessions to be Cleared ---" -ForegroundColor Yellow
        
        foreach ($sess in $sessionsToClear) {
            $idleTime = $now - $sess.DisconnectTime
            $user = $sess.UserName
            $appName = $sess.ApplicationName
            $dg = $sess.DesktopGroupName
            $idleStr = "{0}h {1}m" -f $idleTime.Hours, $idleTime.Minutes
            
            Write-Host "  User: $user | App: $appName | Group: $dg | Idle: $idleStr" -ForegroundColor Red
            
            if (-not $WhatIf) {
                try {
                    Stop-BrokerSession -Id $sess.Id -ErrorAction Stop
                    Write-Host "  -> Session logged off successfully." -ForegroundColor Green
                } catch {
                    Write-Host "  -> Failed to log off: $($_.Exception.Message)" -ForegroundColor DarkYellow
                }
            }
        }
        
        if ($WhatIf) {
            Write-Host "`nDRY RUN complete. $count sessions would have been logged off." -ForegroundColor Magenta
        } else {
            Write-Host "`nCleanup complete. $count sessions were logged off." -ForegroundColor Green
        }
    } else {
        Write-Host "No sessions exceed the idle threshold. Nothing to clear." -ForegroundColor Green
    }

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit
}
