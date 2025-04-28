#!/bin/bash

set -e

# Define the mapping: Project path -> Output subfolder
declare -A projects=(
  ["./Desktop.Windows/Desktop.Windows.csproj"]="Win-x64"
  ["./Desktop.Linux/Desktop.Linux.csproj"]="Linux-x64"
  ["./Desktop.MacOS/Desktop.MacOS.csproj"]="MacOS-x64"
  ["./Agent/Agent.csproj"]="Agent"
  # Add more as needed
)

# Clean old content
rm -rf Server/wwwroot/Content/*
mkdir -p Server/wwwroot/Content

# Publish each project
for proj in "${!projects[@]}"; do
  outdir="Server/wwwroot/Content/${projects[$proj]}"
  mkdir -p "$outdir"
  echo "Publishing $proj to $outdir"
  dotnet publish -c Release -o "$outdir" "$proj"
done

echo "All client projects published to Server/wwwroot/Content/"