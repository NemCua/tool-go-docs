# Yêu cầu chạy HumanTyper trên Windows

## Máy và hệ điều hành

- Windows 10 hoặc Windows 11 có desktop tương tác. Không chạy được trong Windows Server Core hoặc phiên RDP không có giao diện desktop.
- Bản `win-x64` dành cho Intel/AMD 64-bit; `win-arm64` dành cho Windows ARM.
- Độ phân giải bất kỳ; panel tiến độ hiển thị ở góc trên-phải của màn hình đang đặt chuột lúc chạy.

## Cách chạy

Chạy từ source cần .NET 8 SDK. Bản publish self-contained không cần cài .NET.

```powershell
dotnet run --project windows -- ten-file --dry-run
dotnet run --project windows -- ten-file
```

File `settings.json` và thư mục `input/` phải ở thư mục gốc dự án (hoặc cạnh bản publish). Input phải UTF-8 và có đuôi `.txt`.

## Trình duyệt và Google Docs

- Dùng Chrome, Edge hoặc Brave bản desktop; không dùng cửa sổ ẩn/minimized.
- Đặt con trỏ trong Google Docs trước khi countdown kết thúc.
- Trình duyệt và HumanTyper phải chạy cùng mức quyền. Nếu trình duyệt mở Administrator, PowerShell/HumanTyper cũng phải mở Administrator.
- Bảng tự động hiện gửi tên Tool Finder tiếng Việt, vì vậy giao diện Google Docs cần dùng tiếng Việt.
- Không gõ chuột/bàn phím trong lúc công cụ đang chạy, ngoại trừ phím dừng khẩn cấp.

## Lỗi sửa và lưu lịch sử

- Khi `batLoiCoY` bật, HumanTyper cố ý gõ sai rồi gửi Backspace để xóa và gõ lại đúng.
- `batLuuLichSu` bật sẽ dùng `Ctrl + Alt + Shift + H` để mở Version history. Google Docs phải nhận shortcut này; nếu tài khoản/chính sách tổ chức chặn Version history, đặt `batLuuLichSu: false` để vẫn dùng sửa lỗi nhưng không mở lịch sử.
- Directive `{save}` yêu cầu Version history khả dụng. Directive `[sai, đúng]` vẫn sửa được khi `batLuuLichSu` tắt.

## Dừng khẩn cấp

- `Pause/Break`.
- `Ctrl + Alt + Shift + Escape`.
- Đưa chuột vào góc trên-trái màn hình.

## Mạng và tải code

- Cần HTTPS ra GitHub để tải source/ZIP và `dot.net` để cài SDK.
- Máy cloud thiếu Git hoặc winget vẫn dùng được ZIP GitHub và script `dotnet-install.ps1`.
- Kiểm tra an toàn bằng `--dry-run` trước; sau đó thử file ngắn trước khi gõ tài liệu thật.
