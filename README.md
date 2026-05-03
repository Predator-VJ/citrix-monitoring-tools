# 🌐 Citrix Monitoring Tools

A collection of PowerShell monitoring and troubleshooting scripts for **Citrix Virtual Apps and Desktops** environments. These scripts help Citrix admins automate health checks, session monitoring, license reporting, and more.

---

## 📁 Scripts Overview

| Script | Description |
|--------|-------------|
| `Get-CitrixSessionInfo.ps1` | Reports active/disconnected ICA sessions |
| `Get-CitrixLicenseStatus.ps1` | Checks Citrix License Server status and usage |
| `Get-CitrixMachineStatus.ps1` | Monitors VDA machine availability and health |
| `Get-CitrixAppUsage.ps1` | Reports application usage statistics |
| `Test-CitrixServices.ps1` | Checks if critical Citrix services are running |
| `Clear-CitrixIdleSessions.ps1` | Logs off idle/disconnected sessions after a threshold |

> ⚠️ **Note:** All scripts require the **Citrix PowerShell SDK** (Citrix.Broker.Admin.V2) to be installed on your Delivery Controller.

---

## ⚙️ Requirements

- Windows Server with **Citrix Virtual Apps and Desktops** Delivery Controller
- **Citrix PowerShell SDK** (installed with Citrix installation media)
- PowerShell 5.1+ with Administrator privileges
- Appropriate Citrix admin role/permissions

### Install Citrix PowerShell SDK

If not already installed:

```powershell
# Add Citrix snap-in manually if not auto-loaded
Add-PSSnapin Citrix.Broker.Admin.V2
Add-PSSnapin Citrix.Common.Admin.V2
```

---

## 🔧 How to Run Scripts

### Step 1: Open PowerShell as Administrator on the Delivery Controller

### Step 2: Load Citrix Snap-ins (if not auto-loaded)

```powershell
Add-PSSnapin Citrix.Broker.Admin.V2
Add-PSSnapin Citrix.Common.Admin.V2
```

### Step 3: Navigate to the Scripts Directory

```powershell
cd C:\path\to\citrix-monitoring-tools
```

### Step 4: Run Any Script

```powershell
.\Get-CitrixSessionInfo.ps1
```

---

## 📖 Usage Examples

### View Active and Disconnected Sessions
```powershell
.\Get-CitrixSessionInfo.ps1
```

### Check License Server Health
```powershell
.\Get-CitrixLicenseStatus.ps1
```

### Monitor VDA Machine Status
```powershell
.\Get-CitrixMachineStatus.ps1 -DeliveryGroup "Windows10_DG"
```

### Check if Citrix Services Are Running
```powershell
.\Test-CitrixServices.ps1
```

### Clear Idle Sessions (older than 2 hours)
```powershell
.\Clear-CitrixIdleSessions.ps1 -IdleMinutes 120
```

### Report Application Usage
```powershell
.\Get-CitrixAppUsage.ps1
```

---

## 📋 Script Details

### Get-CitrixSessionInfo.ps1
Lists all ICA sessions on the farm including session state, username, client IP, and duration.

### Get-CitrixLicenseStatus.ps1
Connects to the License Server and reports total licenses, used licenses, and available licenses.

### Get-CitrixMachineStatus.ps1
Reports VDA machine registration status, maintenance mode, and power state for a delivery group.

### Test-CitrixServices.ps1
Checks the status of critical Citrix services (Broker, License, Director, Gateway, etc.).

### Clear-CitrixIdleSessions.ps1
Automatically logs off disconnected or idle sessions after a configurable time threshold.

---

## 🖋️ Author

**Vikas Joshi** — System Admin  
GitHub: [Predator-VJ](https://github.com/Predator-VJ)

---

> ⭐ If you find these tools useful, consider **starring** the repo!
