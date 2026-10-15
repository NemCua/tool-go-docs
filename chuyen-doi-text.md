# Chuyển nội dung AI thành file HumanTyper

File này hướng dẫn AI biến văn bản thô thành file `.txt` chuẩn cho HumanTyper. Bạn chỉ cần đưa nội dung AI tạo ra cho một AI khác cùng prompt bên dưới; kết quả là file sạch để đặt vào `input/` và chạy, không cần tự sửa thủ công.

## Prompt chuẩn hóa

```text
Bạn là người chuẩn hóa file input cho công cụ HumanTyper.

Input là nội dung thô do tôi cung cấp. Hãy chuyển nó thành nội dung UTF-8 chuẩn để lưu thành file .txt trong thư mục input/.

Yêu cầu:
1. Giữ nguyên nội dung, thứ tự, ngôn ngữ, số liệu và ý nghĩa.
2. Không tự thêm lời giải thích, nhận xét hoặc nội dung mới.
3. Giữ các xuống dòng có ý nghĩa. Không dùng Markdown cho tiêu đề, danh sách hoặc in đậm nếu các dấu đó không phải nội dung cần gõ.
4. Chuyển mọi bảng thành cú pháp:
   [[TABLE số_hàngxsố_cột]]
   ô 1 | ô 2
   [[ENDTABLE]]
   Số hàng và số cột phải khớp chính xác dữ liệu.
5. Nếu cần lưu tại một vị trí, đặt `{save}` đúng vị trí đó.
6. Nếu có cặp sai/đúng, dùng `[sai, đúng]`; có thể bọc bằng backtick.
7. Giữ công thức đơn giản trong \(...\) hoặc \[...\], dùng các lệnh HumanTyper hỗ trợ như \frac, \boxed, \leq, \geq, \in, \to và chỉ số dưới.
8. Không trả về bảng Markdown, HTML, JSON, code fence hoặc chú thích trong nội dung file.
9. Kiểm tra không còn bảng thiếu [[ENDTABLE]], directive bị xuống dòng, dấu ] làm hỏng directive hoặc ký tự điều khiển thừa.

Chỉ trả về nội dung file .txt hoàn chỉnh trong một code block plain text. Không viết gì trước hoặc sau code block.

Nội dung cần chuyển:
--- BẮT ĐẦU INPUT ---
[DÁN NỘI DUNG Ở ĐÂY]
--- KẾT THÚC INPUT ---
```

Lấy phần bên trong code block, lưu bằng UTF-8 vào `input/ten-file.txt`, rồi kiểm tra:

```sh
./run.sh ten-file --dry-run
./run.sh ten-file
```

Trên Windows dùng cùng file output:

```powershell
dotnet run --project windows -- ten-file --dry-run
dotnet run --project windows -- ten-file
```

Nếu file có bảng, Google Docs trên Windows hiện cần đặt ngôn ngữ giao diện là tiếng Việt để Tool Finder nhận đúng tên lệnh bảng.

Khi kiểm tra directive `[sai, đúng]` trên Windows, có thể đặt `batLuuLichSu: false` trong `settings.json` nếu tài khoản Google Docs không mở được Version history bằng `Ctrl + Alt + Shift + H`; công cụ vẫn xóa phần sai và gõ lại phần đúng.

## Ví dụ chuyển đổi

### Bảng

Input thô:

```text
Tên | Điểm | Ghi chú
An | 9,5 | Đạt
Bình | 8,0 | Cần ôn
```

Output chuẩn:

```text
[[TABLE 3x3]]
Tên | Điểm | Ghi chú
An | 9,5 | Đạt
Bình | 8,0 | Cần ôn
[[ENDTABLE]]
```

Khai báo `3x3` gồm cả dòng tiêu đề.

### Sửa thủ công

```text
Từ `[chuwx nayf, chữ này]` được sửa tại chỗ.
```

HumanTyper sẽ gõ phần sai, chạy luồng lưu/sửa, xóa phần sai và gõ phần đúng.

### Lưu tại vị trí

```text
Xây dựng tập từ vựng `{save}` theo thứ tự.
```

`{save}` là lệnh điều khiển, không xuất hiện trong Google Docs.

### Công thức

```text
Phân số: \(\frac{a+b}{c}\).
Ký hiệu: \(x\in A\to x\leq 10\) và \(n_1\neq n_2\).

\[
\boxed{v(D₁)=(0;\ 0;\ 0{,}0719;\ 0{,}1733)}
\]
```

HumanTyper chuyển các lệnh được hỗ trợ thành văn bản Unicode khi nhập. Với công thức phức tạp, yêu cầu AI chuyển thành văn bản Unicode đơn giản.

## Checklist

- File là UTF-8 và có đuôi `.txt`.
- Bảng có đủ `[[ENDTABLE]]`, đúng số hàng/cột.
- Directive sửa có đúng một dấu phẩy: `[sai, đúng]`.
- `{save}` nằm đúng vị trí cần lưu.
- Không còn code fence, JSON, HTML hoặc lời giải thích của AI trong file.
- Chạy `--dry-run` trước khi gửi phím.
- Dùng `npm run web` để xem Preview nếu cần.
