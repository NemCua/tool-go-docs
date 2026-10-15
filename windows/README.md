# HumanTyper cho Windows

Yêu cầu .NET 8 SDK. Chạy từ thư mục dự án:

```powershell
dotnet run --project windows -- tsst
dotnet run --project windows -- --dry-run
```

Bản Windows dùng `user32.dll`/`SendInput`, nên cần chạy trong phiên desktop tương tác. Đưa chuột vào góc trên-trái, nhấn Pause/Break hoặc Ctrl+Alt+Shift+Esc để dừng. Nội dung UTF-8, tốc độ, lỗi gõ và dry-run được hỗ trợ. Tự động mở Version history và tạo bảng Google Docs chưa port trong bản đầu này.
