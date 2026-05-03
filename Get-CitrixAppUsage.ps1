# Get-CitrixAppUsage.ps1
# Reports application usage statistics in Citrix Virtual Apps and Desktops
# Requires: Citrix.Broker.Admin.V2 snap-in
# Run as Administrator

param (
    [int]$TopCount = 20
)

Write-Host "===== Citrix Application Usage Report =====" -ForegroundColor Cyan
Write-Host "Checked at: $(Get-Date)" -ForegroundColor Gray
Write-Host "Showing top $TopCount applications by session count" -ForegroundColor Gray
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
    # Get all published applications
    Write-Host "--- Published Applications Overview ---" -ForegroundColor Yellow
    $apps = Get-BrokerApplication -ErrorAction SilentlyContinue | Sort-Object SessionCount -Descending | Select-Object -First $TopCount
    
    if ($apps) {
        Write-Host "Total Published Applications: $((Get-BrokerApplication -ErrorAction SilentlyContinue).Count)" -ForegroundColor White
        Write-Host "Top $TopCount by Session Count:" -ForegroundColor Gray
        Write-Host ""

        $appReport = @()
        foreach ($app in $apps) {
            $pctActive = if ($app.SessionCount -gt 0) { 
                "Active" 
            } else { 
                "Inactive" 
            }
            $color = if ($pctActive -eq "Active") { "Green" } else { "DarkGray" }
            
            $appReport += [PSCustomObject]@{
                Name          = $app.ApplicationName
                DesktopGroup  = $app.DesktopGroupName
                Sessions      = $app.SessionCount
                PublishName   = $app.PublishingName
                Status        = $pctActive
            }
        }

        $appReport | Format-Table Name, DesktopGroup, Sessions, PublishName, Status -AutoSize -Wrap
    } else {
        Write-Host "No published applications found." -ForegroundColor DarkGray
    }

    # Application summary by desktop group
    Write-Host ""
    Write-Host "--- Usage by Desktop Group ---" -ForegroundColor Yellow
    $dgUsage = Get-BrokerApplication -ErrorAction SilentlyContinue | 
        Group-Object DesktopGroupName | 
        Select-Object Name, Count | Sort-Object Count -Descending
    
    if ($dgUsage) {
        $dgUsage | Format-Table Name, Count -AutoSize
    }

    # Get session details for top apps
    Write-Host ""
    Write-Host "--- Active Sessions on Top Applications ---" -ForegroundColor Yellow
    $sessions = Get-BrokerSession -ErrorAction SilentlyContinue | 
        Where-Object { $_.SessionState -eq "Active" } | 
        Select-Object -First 10
    
    if ($sessions) {
        $sessions | Format-Table UserName, ApplicationName, SessionState, ClientAddress -AutoSize
    } else {
        Write-Host "No active sessions found." -ForegroundColor DarkGray
    }

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit
}
