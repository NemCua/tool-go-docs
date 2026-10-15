# Đầu ra mong đợi — `input/testText.txt`

Chạy kiểm tra parser:

```sh
./run.sh testText --dry-run
```

Khi gõ vào Google Docs, các heading Markdown (`#`, `##`) được gõ nguyên văn vì đây là file văn bản thuần. Phần nội dung phải xuất hiện theo đúng thứ tự, gồm Unicode, emoji, tab, xuống dòng và một bảng 3×3.

Các directive **không** được gõ nguyên văn:

| Input | Hành vi mong đợi |
| --- | --- |
| `` `[tap, tập]` `` | Gõ `tap`, lưu/sửa theo setting, xóa `tap`, sau đó còn `tập`. |
| `` `{save}` `` hoặc `{save}` | Chỉ mở/lưu lịch sử tại đúng vị trí; không có ký tự directive trong Docs. |
| `` `[helllo yoou, hello you]` `` | Kết quả cuối là `hello you`. |
| `` `chuwx nayf, chữ này` `` | Kết quả cuối là `chữ này`. |

Kết quả LaTex mong đợi:

```text
(a+b)/(c)
x∈ A→ x≤ 10 và n₁≠ n₂
v(D₁)=(0; 0; 0,0719; 0,1733)
```

Trong Google Docs, bảng có 3 hàng và 3 cột, sau đó con trỏ phải ở sau bảng trước câu “Đây là dòng kiểm tra…”.

## Đánh giá

- Nếu `--dry-run` báo lỗi bảng: kiểm tra lại số hàng/cột và dấu `|`.
- Nếu directive bị gõ ra: kiểm tra nó đúng dạng `[sai, đúng]` hoặc `{save}`, có thể bọc bằng backtick.
- Nếu LaTex còn dấu `\boxed` hoặc `\;`: cập nhật binary bằng `./build.sh` rồi chạy lại.
