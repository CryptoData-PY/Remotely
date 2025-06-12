#!/bin/bash

HostName="https://remotely.redfox.lan"
Organization=""

echo "Installing Remotely agent for Manjaro..."
echo "Server: $HostName"

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