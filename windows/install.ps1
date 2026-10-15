$ErrorActionPreference = "Stop"
$project = "C:\HumanTyper"
$repo = "https://github.com/NemCua/tool-go-docs-windows.git"
$branch = "windows"
$localDotnet = "$env:USERPROFILE\.dotnet"

if ((Test-Path "$project\.git") -and (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Cập nhật HumanTyper..."
    git -C $project fetch origin $branch
    git -C $project checkout $branch
    git -C $project pull --ff-only origin $branch
} elseif (Test-Path $project) {
    Write-Host "Dùng HumanTyper đã có tại C:\HumanTyper."
} elseif (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host "Tải HumanTyper bằng Git..."
    git clone --branch $branch --single-branch $repo $project
} else {
    Write-Host "Không có Git, tải HumanTyper bằng ZIP..."
    $zip = "$env:TEMP\HumanTyper-windows.zip"
    $extract = "$env:TEMP\HumanTyper-windows"
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/NemCua/tool-go-docs-windows/archive/refs/heads/windows.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $source = Get-ChildItem $extract -Directory | Select-Object -First 1
    Move-Item -Path $source.FullName -Destination $project
}

$hasSdk8 = (Get-Command dotnet -ErrorAction SilentlyContinue) -and ((dotnet --list-sdks) -match "^8\.")
if (-not $hasSdk8) {
    Write-Host "Cài .NET 8 SDK..."
    $installer = "$env:TEMP\dotnet-install.ps1"
    Invoke-WebRequest -UseBasicParsing -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $installer
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -Channel 8.0 -Architecture x64 -InstallDir $localDotnet
    $env:Path = "$localDotnet;$env:Path"
}

Set-Location $project
$dotnet = if (Test-Path "$localDotnet\dotnet.exe") { "$localDotnet\dotnet.exe" } else { "dotnet" }
& $dotnet --version
& $dotnet run --project windows -- testText --dry-run
Write-Host "Hoàn tất. Chạy thật: cd C:\HumanTyper; & `"$dotnet`" run --project windows -- testText"
