# Enhanced PowerShell script to properly publish all client projects and installation files

param (
    [string]$Hostname = "https://remotely.redfox.lan",  # Updated hostname without port
    [string]$CurrentVersion = "",
    [switch]$MinimalMode  # Only build essential clients
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

if (!$CurrentVersion) {
    $CurrentVersion = Get-Date -Format "yyyy.MM.dd.HHmm"
}

Write-Host "Building Remotely clients for hostname: $Hostname" -ForegroundColor Green
Write-Host "Version: $CurrentVersion" -ForegroundColor Green
if ($MinimalMode) {
    Write-Host "MINIMAL MODE: Building only Windows x64 and Linux x64" -ForegroundColor Yellow
}

# Clean and create Content directory
$ContentDir = "Server\wwwroot\Content"
if (Test-Path $ContentDir) {
    Remove-Item -Recurse -Force $ContentDir\* 2>$null
}
New-Item -ItemType Directory -Force -Path $ContentDir | Out-Null

# Create subdirectories
if ($MinimalMode) {
    $subdirs = @("Win-x64", "Linux-x64")
    $agentBuilds = @{
        "win-x64" = @{ RID = "win-x64"; ZipName = "Remotely-Win-x64.zip" }
        "linux-x64" = @{ RID = "linux-x64"; ZipName = "Remotely-Linux.zip" }
    }
    $desktopBuilds = @{
        "win-x64" = @{ Project = "Desktop.Win\Desktop.Win.csproj"; RID = "win-x64"; OutDir = "Win-x64"; FileName = "Remotely_Desktop.exe" }
        "linux-x64" = @{ Project = "Desktop.Linux\Desktop.Linux.csproj"; RID = "linux-x64"; OutDir = "Linux-x64"; FileName = "Remotely_Desktop" }
    }
} else {
    $subdirs = @("Win-x64", "Win-x86", "Linux-x64", "MacOS-x64", "MacOS-arm64")
    # Publish agents with compression
    $agentBuilds = @{
        "win-x64" = @{ RID = "win-x64"; ZipName = "Remotely-Win-x64.zip" }
        "win-x86" = @{ RID = "win-x86"; ZipName = "Remotely-Win-x86.zip" }
        "linux-x64" = @{ RID = "linux-x64"; ZipName = "Remotely-Linux.zip" }
        "osx-x64" = @{ RID = "osx-x64"; ZipName = "Remotely-MacOS-x64.zip" }
        "osx-arm64" = @{ RID = "osx-arm64"; ZipName = "Remotely-MacOS-arm64.zip" }
    }
    # Publish desktop clients using runtime identifier approach
    $desktopBuilds = @{
        "win-x64" = @{ Project = "Desktop.Win\Desktop.Win.csproj"; RID = "win-x64"; OutDir = "Win-x64"; FileName = "Remotely_Desktop.exe" }
        "win-x86" = @{ Project = "Desktop.Win\Desktop.Win.csproj"; RID = "win-x86"; OutDir = "Win-x86"; FileName = "Remotely_Desktop.exe" }
        "linux-x64" = @{ Project = "Desktop.Linux\Desktop.Linux.csproj"; RID = "linux-x64"; OutDir = "Linux-x64"; FileName = "Remotely_Desktop" }
    }
}

foreach ($dir in $subdirs) {
    New-Item -ItemType Directory -Force -Path "$ContentDir\$dir" | Out-Null
}

Write-Host "Publishing agents..." -ForegroundColor Yellow

foreach ($build in $agentBuilds.Keys) {
    $config = $agentBuilds[$build]
    $publishDir = "Agent\bin\publish\$build"
    
    # Clean publish directory
    if (Test-Path $publishDir) {
        Remove-Item -Recurse -Force $publishDir\*
    } else {
        New-Item -ItemType Directory -Force -Path $publishDir | Out-Null
    }
    
    Write-Host "Publishing Agent for $($config.RID)..." -ForegroundColor Cyan
    dotnet publish /p:Version=$CurrentVersion /p:FileVersion=$CurrentVersion --runtime $($config.RID) --self-contained --configuration Release --output $publishDir "Agent\Agent.csproj"
    
    # Create ZIP file
    $zipPath = "$publishDir\$($config.ZipName)"
    Compress-Archive -Path "$publishDir\*" -DestinationPath $zipPath -Force
    
    # Move to Content directory
    Move-Item -Path $zipPath -Destination "$ContentDir\$($config.ZipName)" -Force
    Write-Host "Created $($config.ZipName)" -ForegroundColor Green
}

Write-Host "Publishing desktop clients..." -ForegroundColor Yellow

foreach ($build in $desktopBuilds.Keys) {
    $config = $desktopBuilds[$build]
    $outPath = "$ContentDir\$($config.OutDir)"
    
    Write-Host "Publishing $($config.Project) for $($config.RID)..." -ForegroundColor Cyan
    dotnet publish /p:Version=$CurrentVersion /p:FileVersion=$CurrentVersion --runtime $($config.RID) --self-contained --configuration Release --output $outPath $config.Project
    
    Write-Host "Created desktop client for $($config.OutDir)" -ForegroundColor Green
}

Write-Host "Creating installation scripts..." -ForegroundColor Yellow

# Create PowerShell installation script
$installRemotelyPs1 = @"
<#
.SYNOPSIS
    Installs the Remotely agent.
.DESCRIPTION
    Downloads and installs the Remotely agent.
#>

[CmdletBinding()]
param(
    [string]`$HostName = `"$Hostname`",
    [string]`$Organization = `$null,
    [string]`$DeviceGroup = `$null,
    [string]`$DeviceAlias = `$null,
    [string]`$DeviceUuid = `$null,
    [string]`$Path = `$null,
    [switch]`$Install,
    [switch]`$Uninstall,
    [switch]`$Quiet,
    [switch]`$SupportShortcut
)

`$ErrorActionPreference = "Stop"

if (`$Install -and `$Uninstall) {
    Write-Error "Cannot specify both -Install and -Uninstall parameters."
    exit 1
}

if (!`$Install -and !`$Uninstall) {
    Write-Host "Usage: Install-Remotely.ps1 -Install [-Quiet] [-Organization <OrgId>] [-HostName <ServerUrl>]"
    Write-Host "       Install-Remotely.ps1 -Uninstall [-Quiet]"
    exit 0
}

if (`$Uninstall) {
    Write-Host "Uninstalling Remotely agent..."
    
    # Stop and remove service
    try {
        Stop-Service -Name "Remotely_Service" -Force -ErrorAction SilentlyContinue
        sc.exe delete "Remotely_Service"
    } catch {
        Write-Warning "Failed to remove service: `$(`$_.Exception.Message)"
    }
    
    # Remove installation directory
    try {
        Remove-Item -Path "`$env:ProgramFiles\Remotely" -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Failed to remove installation directory: `$(`$_.Exception.Message)"
    }
    
    # Remove from startup
    try {
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "Remotely_Desktop" -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Failed to remove startup entry: `$(`$_.Exception.Message)"
    }
    
    if (!`$Quiet) {
        Write-Host "Remotely agent has been uninstalled." -ForegroundColor Green
    }
    exit 0
}

if (`$Install) {
    if (!`$HostName) {
        Write-Error "HostName parameter is required for installation."
        exit 1
    }
    
    Write-Host "Installing Remotely agent..."
    Write-Host "Server: `$HostName"
    if (`$Organization) { Write-Host "Organization: `$Organization" }
    if (`$DeviceGroup) { Write-Host "Device Group: `$DeviceGroup" }
    if (`$DeviceAlias) { Write-Host "Device Alias: `$DeviceAlias" }
    
    `$installDir = "`$env:ProgramFiles\Remotely"
    
    if (`$Path) {
        # Install from local file
        if (!(Test-Path `$Path)) {
            Write-Error "Local installation file not found: `$Path"
            exit 1
        }
        
        Write-Host "Installing from local file: `$Path"
        Expand-Archive -Path `$Path -DestinationPath `$installDir -Force
    } else {
        # Download and install
        `$downloadUrl = "`$HostName/Content/Remotely-Win-x64.zip"
        `$tempFile = Join-Path `$env:TEMP "Remotely-Win-x64.zip"
        
        Write-Host "Downloading from: `$downloadUrl"
        try {
            Invoke-WebRequest -Uri `$downloadUrl -OutFile `$tempFile -UseBasicParsing
        } catch {
            Write-Error "Failed to download Remotely agent: `$(`$_.Exception.Message)"
            exit 1
        }
        
        if (Test-Path `$installDir) {
            Remove-Item -Path `$installDir -Recurse -Force
        }
        New-Item -Path `$installDir -ItemType Directory -Force | Out-Null
        
        Expand-Archive -Path `$tempFile -DestinationPath `$installDir -Force
        Remove-Item -Path `$tempFile -Force
    }
    
    # Create appsettings.json
    `$appSettings = @{
        ServerUrl = `$HostName
        OrganizationId = `$Organization
        DeviceGroup = `$DeviceGroup
        DeviceAlias = `$DeviceAlias
        DeviceUuid = `$DeviceUuid
    }
    
    `$appSettingsJson = `$appSettings | ConvertTo-Json -Depth 3
    `$appSettingsPath = Join-Path `$installDir "appsettings.json"
    `$appSettingsJson | Out-File -FilePath `$appSettingsPath -Encoding UTF8
    
    # Install and start service
    `$servicePath = Join-Path `$installDir "Remotely_Agent.exe"
    sc.exe create "Remotely_Service" binPath= "`$servicePath" start= auto
    Start-Service -Name "Remotely_Service"
    
    # Create support shortcut if requested
    if (`$SupportShortcut) {
        `$shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Get Support.lnk"
        `$shell = New-Object -ComObject WScript.Shell
        `$shortcut = `$shell.CreateShortcut(`$shortcutPath)
        `$shortcut.TargetPath = "`$HostName/get-support"
        `$shortcut.Save()
    }
    
    if (!`$Quiet) {
        Write-Host "Remotely agent has been installed successfully." -ForegroundColor Green
        Write-Host "Service status:" -ForegroundColor Yellow
        Get-Service -Name "Remotely_Service"
    }
}
"@

