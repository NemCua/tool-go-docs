# HumanTyper cho Windows

Yêu cầu .NET 8 SDK. Chạy từ thư mục dự án:

```powershell
dotnet run --project windows -- tsst
dotnet run --project windows -- --dry-run
```

Bản Windows dùng `user32.dll`/`SendInput`, nên cần chạy trong phiên desktop tương tác. Enter và Tab được gửi bằng phím Windows thật; các modifier Windows dùng `Ctrl`, `Alt`, `Shift`, `Win` thay cho `Command`, `Option` của macOS. Đưa chuột vào góc trên-trái, nhấn Pause/Break hoặc Ctrl+Alt+Shift+Esc để dừng.

Windows đọc cùng `settings.json` tiếng Việt camelCase với macOS: tốc độ, countdown, lỗi gõ, nhịp tự nhiên, lưu lịch sử và các khoảng ký tự min/max. Khi chạy thật, Windows hiện panel nền tối ở góc trên bên phải, luôn nổi trên cửa sổ khác, gồm thời gian còn lại ước tính, thời gian thực đã chạy, số ký tự, phần trăm và thanh tiến độ. Sau khi hoàn tất, panel hiện tổng thời gian 4 giây rồi tự đóng.

Nội dung UTF-8, tốc độ, lỗi gõ, nhịp tự nhiên và dry-run được hỗ trợ. Các shortcut Google Docs cần dùng bản Windows (ví dụ Tool Finder `Alt+/`, lịch sử phiên bản `Ctrl+Alt+Shift+H`); không dùng mã phím macOS.
