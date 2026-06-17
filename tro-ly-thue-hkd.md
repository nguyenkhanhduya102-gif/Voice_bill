# Kế hoạch: "Trợ lý ảo Thuế HKD" (Voice Tax Assistant)

> Loại: Tính năng mới · Nền tảng dữ liệu: doanh thu từ bill đã có sẵn trong app
> Ngày lập: 2026-06-10 · **Chỉ kế hoạch — không viết code trong tài liệu này**
> ⚠️ Tuyên bố: Mọi con số/mẫu biểu dưới đây dựa trên bản đặc tả luật do người dùng cung cấp.Mọi hành vi chỉnh sửa đều phải thông qua ý kiến người giám sát dự án này.
> Trước khi phát hành **phải đối chiếu kế toán/cơ quan thuế**. App chỉ **ước tính tham khảo**, **không nộp thay**.

---
## 0 · Hai thông số nền đã chốt
- **Ngưỡng xét theo NĂM DƯƠNG LỊCH** (01/01–31/12), reset mỗi năm — KHÔNG dùng cửa sổ 12 tháng trượt.
- **Tạp hóa thuộc nhóm "Phân phối, cung cấp hàng hóa"** → GTGT **1%**, TNCN tạm tính **0,5%** (mức 1–3 tỷ).
### Bảng tỷ lệ ngành nghề (lưu dạng cấu hình)
| Nhóm ngành | GTGT | TNCN tạm (1–3 tỷ) |
|---|---|---|
| **Phân phối, cung cấp hàng hóa** (← tạp hóa) | **1%** | **0,5%** |
| SX, vận tải, dịch vụ gắn hàng hóa, XD có bao thầu NVL | 3% | 1,5% |
| Dịch vụ, XD không bao thầu NVL | 5% | 2% |
| Kinh doanh khác | 2% | 1% |
| Cho thuê tài sản/BĐS; nội dung số | 5% | 5% |
| Đại lý bảo hiểm, xổ số, ĐLĐC | — | 5% |

---

## 1 · Insight cốt lõi: MÁY TRẠNG THÁI theo doanh thu năm

App sở hữu doanh thu → tự xác định bậc và áp đúng nghĩa vụ. Đây là lợi thế không giải pháp thủ công nào có.

| Bậc | HĐĐT | TNCN | Sổ sách | Tờ khai · hạn |
|---|---|---|---|---|
| **≤ 1 tỷ** | Không bắt buộc | **Miễn** GTGT & TNCN | **1 sổ S1a** | 01/TKN-CNKD · **31/01 năm sau** |
| **>1–3 tỷ · PP1 (trên doanh thu)** | Bắt buộc | (DT−1 tỷ) × 0,5%; GTGT = 1% × DT | 1 sổ S2a-HKD | 01/CNKD · cuối tháng đầu quý sau |
| **>1–3 tỷ · PP2 (trên thu nhập)** | Bắt buộc | (DT−chi phí) × **15%** | 4 sổ S2b–e | 01/CNKD quý + 02/QTT **31/03** |
| **>3–50 tỷ** | Bắt buộc | (DT−chi phí) × **17%** | 4 sổ | quý + quyết toán 31/03 |
| **>50 tỷ** | Bắt buộc | (DT−chi phí) × **20%** | 4 sổ | **tháng** + quyết toán |

> Quy tắc chuyển bậc: vượt 1 tỷ trong năm ⇒ **từ quý sau** dùng HĐĐT + chuyển diện kê khai (1–3 tỷ).
> Mã hóa toàn bộ bảng này thành **config-driven** (1 nguồn dữ liệu) để năm sau luật đổi chỉ sửa cấu hình.

---

## 2 · Phân tầng giai đoạn