# Create Ubuntu installation script
$installUbuntuSh = @"
#!/bin/bash

HostName="$Hostname"
Organization=""

Help()
{
   echo "Install script for Remotely"
   echo
   echo "Syntax: Install-Ubuntu-x64.sh [options]"
   echo "options:"
   echo "--uninstall        Uninstall Remotely."
   echo "--path             Local path to install from."
   echo
}

ArgCount=`$#

if [ `$ArgCount -eq 0 ]; then
    echo "Installing Remotely agent..."
    echo "Server: `$HostName"
    echo "Organization: `$Organization"
    
    # Download and install
    TempFile="/tmp/Remotely-Linux.zip"
    InstallDir="/usr/local/bin/Remotely"
    
    echo "Downloading from: `$HostName/Content/Remotely-Linux.zip"
    
    if [ -f "`$TempFile" ]; then
        rm "`$TempFile"
    fi
    
    wget -q -O "`$TempFile" "`$HostName/Content/Remotely-Linux.zip"
    
    if [ ! -f "`$TempFile" ]; then
        echo "Failed to download Remotely agent."
        exit 1
    fi
    
    if [ -d "`$InstallDir" ]; then
        sudo rm -rf "`$InstallDir"
    fi
    
    sudo mkdir -p "`$InstallDir"
    sudo unzip -q "`$TempFile" -d "`$InstallDir"
    sudo chmod +x "`$InstallDir/Remotely_Agent"
    
    # Create service
    sudo tee /etc/systemd/system/remotely.service > /dev/null <<EOL
