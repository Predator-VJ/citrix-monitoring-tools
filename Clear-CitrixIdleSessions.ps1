# Clear-CitrixIdleSessions.ps1
# Logs off idle/disconnected Citrix sessions after a configurable time threshold.
# Requires: Citrix.Broker.Admin.V2 snap-in
# Run as Administrator
# WARNING: This script terminates sessions. Use -WhatIf for a dry run.

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param (
    [int]$IdleMinutes = 120,        # Default: 2 hours
    [switch]$DisconnectedOnly       # Only clear disconnected sessions
)

Write-Host "===== Citrix Idle Session Cleanup =====" -ForegroundColor Cyan
Write-Host "Checked at: $(Get-Date)" -ForegroundColor Gray
Write-Host "Idle threshold: $IdleMinutes minutes" -ForegroundColor Gray
if ($DisconnectedOnly) {
    Write-Host "Mode: Disconnected sessions only" -ForegroundColor Yellow
} else {
    Write-Host "Mode: Disconnected + Idle sessions" -ForegroundColor Yellow
}
if ($WhatIfPreference) {
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
    return
}

try {
    $now = Get-Date
    $threshold = $now.AddMinutes(-$IdleMinutes)

    Write-Host "--- Analyzing Sessions ---" -ForegroundColor Yellow

    # Disconnected sessions older than the threshold.
    # DisconnectTime is the moment the session was disconnected.
    $disconnectedSessions = @(
        Get-BrokerSession -Filter { SessionState -eq 'Disconnected' } -ErrorAction SilentlyContinue |
            Where-Object { $_.SessionStateChangeTime -ne $null -and $_.SessionStateChangeTime -lt $threshold }
    )

    # Idle (Connected) sessions: idle time is measured from the last user input,
    # which lives on $_.SessionInfo or, on older SDKs, can be approximated with
    # SessionStateChangeTime. We deliberately do NOT use DisconnectTime for
    # connected sessions because it is null and "$null -lt [datetime]" is $true,
    # which would match every active session.
    $idleSessions = @()
    if (-not $DisconnectedOnly) {
        $idleSessions = @(
            Get-BrokerSession -Filter { SessionState -eq 'Active' } -ErrorAction SilentlyContinue |
                Where-Object {
                    # Prefer the explicit IdleSince/IdleTime if present, else
                    # fall back to the last session-state change.
                    $idleSince = $null
                    if ($_.PSObject.Properties.Name -contains 'IdleSince' -and $_.IdleSince) {
                        $idleSince = $_.IdleSince
                    } elseif ($_.SessionStateChangeTime) {
                        $idleSince = $_.SessionStateChangeTime
                    }
                    $idleSince -ne $null -and $idleSince -lt $threshold
                }
        )
    }

    # Combine sessions based on mode
    if ($DisconnectedOnly) {
        $sessionsToClear = $disconnectedSessions
    } else {
        $sessionsToClear = @($disconnectedSessions + $idleSessions) | Sort-Object -Unique -Property Uid
    }

    if ($sessionsToClear -and $sessionsToClear.Count -gt 0) {
        $count = $sessionsToClear.Count
        Write-Host "Found $count sessions exceeding the idle threshold." -ForegroundColor Red
        Write-Host ""
        Write-Host "--- Sessions to be Cleared ---" -ForegroundColor Yellow

        foreach ($sess in $sessionsToClear) {
            $referenceTime = if ($sess.SessionState -eq 'Disconnected') { $sess.SessionStateChangeTime }
                             elseif ($sess.PSObject.Properties.Name -contains 'IdleSince' -and $sess.IdleSince) { $sess.IdleSince }
                             else { $sess.SessionStateChangeTime }

            $idleStr = "n/a"
            if ($referenceTime) {
                $idleTime = $now - $referenceTime
                $idleStr  = "{0}h {1}m" -f [int]$idleTime.TotalHours, $idleTime.Minutes
            }

            $user = $sess.UserName
            $dg   = $sess.DesktopGroupName
            $st   = $sess.SessionState

            Write-Host "  User: $user | State: $st | Group: $dg | Idle: $idleStr" -ForegroundColor Red

            $target = "Citrix session Uid=$($sess.Uid) (User=$user, State=$st)"
            if ($PSCmdlet.ShouldProcess($target, "Stop-BrokerSession (log off)")) {
                try {
                    Stop-BrokerSession -InputObject $sess -ErrorAction Stop
                    Write-Host "  -> Session logged off successfully." -ForegroundColor Green
                } catch {
                    Write-Host "  -> Failed to log off: $($_.Exception.Message)" -ForegroundColor DarkYellow
                }
            }
        }

        if ($WhatIfPreference) {
            Write-Host "`nDRY RUN complete. $count sessions would have been logged off." -ForegroundColor Magenta
        } else {
            Write-Host "`nCleanup complete. Processed $count sessions." -ForegroundColor Green
        }
    } else {
        Write-Host "No sessions exceed the idle threshold. Nothing to clear." -ForegroundColor Green
    }

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    return
}
