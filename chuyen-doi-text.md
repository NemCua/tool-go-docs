# Hướng dẫn chuyển đổi nội dung sang file `.txt`

File trong thư mục `input/` phải là văn bản UTF-8. Công cụ sẽ gõ nội dung theo đúng thứ tự, nhận diện bảng, directive lưu/sửa và một số công thức LaTeX đơn giản.

## 1. Văn bản thường

Dán văn bản trực tiếp vào file `.txt`. Giữ xuống dòng nếu muốn tạo đoạn mới.

```text
Đây là đoạn đầu tiên.

Đây là đoạn thứ hai.
```

Không dùng Markdown cho tiêu đề, in đậm hay danh sách nếu không muốn các dấu `#`, `*`, `-` bị gõ ra tài liệu.

## 2. Bảng

Chỉ dùng đúng cú pháp dưới đây. Số hàng/cột trong khai báo phải khớp hoàn toàn với dữ liệu.

```text
[[TABLE 3x2]]
Tên | Tuổi
An | 20
Bình | 22
[[ENDTABLE]]
```

- `[[TABLE 3x2]]`: 3 hàng, 2 cột.
- Khi ước tính thời gian, mỗi hàng cộng 1 giây và mỗi cột cộng 1 giây; bảng 3x2 cộng 5 giây.
- Mỗi hàng phải có đúng số ô; ngăn cách ô bằng dấu `|`.
- Không để thêm dấu `|` ở đầu/cuối hàng.
- Không chèn dòng trống trong bảng.
- Đặt bảng ở cuối tài liệu nếu đang thử, để dễ kiểm tra vị trí con trỏ.

## 3. Lỗi gõ và sửa thủ công

Dùng `[phần sai, phần đúng]`. Có thể bọc directive bằng backtick; các dấu directive sẽ không bị gõ vào Google Docs.

```text
Xây dựng `[tap, tập]` từ vựng.
`[helllo yoou, hello you]`
```

Công cụ sẽ gõ phần sai, thực hiện luồng lưu/sửa đã cấu hình, Backspace đúng độ dài phần sai, rồi gõ phần đúng.

Lưu ý:

- Mỗi directive chỉ dùng một dấu phẩy phân cách phần sai và phần đúng.
- Không xuống dòng bên trong directive.
- Không dùng `]` bên trong hai phần của directive.

## 4. Lưu lịch sử tại vị trí xác định

Đặt `{save}` hoặc `` `{save}` `` tại nơi muốn mở lịch sử phiên bản.

```text
Xây dựng tập từ vựng {save} theo thứ tự chữ cái.
```

Directive sẽ không được gõ ra tài liệu. Công cụ chờ theo `choTruocLuuGiay`, mở lịch sử trong `xemLuuLichSuGiay`, sau đó chờ `choSauLuuGiay` rồi tiếp tục.

## 5. Công thức LaTex

Đặt công thức inline trong `\(` và `\)`, hoặc công thức khối trong `\[` và `\]`.

```text
Giá trị là \(\frac{a}{b}\).

\[
\boxed{v(D₁)=(0;\ 0;\ 0,0719)}
\]
```

Công cụ chuyển một số lệnh phổ biến sang văn bản Unicode:

```text
\frac{a}{b}   → (a)/(b)
\boxed{x}     → x
\leq          → ≤
\geq          → ≥
\in           → ∈
\to           → →
\Rightarrow   → →
\; hoặc \,    → khoảng trắng LaTex bị bỏ
```

Không dùng công thức LaTex quá phức tạp, macro tự định nghĩa, ảnh công thức hoặc môi trường như `align`, `matrix`, `cases` nếu cần kết quả chính xác trong Google Docs.

## 6. Checklist trước khi chạy

1. Lưu file ở UTF-8, đuôi `.txt`, trong thư mục `input/`.
2. Kiểm tra `[[TABLE ...]]` có đủ `[[ENDTABLE]]` và đúng số hàng/cột.
3. Kiểm tra directive `[sai, đúng]` không chứa dấu `]` hoặc xuống dòng.
4. Kiểm tra `{save}` viết đúng chính tả.
5. Chạy thử an toàn:

```sh
./run.sh ten-file --dry-run
```

6. Khi số ký tự và số bảng đúng, mở Google Docs, đặt con trỏ, rồi chạy bình thường:

```sh
./run.sh ten-file
```

## 7. Preview trước khi gõ

Chạy `npm run web`, mở `http://localhost:4173` rồi chọn **Preview tài liệu**. Bấm **Nạp testText.txt**, **Chọn tệp**, hoặc dán trực tiếp nội dung; sau đó bấm **Cập nhật preview** để xem bản mô phỏng dạng trang giấy. Preview dùng cùng quy tắc chuyển đổi với bản macOS: directive, bảng, `\\frac`, `\\boxed`, ký hiệu và chỉ số dưới; đây là kiểm tra trước khi chạy, không thay thế kiểm tra Google Docs thật.

## 8. Bảng tiến độ khi chạy trên macOS

Khi chạy bình thường, panel kính mờ tối native hiện ở góc phải với trạng thái chữ lớn, thời gian ở hàng riêng, số ký tự, phần trăm, thanh tiến độ và animation đếm ngược. Panel ép giao diện tối để luôn đủ tương phản cả trong macOS Light Mode. Bảng không có nút chuột; dùng phím dừng khẩn cấp nếu cần dừng. Ước tính gồm WPM, nhịp tự nhiên, số lần lưu tự động suy ra từ tổng ký tự và khoảng min/max, lỗi dự kiến theo khoảng lỗi/giới hạn mỗi chu kỳ, từng directive sửa hoặc `{save}`, cùng thời gian tạo bảng. Mỗi lần sửa lỗi được tính một lần lưu; xác suất lưu trước khi sửa chỉ đổi vị trí lần lưu. Ước tính được tính lại khi trạng thái đổi hoặc tối đa mỗi 2 giây, không giảm từng giây. Bảng tự đóng khi hoàn tất và không lấy focus khỏi Google Docs.
