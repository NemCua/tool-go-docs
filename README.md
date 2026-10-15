# HumanTyper cho macOS

CLI nhập lại nội dung của file UTF-8 bằng sự kiện bàn phím macOS, với tốc độ biến thiên và lỗi đánh máy được sửa lại. Tốc độ mặc định là 120 WPM; sau mỗi mốc ngẫu nhiên 180–300 ký tự, công cụ nghỉ 5 giây, mở lịch sử phiên bản trong 5 giây, nghỉ thêm 5 giây rồi tiếp tục gõ.

## Biên dịch

```sh
chmod +x build.sh
./build.sh
```

Máy cần có Xcode Command Line Tools. Nếu lệnh `swiftc` chưa tồn tại, cài bằng:

```sh
xcode-select --install
```

## Chuẩn bị nội dung

Đặt file `.txt` vào thư mục `input/`. Chọn theo tên (có thể bỏ đuôi `.txt`):

```sh
./run.sh tsst
```

Nếu không truyền tên, thư mục phải chứa đúng một file `.txt`.

## Cấu hình

Chỉnh [settings.json](settings.json) để thay đổi tốc độ, đếm ngược, lỗi gõ và chu kỳ lịch sử. Toàn bộ khóa dùng tiếng Việt camelCase. `khoangKyTuLoiToiThieu`/`khoangKyTuLoiToiDa` là khoảng ký tự giữa các lỗi; `soLoiMoiDotToiThieu`/`soLoiMoiDotToiDa` là số lỗi ngẫu nhiên trong một đợt. `xacSuatLuuTruocKhiSua: 0.5` nghĩa là 50% lưu lịch sử trước khi sửa, 50% sửa trước rồi mới lưu.

`xacSuatLoiTelex` (0–1, mặc định `0.75`) xác định xác suất dùng lỗi Telex cho từ tiếng Việt có dấu, chẳng hạn `chữ` thành `chuwx` và `này` thành `nayf`. Các lỗi còn lại được chọn ngẫu nhiên giữa lặp ký tự, thiếu ký tự, đảo hai ký tự kề nhau và phím gần nhau.

## Chỉ gõ văn bản

Để gõ thuần văn bản, không lỗi có chủ ý, không lưu lịch sử và không thao tác sửa, truyền tốc độ ngay sau tên file:

```sh
./run.sh testText 500
```

Lệnh trên đọc `input/testText.txt` và gõ ở 500 WPM. Hoặc đặt `"chiGoVanBan": true` trong `settings.json`, rồi chạy ngắn gọn:

```sh
./run.sh testText
```

## Kiểm tra mà không gửi phím

```sh
./run.sh --dry-run
```

## Chạy

Mở Google Docs, đặt định dạng và vị trí con trỏ mong muốn. Sau đó quay lại Terminal và chạy:

```sh
./run.sh
```

Chương trình mặc định đếm ngược 15 giây. Trong thời gian đó, chuyển sang Google Docs trên Brave hoặc Chrome và đặt con trỏ tại vị trí cần nhập. Công cụ gõ vào cửa sổ đang được chọn nên không phụ thuộc trình duyệt.

Có ba cách dừng khẩn cấp, đều hoạt động dù Google Docs đang được focus:

- Nhấn phím **`** (phím vật lý ngay dưới Escape).
- Nhấn **Control + Option + Command + Escape**.
- Đưa con trỏ chuột sát vào **góc trên-trái của màn hình chính**.

Escape thường được dành cho chương trình tự đóng giao diện lịch sử phiên bản. Sau mỗi mốc ngẫu nhiên 180–300 ký tự, công cụ nghỉ 5 giây, gửi `Command + Option + Shift + H`, chờ 5 giây rồi gửi Escape để quay lại trang viết, sau đó nghỉ thêm 5 giây. Google Docs vẫn tự quyết định cách nhóm và lưu các phiên bản.

Lần đầu chạy, macOS sẽ yêu cầu quyền **Privacy & Security → Accessibility** cho Terminal (hoặc ứng dụng terminal bạn đang dùng). Cấp quyền rồi chạy lại lệnh.

Các tuỳ chọn đầy đủ:

```text
--wpm N          tốc độ trung bình (5–300)
--error-rate N   tỷ lệ phần trăm lỗi (0–30)
--countdown N    thời gian chuyển cửa sổ (0–60 giây)
--seed N         tái tạo cùng chuỗi ngẫu nhiên
--no-errors      tắt lỗi cố ý
--no-history     không tự mở lịch sử phiên bản và nghỉ dài
--dry-run        không gửi sự kiện bàn phím
```

Lưu ý: tiện ích nhập văn bản thuần. Nội dung sẽ kế thừa định dạng đang đặt tại con trỏ; tab có thể làm đổi ô hoặc điều khiển giao diện tuỳ ứng dụng đích.

## Bảng trong Google Docs

Dùng cú pháp sau trong file `.txt`:

```text
[[TABLE 3x2]]
Tên | Tuổi
An | 20
Bình | 22
[[ENDTABLE]]
```

Số dòng dữ liệu và số ô phân cách bằng `|` phải khớp kích thước đã khai báo. Công cụ dùng Tool Finder tiếng Việt của Google Docs để tạo bảng 2×2, điều chỉnh số hàng/cột bằng các lệnh bảng, đưa con trỏ về ô đầu rồi nhập lần lượt các ô; bảng thử nên đặt cuối tài liệu.
