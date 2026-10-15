# Cài HumanTyper trên Windows

Mở PowerShell và dán đúng một lệnh này:

```powershell
Invoke-Expression (Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/NemCua/tool-go-docs-windows/windows/windows/install.ps1").Content
```

Lệnh tự kiểm tra Git và .NET 8; có thì dùng, thiếu thì tự tải, sau đó tải HumanTyper và chạy dry-run `testText`.
