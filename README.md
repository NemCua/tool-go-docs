# HumanTyper

HumanTyper nhận file `.txt`, chuyển nội dung về dạng Google Docs có thể nhập ổn định rồi gõ bằng sự kiện bàn phím. Công cụ có bản macOS và Windows.

## Chạy trên macOS

Cài Xcode Command Line Tools, sau đó build:

```sh
xcode-select --install
chmod +x build.sh run.sh
./build.sh
```

Đặt file UTF-8 vào `input/` rồi chạy:

```sh
./run.sh ten-file
```

Có thể bỏ đuôi `.txt`. Nếu không truyền tên file, `input/` phải có đúng một file `.txt`. Mở Google Docs, đặt con trỏ, chạy lệnh và chuyển sang Google Docs trong countdown. Lần đầu chạy cần cấp quyền Accessibility cho Terminal tại **System Settings → Privacy & Security → Accessibility**.

## Kiểm tra trước khi gõ

```sh
./run.sh ten-file --dry-run
```

Dry-run chỉ đọc và thống kê file, không gửi phím. Kết quả gồm số ký tự, thời gian ước tính, số lần lưu, directive và bảng.

## Tùy chọn dòng lệnh

```text
--wpm N          tốc độ gõ, từ 5 đến 1000
--error-rate N   tỷ lệ lỗi từ 0 đến 30 phần trăm
--countdown N    countdown từ 0 đến 60 giây
--seed N         dùng lại cùng chuỗi ngẫu nhiên
--no-errors      tắt lỗi tự động
--no-history     tắt lưu lịch sử định kỳ
--dry-run        chỉ thống kê, không gửi phím
```

Dừng khẩn cấp bằng phím backtick dưới Escape, `Control + Option + Command + Escape`, hoặc đưa chuột vào góc trên-trái màn hình.

## Cấu hình

Sửa trực tiếp [settings.json](settings.json). Các khóa dùng tiếng Việt camelCase.

| Khóa | Tác dụng |
| --- | --- |
| `tocDoTuMoiPhut` | Tốc độ gõ WPM. |
| `demNguocGiay` | Thời gian chuyển sang Google Docs. |
| `batLoiCoY` / `tyLeLoiPhanTram` | Bật lỗi tự động và tỷ lệ lỗi. |
| `batLuuLichSu` | Bật lưu lịch sử định kỳ. |
| `soKyTuLuuToiThieu` / `soKyTuLuuToiDa` | Khoảng ký tự giữa các lần lưu. |
| `choTruocLuuGiay` / `xemLuuLichSuGiay` / `choSauLuuGiay` | Ba khoảng chờ của một lần lưu. |
| `khoangKyTuLoiToiThieu` / `khoangKyTuLoiToiDa` | Khoảng ký tự giữa các cụm lỗi. |
| `soLoiMoiDotToiThieu` / `soLoiMoiDotToiDa` | Số lỗi trong một đợt. |
| `soTuCumSaiToiThieu` / `soTuCumSaiToiDa` | Số từ trong một cụm lỗi. |
| `xacSuatLoiTelex` | Xác suất dùng lỗi Telex. |
| `xacSuatLuuTruocKhiSua` | Xác suất lưu trước khi sửa lỗi. |
| `batNhipTuNhien` | Bật khựng tự nhiên và nghỉ dấu câu. |

## Cú pháp file input

### Văn bản thường

Gõ nội dung trực tiếp, giữ xuống dòng và tab nếu cần. Công cụ không tự hiểu Markdown; các dấu `#`, `*`, `-` sẽ được gõ như văn bản.

### Sửa thủ công

```text
Xây dựng `[tap, tập]` từ vựng.
`[helllo yoou, hello you]`
```

Công cụ gõ phần sai, chạy luồng lưu/sửa, xóa phần sai rồi gõ phần đúng. Backtick là tùy chọn. Không dùng dấu `]`, dấu phẩy phân cách hoặc xuống dòng bên trong directive.

### Lưu tại vị trí chỉ định

```text
Xây dựng tập từ vựng `{save}` theo thứ tự.
```

`{save}` không được gõ ra tài liệu; công cụ mở lịch sử tại vị trí đó theo `settings.json`.

### Bảng

```text
[[TABLE 3x2]]
Tên | Tuổi
An | 20
Bình | 22
[[ENDTABLE]]
```

Kích thước phải khớp dữ liệu, dùng `|` để ngăn cách ô. Ước tính cộng 1 giây cho mỗi hàng và 1 giây cho mỗi cột.

### Công thức

Hỗ trợ một số lệnh LaTeX đơn giản trong `\(...\)` hoặc `\[...\]`, gồm `\frac`, `\boxed`, `\leq`, `\geq`, `\in`, `\to` và chỉ số dưới. Công thức phức tạp như `align`, `matrix`, `cases` không được đảm bảo.

## Preview trên trình duyệt

```sh
npm run web
```

Mở `http://localhost:4173`. Preview đọc trực tiếp `settings.json`, mô phỏng nội dung sau chuyển đổi và tính thời gian ước tính. Có thể nạp `testText.txt`, chọn file `.txt` hoặc dán nội dung rồi bấm **Cập nhật preview**. Preview không gửi phím và không thay đổi Google Docs. Nếu sửa `settings.json`, tải lại trang.

## Bảng tiến độ macOS

Khi chạy thật, panel nền tối ở góc phải hiển thị trạng thái, thời gian còn lại ước tính, thời gian thực đã chạy, số ký tự, phần trăm và thanh tiến độ. Đồng hồ thực bắt đầu từ `00:00` sau countdown, tăng theo thời gian thật và hiện tổng thời gian trong 4 giây sau khi hoàn tất rồi tự đóng.

## Windows

Bản Windows nằm trong [windows/](windows/) và yêu cầu .NET 8 SDK:

```powershell
dotnet run --project windows -- ten-file
dotnet run --project windows -- ten-file --dry-run
```

Bản Windows dùng cùng `settings.json` và cú pháp input với macOS, gồm Unicode/emoji, lỗi rồi sửa, lịch sử, directive, LaTeX, bảng, dry-run và panel tiến độ không lấy focus. Windows dùng `Ctrl`, `Alt`, `Shift` thay cho phím macOS. Tạo bảng hiện yêu cầu giao diện Google Docs tiếng Việt. Cách chạy và đóng gói `win-x64`/`win-arm64` xem tại [windows/README.md](windows/README.md).

Các yêu cầu môi trường Windows/cloud (SDK hoặc bản self-contained, desktop tương tác, quyền ứng dụng, Version history, trình duyệt và mạng) nằm tại [windows/REQUIREMENTS.md](windows/REQUIREMENTS.md).

Khi thay đổi cú pháp hoặc hành vi, cập nhật đồng thời README này và [chuyen-doi-text.md](chuyen-doi-text.md).