### Giai đoạn 1 — "Sổ doanh thu & cảnh báo ngưỡng" (MVP, phục vụ ~80% hộ ≤1 tỷ) ✅ ĐÃ LÀM
> **Điều hướng (chốt): hướng A** — vào qua Hồ sơ → "Thuế & Báo cáo". Tối ưu giao diện tổng thể để sau khi xong hết chức năng.
> Đã code: [tax_rules.dart](lib/services/tax_rules.dart) (config + logic thuần, 13 test), [tax_service.dart](lib/services/tax_service.dart) (gom doanh thu năm theo `createdAt` + xuất S1a CSV), [tax_page.dart](lib/pages/tax_page.dart) (đồng hồ doanh thu, badge bậc, cảnh báo ngưỡng, ước tính thuế, nghĩa vụ + hạn, nút xuất S1a, disclaimer), lối vào trong [profile_page.dart](lib/pages/profile_page.dart). Đã chốt D1 (80%/100%) · D2 (`createdAt` của bill) · D4 (CSV trước).
Phục vụ đúng nhóm đông nhất, dùng lại data bill sẵn có, rủi ro pháp lý thấp nhất (bậc miễn thuế).
1. **Đồng hồ doanh thu năm dương lịch** — cộng dồn bill theo năm hiện tại; biểu đồ tháng/quý.
2. **Cảnh báo ngưỡng** khi chạm mốc 80%/100% của 1 tỷ (và 3 tỷ, 50 tỷ cho tương lai):
   > "Doanh thu năm nay đã đạt 950 triệu. Khi vượt 1 tỷ, từ quý sau bạn **bắt buộc dùng HĐĐT** + chuyển diện kê khai."
3. **Sổ doanh thu S1a** tự sinh từ bill + **xuất Excel/CSV**.
4. **Nhắc hạn** 01/TKN-CNKD (31/01 năm sau; hộ mới: nửa đầu trước 31/07, nửa sau trước 31/01) + nhắc **đăng ký tài khoản ngân hàng/ví trên eTax Mobile**.
5. **Disclaimer** rõ ràng ở mọi màn thuế.

### Giai đoạn 2 — nhóm 1–3 tỷ (PP1)
- UI chọn PP1/PP2 + giải thích hệ quả (1 sổ vs 4 sổ).
- PP1: tính GTGT = 1%×DT, TNCN = (DT−1 tỷ)×0,5%; sinh **01/CNKD** theo quý; sổ **S2a-HKD**; xuất Excel/PDF để tự nhập eTax.
### Giai đoạn 3 — nhóm có chi phí (PP2 / >3 tỷ)
- **Nhập chi phí mua vào bằng giọng nói** (tái dùng luồng xác nhận Phase 3 của nhập hàng).
- **4 sổ S2b–e** + quyết toán 02/CNKD-TNCN-QTT (31/03).
- **Cảnh báo "tiền mặt ≥5tr không được trừ"** (chi phí ≥5tr phải chuyển khoản mới được trừ).
### Giai đoạn 4 (chỉ khi có nhu cầu thật)
- Tích hợp **HĐĐT** (nhà cung cấp hóa đơn điện tử), đọc XML đầu vào. Đắt & khó nhất → để cuối.
## 3 · Mô hình dữ liệu (phác thảo)
- `TaxProfile` (per user): `nganhNghe` (mặc định "phan_phoi_hang_hoa"), `phuongPhap` (PP1/PP2, chỉ dùng khi 1–3 tỷ), `hoMoiKinhDoanh` (bool, ảnh hưởng hạn nộp), `namApDung`.
- `taxRulesConfig` (hằng/Remote Config): bảng bậc + bảng tỷ lệ ngành ở mục 0–1. **Versioned theo năm.**
- Doanh thu: **tính từ collection bill sẵn có**, group theo `năm`. Không tạo nguồn dữ liệu trùng.
- Suy luận bậc: hàm thuần `xacDinhBac(doanhThuNam) -> Bac` + `tinhThue(Bac, profile, doanhThu, chiPhi?)` → **dễ viết unit test** (giống cách đã làm với `vietnamese_number` / `aggregateStockItems`).
## 4 · Quyết định cần chốt khi triển khai
- D1. Mốc cảnh báo: 80% & 100% ngưỡng? Có cảnh báo tốc độ ("đà này quý 4 sẽ vượt") không? → đề xuất: 80%/100% trước, dự báo để sau.
- D2. Doanh thu năm tính theo ngày bill (ngày lập hóa đơn) — xác nhận trường ngày đang lưu trên bill.
- D3. Hộ mới kinh doanh năm đầu: cần cờ để áp hạn nộp nửa năm (31/07 / 31/01).
- D4. Xuất sổ: Excel (.xlsx) hay CSV trước? → đề xuất CSV trước (nhẹ), Excel sau.

---

## 5 · Ngoài phạm vi plan này
- Nộp tờ khai trực tiếp lên cơ quan thuế (app không nộp thay).
- Tích hợp HĐĐT thực tế (Giai đoạn 4).
- Tư vấn pháp lý — app chỉ ước tính, kèm disclaimer.
