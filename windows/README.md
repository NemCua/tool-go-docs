# HumanTyper cho Windows

Yêu cầu Windows 10/11 và .NET 8 SDK khi chạy từ source.

Xem checklist đầy đủ về máy cloud, quyền, trình duyệt, Google Docs, Version history và đóng gói tại [REQUIREMENTS.md](REQUIREMENTS.md). Cài nhanh trên máy mới/máy cloud, có kiểm tra Git/winget/.NET tự động, xem [CAI-DAT-MAY-MOI.md](CAI-DAT-MAY-MOI.md).

## Chạy

Mở PowerShell tại thư mục gốc dự án:

```powershell
dotnet run --project windows -- ten-file
dotnet run --project windows -- ten-file --dry-run
```

Đặt file UTF-8 trong `input/`. Tên file có thể có hoặc không có `.txt`. Chương trình tìm `settings.json` và `input/` từ thư mục hiện hành hoặc cạnh bản build.

## Chức năng

Bản Windows dùng chung cú pháp và `settings.json` với macOS:

- Gõ Unicode, tiếng Việt, emoji, Enter và Tab bằng `SendInput`.
- Lỗi ngẫu nhiên theo cụm, xóa và gõ lại đúng.
- `{save}` và `[sai, đúng]`.
- Chuyển LaTeX đơn giản sang Unicode.
- Tạo và nhập bảng `[[TABLE ...]]`.
- Lưu lịch sử Google Docs bằng `Ctrl + Alt + Shift + H`.
- Nhịp gõ tự nhiên và các khoảng chờ trong settings.
- Dry-run và các tùy chọn `--wpm`, `--error-rate`, `--countdown`, `--seed`, `--no-errors`, `--no-history`.

Panel không lấy focus, luôn nổi ở góc trên bên phải. Panel hiện countdown, thời gian ước tính, thời gian thực, ký tự còn lại và tiến độ; khi hoàn tất hiện tổng thời gian 4 giây rồi tự đóng.

## Khác biệt hệ điều hành

- Windows dùng `Ctrl`/`Alt`/`Shift`; macOS dùng `Command`/`Option`/`Control`.
- Tool Finder của Google Docs trên Windows mở bằng `Alt + /`.
- Chương trình hiện gửi tên lệnh bảng bằng tiếng Việt (`Chèn bảng`, `Chèn cột bên phải`, `Chèn hàng bên dưới`, `Xóa cột`, `Xóa hàng`), nên giao diện Google Docs phải dùng tiếng Việt để tạo bảng tự động.
- `SendInput` không điều khiển được ứng dụng chạy quyền Administrator nếu HumanTyper chạy quyền thường. Nên chạy trình duyệt và HumanTyper cùng mức quyền.
- Panel dùng WinForms và `user32.dll`, không chạy trên macOS/Linux.

Dừng khẩn cấp bằng `Pause/Break`, `Ctrl + Alt + Shift + Escape`, hoặc đưa chuột vào góc trên-trái màn hình chính.

## Đóng gói

Tạo file chạy độc lập, không yêu cầu người dùng cài .NET:

```powershell
powershell -ExecutionPolicy Bypass -File windows\publish.ps1 -Runtime win-x64
```

Máy Windows ARM dùng:

```powershell
powershell -ExecutionPolicy Bypass -File windows\publish.ps1 -Runtime win-arm64
```

Kết quả nằm trong `windows\publish\win-x64` hoặc `windows\publish\win-arm64`. Khi chuyển sang máy khác, đặt `settings.json` và thư mục `input` cạnh file chạy hoặc chạy file từ thư mục dự án.

## Kiểm tra trước khi phát hành

1. Chạy `--dry-run` với `input/testText.txt`.
2. Kiểm tra tiếng Việt, emoji, xuống dòng, directive và bảng trong Preview.
3. Mở Google Docs tiếng Việt, đặt con trỏ rồi chạy thử một file ngắn.
4. Xác nhận panel không lấy focus khỏi trình duyệt.
5. Thử phím dừng khẩn cấp.
6. Thử đúng gói `win-x64` hoặc `win-arm64` trên máy đích.
