from docx import Document
from docx.shared import Cm, Pt, RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from pathlib import Path

out = Path(__file__).parent / 'Tinh_nang_app_VLXD.docx'
doc = Document()
s = doc.sections[0]
s.page_width, s.page_height = Cm(21), Cm(29.7)
s.top_margin = s.bottom_margin = Cm(1.8)
s.left_margin = s.right_margin = Cm(2)
for name in ['Normal', 'Title', 'Subtitle', 'Heading 1', 'List Bullet']:
    st = doc.styles[name]
    st.font.name = 'Arial'
    st.font.color.rgb = RGBColor(0,0,0)
doc.styles['Normal'].font.size = Pt(11)
doc.styles['Normal'].paragraph_format.space_after = Pt(5)
doc.styles['Normal'].paragraph_format.line_spacing = 1.12
doc.styles['Title'].font.size = Pt(21)
doc.styles['Heading 1'].font.size = Pt(14)
doc.styles['Heading 1'].paragraph_format.space_before = Pt(12)
doc.styles['Heading 1'].paragraph_format.space_after = Pt(7)

groups = [
('1  Quản lý sản phẩm gạch men', [
'Thêm, sửa, xóa gạch: 30×60, 60×60, 80×80, gạch thẻ, chống trơn…',
'Mỗi mẫu có 1 ảnh đại diện và 5–10 ảnh chi tiết; bấm ảnh để đổi hoặc xóa.',
'Quản lý theo lô, thùng và m²; tự quy đổi, ví dụ 1 thùng = 1,44 m².',
'Không bán âm kho nếu chưa được chủ duyệt.',
'Báo gạch tồn trên 60 ngày để chủ động xả kho.']),
('2  Bán hàng và báo giá', [
'Tạo đơn nhanh bằng quét mã hoặc chọn gạch.',
'Tự tính diện tích m², số thùng và tiền phần lẻ.',
'Xuất báo giá PDF có logo cửa hàng và ảnh gạch để gửi Zalo cho khách.',
'Theo dõi công nợ khách lẻ và công trình; ghi nhận từng đợt thanh toán.',
'Giữ đơn, nhận cọc 30% để giữ gạch cho khách.']),
('3  Vận chuyển', [
'Tạo chuyến giao hàng; chọn tài xế, xe và tiền ship.',
'Tính tiền ship theo km hoặc theo chuyến.',
'Theo dõi chuyến đang giao.',
'Chỉ chủ được bấm “Đã xong”; nhân viên không tự hoàn tất chuyến.']),
('4  Kho và nhập hàng', [
'Nhập hàng từ nhà cung cấp: Prime, Đồng Tâm, Viglacera…',
'Ghi nhận số lượng và giá nhập theo từng lô.',
'Kiểm kê: chụp ảnh kho, so sánh tồn thực tế với tồn trên app.',
'Xem lịch sử giá nhập để biết giá vốn và tránh bán lỗ.']),
('5  Thông báo nội bộ', [
'Đơn mới chỉ gửi vào nhóm Messenger cửa hàng; không tự nhắn cho khách.',
'Nhóm “Đơn mới”: mọi người trong nhóm đều đọc được.',
'Nhóm “Chỉ chủ đọc”: gửi yêu cầu duyệt đơn giá trị lớn.',
'Chỉ gửi thông báo, không đọc nội dung hội thoại nhóm.',
'Tự tổng kết mỗi tối: số m² đã bán và tiền đã thu trong ngày.']),
('6  Báo cáo cho chủ', [
'Xem doanh thu theo ngày, tuần và tháng.',
'Xem lãi hoặc lỗ theo từng loại gạch.',
'Top 10 mẫu gạch bán chạy.',
'Top 10 khách còn nợ nhiều nhất.'])]

for i,(heading,items) in enumerate(groups):
    if i % 2 == 0:
        if i: doc.add_page_break()
        if i == 0:
            doc.add_paragraph('TÍNH NĂNG APP VLXD', 'Title')
            p=doc.add_paragraph('Cửa hàng Gò Dầu • Tây Ninh')
            p.runs[0].bold=True
            doc.add_paragraph('Danh sách tính năng để rà soát và bổ sung trước khi triển khai.')
        else:
            p=doc.add_paragraph('TÍNH NĂNG APP VLXD')
            p.runs[0].bold=True
    doc.add_heading(heading, 1)
    for item in items:
        p=doc.add_paragraph(item, 'List Bullet')
        p.paragraph_format.keep_together=True
    p=doc.add_paragraph('Bổ sung tính năng hoặc ghi chú')
    p.runs[0].italic=True
    p.paragraph_format.space_before=Pt(5)
    for _ in range(3):
        p=doc.add_paragraph('........................................................................................................')
        p.paragraph_format.space_after=Pt(6)
        p.paragraph_format.line_spacing=1.15

doc.core_properties.title='Tính năng app VLXD cửa hàng Gò Dầu Tây Ninh'
doc.core_properties.subject='Danh sách tính năng và khoảng trống bổ sung'
doc.save(out)
print(out)