[Unit]
Description=Remotely Agent

[Service]
WorkingDirectory=`$InstallDir
ExecStart=`$InstallDir/Remotely_Agent
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable remotely
    sudo systemctl start remotely
    
    echo "Remotely agent installed successfully."
    exit 0
fi

while [ `$# -gt 0 ]; do
  case `$1 in
    --uninstall)
      echo "Uninstalling Remotely agent..."
      sudo systemctl stop remotely
      sudo systemctl disable remotely
      sudo rm -f /etc/systemd/system/remotely.service
      sudo rm -rf /usr/local/bin/Remotely
      sudo systemctl daemon-reload
      echo "Remotely agent uninstalled."
      exit 0
      ;;
    --path)
      LocalPath="`$2"
      if [ ! -f "`$LocalPath" ]; then
          echo "Local installation file not found: `$LocalPath"
          exit 1
      fi
      
      InstallDir="/usr/local/bin/Remotely"
      
      if [ -d "`$InstallDir" ]; then
          sudo rm -rf "`$InstallDir"
      fi
      
      sudo mkdir -p "`$InstallDir"
      sudo unzip -q "`$LocalPath" -d "`$InstallDir"
      sudo chmod +x "`$InstallDir/Remotely_Agent"
      
      # Create service
      sudo tee /etc/systemd/system/remotely.service > /dev/null <<EOL
