<#
.SYNOPSIS
    Installs the Remotely agent.
.DESCRIPTION
    Downloads and installs the Remotely agent.
#>

[CmdletBinding()]
param(
    [string]$HostName = "https://remotely.redfox.lan",
    [string]$Organization = $null,
    [string]$DeviceGroup = $null,
    [string]$DeviceAlias = $null,
    [string]$DeviceUuid = $null,
    [string]$Path = $null,
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Quiet,
    [switch]$SupportShortcut
)

$ErrorActionPreference = "Stop"

if ($Install -and $Uninstall) {
    Write-Error "Cannot specify both -Install and -Uninstall parameters."
    exit 1
}

if (!$Install -and !$Uninstall) {
    Write-Host "Usage: Install-Remotely.ps1 -Install [-Quiet] [-Organization <OrgId>] [-HostName <ServerUrl>]"
    Write-Host "       Install-Remotely.ps1 -Uninstall [-Quiet]"
    exit 0
}

if ($Uninstall) {
    Write-Host "Uninstalling Remotely agent..."
    
    # Stop and remove service
    try {
        Stop-Service -Name "Remotely_Service" -Force -ErrorAction SilentlyContinue
        sc.exe delete "Remotely_Service"
    } catch {
        Write-Warning "Failed to remove service: $($_.Exception.Message)"
    }
    
    # Remove installation directory
    try {
        Remove-Item -Path "$env:ProgramFiles\Remotely" -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Failed to remove installation directory: $($_.Exception.Message)"
    }
    
    # Remove from startup
    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "Remotely_Desktop" -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Failed to remove startup entry: $($_.Exception.Message)"
    }
    
    if (!$Quiet) {
        Write-Host "Remotely agent has been uninstalled." -ForegroundColor Green
    }
    exit 0
}

if ($Install) {
    if (!$HostName) {
        Write-Error "HostName parameter is required for installation."
        exit 1
    }
    
    Write-Host "Installing Remotely agent..."
    Write-Host "Server: $HostName"
    if ($Organization) { Write-Host "Organization: $Organization" }
    if ($DeviceGroup) { Write-Host "Device Group: $DeviceGroup" }
    if ($DeviceAlias) { Write-Host "Device Alias: $DeviceAlias" }
    
    $installDir = "$env:ProgramFiles\Remotely"
    
    if ($Path) {
        # Install from local file
        if (!(Test-Path $Path)) {
            Write-Error "Local installation file not found: $Path"
            exit 1
        }
        
        Write-Host "Installing from local file: $Path"
        Expand-Archive -Path $Path -DestinationPath $installDir -Force
    } else {
        # Download and install
        $downloadUrl = "$HostName/Content/Remotely-Win-x64.zip"
        $tempFile = Join-Path $env:TEMP "Remotely-Win-x64.zip"
        
        Write-Host "Downloading from: $downloadUrl"
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
        } catch {
            Write-Error "Failed to download Remotely agent: $($_.Exception.Message)"
            exit 1
        }
        
        if (Test-Path $installDir) {
            Remove-Item -Path $installDir -Recurse -Force
        }
        New-Item -Path $installDir -ItemType Directory -Force | Out-Null
        
        Expand-Archive -Path $tempFile -DestinationPath $installDir -Force
        Remove-Item -Path $tempFile -Force
    }
    
    # Create appsettings.json
    $appSettings = @{
        ServerUrl = $HostName
        OrganizationId = $Organization
        DeviceGroup = $DeviceGroup
        DeviceAlias = $DeviceAlias
        DeviceUuid = $DeviceUuid
    }
    
    $appSettingsJson = $appSettings | ConvertTo-Json -Depth 3
    $appSettingsPath = Join-Path $installDir "appsettings.json"
    $appSettingsJson | Out-File -FilePath $appSettingsPath -Encoding UTF8
    
    # Install and start service
    $servicePath = Join-Path $installDir "Remotely_Agent.exe"
    sc.exe create "Remotely_Service" binPath= "$servicePath" start= auto
    Start-Service -Name "Remotely_Service"
    
    # Create support shortcut if requested
    if ($SupportShortcut) {
        $shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Get Support.lnk"
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = "$HostName/get-support"
        $shortcut.Save()
    }
    
    if (!$Quiet) {
        Write-Host "Remotely agent has been installed successfully." -ForegroundColor Green
        Write-Host "Service status:" -ForegroundColor Yellow
        Get-Service -Name "Remotely_Service"
    }
}
