# PowerShell script to publish all client projects to Server/wwwroot/Content

$projects = @{
    "Agent\Agent.csproj" = "Agent"
    "Desktop.Win\Desktop.Win.csproj" = "Win-x64"
    "Desktop.Linux\Desktop.Linux.csproj" = "Linux-x64"
    "Desktop.Core\Desktop.Core.csproj" = "Core"
    "Desktop.Shared\Desktop.Shared.csproj" = "Shared"
    "Desktop.UI\Desktop.UI.csproj" = "UI"
    "Desktop.Native\Desktop.Native.csproj" = "Native"
    # Add more as needed
}

# Clean old content
Remove-Item -Recurse -Force Server\wwwroot\Content\* 2>$null
New-Item -ItemType Directory -Force -Path Server\wwwroot\Content | Out-Null

foreach ($proj in $projects.Keys) {
    $outdir = "Server\wwwroot\Content\$($projects[$proj])"
    New-Item -ItemType Directory -Force -Path $outdir | Out-Null
    Write-Host "Publishing $proj to $outdir"
    dotnet publish -c Release -o $outdir $proj
}

Write-Host "All client projects published to Server/wwwroot/Content/"