[Unit]
Description=Remotely Agent

[Service]
WorkingDirectory=`$InstallDir
ExecStart=`$InstallDir/Remotely_Agent
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

      sudo systemctl daemon-reload
      sudo systemctl enable remotely
      sudo systemctl start remotely
      
      echo "Remotely agent installed successfully from local file."
      exit 0
      ;;
    -*|--*)
      echo "Unknown option `$1"
      Help
      exit 1
      ;;
  esac
  shift
done
"@

# Create Manjaro installation script (similar to Ubuntu)
$installManjaroSh = @"
#!/bin/bash

HostName="$Hostname"
Organization=""

echo "Installing Remotely agent for Manjaro..."
echo "Server: `$HostName"

TempFile="/tmp/Remotely-Linux.zip"
InstallDir="/usr/local/bin/Remotely"

echo "Downloading from: `$HostName/Content/Remotely-Linux.zip"

if [ -f "`$TempFile" ]; then
    rm "`$TempFile"
fi

wget -q -O "`$TempFile" "`$HostName/Content/Remotely-Linux.zip"

if [ ! -f "`$TempFile" ]; then
    echo "Failed to download Remotely agent."
    exit 1
fi

if [ -d "`$InstallDir" ]; then
    sudo rm -rf "`$InstallDir"
fi

sudo mkdir -p "`$InstallDir"
sudo unzip -q "`$TempFile" -d "`$InstallDir"
sudo chmod +x "`$InstallDir/Remotely_Agent"

# Create service
sudo tee /etc/systemd/system/remotely.service > /dev/null <<EOL
[Unit]
Description=Remotely Agent

[Service]
WorkingDirectory=`$InstallDir
ExecStart=`$InstallDir/Remotely_Agent
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable remotely
sudo systemctl start remotely

echo "Remotely agent installed successfully."
"@

# Write installation scripts to Content directory
$installRemotelyPs1 | Out-File -FilePath "$ContentDir\Install-Remotely.ps1" -Encoding UTF8
$installUbuntuSh | Out-File -FilePath "$ContentDir\Install-Ubuntu-x64.sh" -Encoding UTF8 -NoNewline
$installManjaroSh | Out-File -FilePath "$ContentDir\Install-Manjaro-x64.sh" -Encoding UTF8 -NoNewline

Write-Host "Created Install-Remotely.ps1" -ForegroundColor Green
Write-Host "Created Install-Ubuntu-x64.sh" -ForegroundColor Green
Write-Host "Created Install-Manjaro-x64.sh" -ForegroundColor Green

# Make shell scripts executable (if on Linux/WSL)
if (Get-Command chmod -ErrorAction SilentlyContinue) {
    chmod +x "$ContentDir/Install-Ubuntu-x64.sh"
    chmod +x "$ContentDir/Install-Manjaro-x64.sh"
}

Write-Host "Updating client configurations..." -ForegroundColor Yellow

# Update client configuration files with hostname
$configFiles = Get-ChildItem -Path $ContentDir -Recurse -Filter "appsettings.json" -ErrorAction SilentlyContinue
foreach ($file in $configFiles) {
    try {
        $config = Get-Content -Path $file.FullName | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($config) {
            $config.ServerUrl = $Hostname
            $config | ConvertTo-Json -Depth 3 | Set-Content -Path $file.FullName -Encoding UTF8
            Write-Host "Updated config: $($file.FullName)" -ForegroundColor Cyan
        }
    } catch {
        Write-Warning "Failed to update config file: $($file.FullName) - $($_.Exception.Message)"
    }
}

Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "Hostname configured: $Hostname" -ForegroundColor Green
Write-Host "All client projects published to Server/wwwroot/Content/" -ForegroundColor Green 