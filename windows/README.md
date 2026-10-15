# HumanTyper cho Windows

Yêu cầu .NET 8 SDK. Chạy từ thư mục dự án:

```powershell
dotnet run --project windows -- tsst
dotnet run --project windows -- --dry-run
```

Bản Windows dùng `user32.dll`/`SendInput`, nên cần chạy trong phiên desktop tương tác. Enter và Tab được gửi bằng phím Windows thật; các modifier Windows dùng `Ctrl`, `Alt`, `Shift`, `Win` thay cho `Command`, `Option` của macOS. Đưa chuột vào góc trên-trái, nhấn Pause/Break hoặc Ctrl+Alt+Shift+Esc để dừng.

Windows đọc cùng `settings.json` tiếng Việt camelCase với macOS: `tocDoTuMoiPhut`, `demNguocGiay`, `batLoiCoY`, `tyLeLoiPhanTram`, `batNhipTuNhien` và `batLuuLichSu`. Hiện bản Windows áp dụng tốc độ, lỗi gõ và nhịp tự nhiên; các thao tác Google Docs đặc thù như bảng, `{save}` và `[sai, đúng]` vẫn dùng bản macOS.

Nội dung UTF-8, tốc độ, lỗi gõ và dry-run được hỗ trợ. Các shortcut Google Docs cần dùng bản Windows (ví dụ Tool Finder `Alt+/`, lịch sử phiên bản `Ctrl+Alt+Shift+H`); không dùng mã phím macOS.
