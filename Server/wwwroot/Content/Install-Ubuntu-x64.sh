#!/bin/bash

HostName="https://remotely.redfox.lan"
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

ArgCount=$#

if [ $ArgCount -eq 0 ]; then
    echo "Installing Remotely agent..."
    echo "Server: $HostName"
    echo "Organization: $Organization"
    
    # Download and install
    TempFile="/tmp/Remotely-Linux.zip"
    InstallDir="/usr/local/bin/Remotely"
    
    echo "Downloading from: $HostName/Content/Remotely-Linux.zip"
    
    if [ -f "$TempFile" ]; then
        rm "$TempFile"
    fi
    
    wget -q -O "$TempFile" "$HostName/Content/Remotely-Linux.zip"
    
    if [ ! -f "$TempFile" ]; then
        echo "Failed to download Remotely agent."
        exit 1
    fi
    
    if [ -d "$InstallDir" ]; then
        sudo rm -rf "$InstallDir"
    fi
    
    sudo mkdir -p "$InstallDir"
    sudo unzip -q "$TempFile" -d "$InstallDir"
    sudo chmod +x "$InstallDir/Remotely_Agent"
    
    # Create service
    sudo tee /etc/systemd/system/remotely.service > /dev/null <<EOL
[Unit]
Description=Remotely Agent

[Service]
WorkingDirectory=$InstallDir
ExecStart=$InstallDir/Remotely_Agent
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

while [ $# -gt 0 ]; do
  case $1 in
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
      LocalPath="$2"
      if [ ! -f "$LocalPath" ]; then
          echo "Local installation file not found: $LocalPath"
          exit 1
      fi
      
      InstallDir="/usr/local/bin/Remotely"
      
      if [ -d "$InstallDir" ]; then
          sudo rm -rf "$InstallDir"
      fi
      
      sudo mkdir -p "$InstallDir"
      sudo unzip -q "$LocalPath" -d "$InstallDir"
      sudo chmod +x "$InstallDir/Remotely_Agent"
      
      # Create service
      sudo tee /etc/systemd/system/remotely.service > /dev/null <<EOL
[Unit]
Description=Remotely Agent

[Service]
WorkingDirectory=$InstallDir
ExecStart=$InstallDir/Remotely_Agent
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
      echo "Unknown option $1"
      Help
      exit 1
      ;;
  esac
  shift
done