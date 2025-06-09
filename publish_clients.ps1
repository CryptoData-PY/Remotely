# PowerShell script to publish all client projects to Server/wwwroot/Content

param (
    [string]$Hostname = "https://remotely.redfox.lan:8081/"  # Default hostname
)

$projects = @{
    "Agent\Agent.csproj" = "Agent"
    "Desktop.Win\Desktop.Win.csproj" = @{ OutDir = "Win-x64"; RID = "win-x64" }
    "Desktop.Linux\Desktop.Linux.csproj" = @{ OutDir = "Linux-x64"; RID = "linux-x64" }
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
    $projValue = $projects[$proj]
    if ($projValue -is [string]) {
        $outdir = "Server\wwwroot\Content\$projValue"
        New-Item -ItemType Directory -Force -Path $outdir | Out-Null
        Write-Host "Publishing $proj to $outdir (framework-dependent)"
        dotnet publish -c Release -o $outdir $proj
    } else {
        $outdir = "Server\wwwroot\Content\$($projValue.OutDir)"
        $rid = $projValue.RID
        New-Item -ItemType Directory -Force -Path $outdir | Out-Null
        Write-Host "Publishing $proj to $outdir (RID: $rid, self-contained)"
        dotnet publish -c Release -r $rid --self-contained true -o $outdir $proj
    }
}

# Update client configuration with hostname
$configFiles = Get-ChildItem -Path "Server\wwwroot\Content\*" -Recurse -Filter "appsettings.json"
foreach ($file in $configFiles) {
    $config = Get-Content -Path $file.FullName | ConvertFrom-Json
    $config.ServerUrl = $Hostname
    $config | ConvertTo-Json | Set-Content -Path $file.FullName
}

Write-Host "All client projects published to Server/wwwroot/Content/ with hostname: $Hostname"