# Sản phẩm minh họa Bảy Hải

Theo yêu cầu của chủ ngày 04/11/2026: 4 sản phẩm mã MAU-*, tên có [Mẫu], giá và tồn kho đều minh họa để tùy chỉnh sau. Không dùng tồn minh họa làm số kiểm kê thực tế.

- Gạch 60×60: 180.000 đ/m², tồn 72 m², 1 thùng = 1,44 m².
- Gạch 30×60: 150.000 đ/m², tồn 43,2 m², 1 thùng = 1,44 m² (quy đổi mẫu, cần kiểm tra thực tế).
- Đá 1×2: 420.000 đ/m³, tồn 20 m³.
- Cát: 350.000 đ/m³, tồn 25 m³.

Ảnh gạch, đá và cát tạo bằng công cụ ImageGen tích hợp, là hình minh họa AI, không phải ảnh chụp hàng thật của cửa hàng. Bản gốc `*-original.png`, ảnh dùng trong app `gach.jpg`, `da.jpg`, `cat.jpg` (420×420, mỗi ảnh dưới 40 KB). Gạch 30×60 đang dùng chung ảnh minh họa vân trắng, cần thay ảnh thật sau. Prompts được lưu trong prompts.json.

`catalog.json` là dữ liệu đầu vào; `tools/seed-sample-products.cjs` mặc định chỉ xem kế hoạch. Chỉ `--apply` mới ghi; bỏ qua mã/id đã có, tạo trong một commit với điều kiện revision, không thay tài khoản/đơn/công nợ/quyền hoặc Rules. Ảnh được lưu vào trường images của từng sản phẩm trên Firestore theo cơ chế hiện có, không cần bật Storage hoặc thanh toán.

Đã thực hiện một lần, Firebase xác nhận tạo đủ 4 sản phẩm, revision 1 và đọc kiểm tra lại 4/4. Commit time máy chủ: 2026-11-03T18:07:09.537182Z (01:07 ngày 04/11 theo Asia/Saigon).

Đơn vị m³ được nhận diện khi trường Kích thước / đơn vị là chính xác `m³`; các kích thước gạch cũ vẫn là m². Cách này giữ nguyên schema sản phẩm và bộ Rules đã triển khai. Mỗi dòng đơn bán mới chụp lại đơn vị để PDF/chi tiết không dùng lẫn m² và m³. Không cho đổi giữa hai đơn vị nếu mã hàng đã có tồn hoặc lịch sử bán.
