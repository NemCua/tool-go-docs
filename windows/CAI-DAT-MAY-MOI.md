# Lệnh cài HumanTyper trên máy Windows mới hoặc máy cloud

Tài liệu này dành cho máy Windows cũ hoặc cloud có thể thiếu Git, `winget` hoặc .NET. Lệnh cài tự kiểm tra thành phần nào đã có để dùng lại; thành phần thiếu sẽ được cài hoặc có phương án dự phòng.

## Cách nhanh nhất

Mở **PowerShell** (không cần Administrator), dán toàn bộ khối sau rồi chờ hoàn tất:

```powershell
$ErrorActionPreference = "Stop"
$project = "C:\HumanTyper"
$repo = "https://github.com/NemCua/tool-go-docs-windows.git"
$branch = "windows"
$localDotnet = "$env:USERPROFILE\.dotnet"

# 1) Tải/cập nhật code: ưu tiên Git; thiếu Git thì tải ZIP GitHub.
if ((Test-Path "$project\.git") -and (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Đã có Git repo, đang cập nhật..."
    git -C $project fetch origin $branch
    git -C $project checkout $branch
    git -C $project pull --ff-only origin $branch
} elseif (Test-Path $project) {
    Write-Host "Đã có thư mục $project nhưng không có Git, dùng code hiện có."
} elseif (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host "Đang tải bằng Git..."
    git clone --branch $branch --single-branch $repo $project
} else {
    Write-Host "Không có Git, đang tải ZIP GitHub..."
    $zip = "$env:TEMP\HumanTyper-windows.zip"
    $extract = "$env:TEMP\HumanTyper-windows"
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/NemCua/tool-go-docs-windows/archive/refs/heads/windows.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $source = Get-ChildItem $extract -Directory | Select-Object -First 1
    Move-Item -Path $source.FullName -Destination $project
}

# 2) Kiểm tra .NET SDK 8. Nếu đã có thì dùng luôn.
$hasSdk8 = (Get-Command dotnet -ErrorAction SilentlyContinue) -and ((dotnet --list-sdks) -match "^8\.")
if (-not $hasSdk8) {
    Write-Host "Chưa có .NET 8 SDK. Đang cài bản local..."
    $installer = "$env:TEMP\dotnet-install.ps1"
    Invoke-WebRequest -UseBasicParsing -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $installer
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer -Channel 8.0 -Architecture x64 -InstallDir $localDotnet
    $env:Path = "$localDotnet;$env:Path"
}

# 3) Kiểm tra và chạy dry-run. Không gửi phím vào Google Docs.
Set-Location $project
$dotnet = if (Test-Path "$localDotnet\dotnet.exe") { "$localDotnet\dotnet.exe" } else { "dotnet" }
& $dotnet --version
& $dotnet run --project windows -- testText --dry-run
```

Nếu máy có `winget` và bạn muốn cài Git để tiện cập nhật về sau, chạy thêm:

```powershell
winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
```

Lệnh cài phía trên không cần Git để chạy lần đầu.

## Chạy thật

Sau khi dry-run thành công:

```powershell
cd C:\HumanTyper
& "$env:USERPROFILE\.dotnet\dotnet.exe" run --project windows -- testText
```

Nếu máy dùng .NET cài toàn hệ thống thay vì bản local, dùng:

```powershell
dotnet run --project windows -- testText
```

Trong countdown, chuyển sang Google Docs và đặt con trỏ. Xem [REQUIREMENTS.md](REQUIREMENTS.md) trước khi chạy thật.

## Tạo file test riêng

```powershell
@"
Xin chào, đây là bài test Windows.

Từ `[helllo yoou, hello you]` được sửa tại chỗ.

[[TABLE 2x2]]
Tên | Điểm
An | 9,5
[[ENDTABLE]]
"@ | Set-Content -Encoding utf8 C:\HumanTyper\input\cloudTest.txt

cd C:\HumanTyper
& "$env:USERPROFILE\.dotnet\dotnet.exe" run --project windows -- cloudTest --dry-run
```

Nếu `batLuuLichSu` đang bật, Google Docs phải mở được Version history. Khi chỉ test lỗi rồi sửa, có thể tạm đặt `"batLuuLichSu": false` trong `settings.json`.

## Cập nhật code ở máy đã cài

Nếu máy có Git repo, chạy:

```powershell
git -C C:\HumanTyper pull --ff-only origin windows
```

Nếu máy được cài bằng ZIP, chạy lại khối **Cách nhanh nhất**. Khối đó giữ nguyên thư mục đang có để không tự ghi đè `settings.json` và input cá nhân; muốn lấy code mới theo ZIP, đổi tên thư mục cũ trước khi chạy lại:

```powershell
Rename-Item C:\HumanTyper C:\HumanTyper-cu
```
