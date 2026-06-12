# Kế hoạch: Cải thiện "Nhập hàng bằng giọng nói"

> Loại: Cải thiện tính năng đang có · Chế độ: Online (Gemini) + fallback offline (parser local)
> Trọng tâm: (1) Parse chính xác hơn · (2) Chống trùng sản phẩm · (3) Màn xác nhận + số lượng
> Ngày lập: 2026-06-09 · **Chỉ kế hoạch — không viết code trong tài liệu này**

---

## Phase -1 · Bối cảnh hiện trạng (đã đọc code)

| Thành phần | Hiện tại | Hạn chế cần cải thiện |
|---|---|---|
| [stock_entry_page.dart](lib/pages/stock_entry_page.dart) | `_handleVoiceText`/`_openTextEntry` parse xong **gọi `addProduct` ngay trong vòng lặp** | Không có bước duyệt lại; không nhập được số lượng tồn (mặc định `stock=1`) |
| [local_parser_service.dart](lib/services/local_parser_service.dart) | `parseStockItems` xử lý định dạng pipe/phẩy/cách trắng; `_isUnit` danh sách đơn vị ngắn | Không hiểu số viết bằng chữ ("ba"), không bỏ từ thừa ("nhập/thêm/với/và"), giá "k/nghìn/triệu" chưa chuẩn hóa, thiếu nhiều đơn vị (lon, gói, vỉ, lốc, bao…) |
| [functions/index.js](functions/index.js) `parseStock` | Prompt Gemini cơ bản, ví dụ ít | Chưa cho số bằng chữ, đơn vị hẹp, chưa chuẩn hóa giá "k/nghìn", **không trả `quantity`** |
| [product_service.dart](lib/services/product_service.dart) | `addProduct` luôn **tạo doc mới**; có `fetchProducts` | Nhập trùng tên ⇒ tạo trùng sản phẩm; chưa có upsert/merge; chưa bỏ dấu khi so khớp |
| Schema item nhập hàng | `{name, unit, price}` | Thiếu `quantity` (số lượng tồn nhập vào) |

**Quyết định cần chốt khi triển khai (ghi sẵn để hỏi lúc làm):**
- D1. Khi trùng sản phẩm: **cộng dồn tồn kho** và **cập nhật giá mới nhất** (đề xuất mặc định). Có cần giữ lịch sử giá không? → tạm: không.
- D2. So khớp trùng: chuẩn hóa = bỏ dấu tiếng Việt + lowercase + gộp khoảng trắng. Có khớp gần đúng (typo) không? → tạm: chỉ khớp chính xác sau chuẩn hóa (khớp mờ để sau).
- D3. "vỉ/lốc/thùng" có quy đổi ra đơn vị lẻ không? → tạm: KHÔNG quy đổi, lưu đúng đơn vị người nói.

---

## Phase 0 · Socratic Gate (đã hỏi & chốt)
- Mục tiêu: cải thiện tính năng đang có ✅
- Ưu tiên: parse chính xác + chống trùng + xác nhận/số lượng ✅
- Chế độ: cả hai, có fallback ✅
- Ngoài phạm vi plan này: sửa STT web (đang debug riêng), công nợ, sửa/xóa hóa đơn.

---

## Phase 1 · Parse chính xác hơn (offline + online cùng schema)

**Mục tiêu:** câu nói tự nhiên → `{name, unit, price, quantity}` đúng hơn, đồng nhất giữa Gemini và parser local.

- T1.1 — Chuẩn schema nhập hàng: bổ sung **`quantity`** (số lượng nhập) vào cả local parser và Gemini, mặc định 1.
- T1.2 — Parser local: thêm bộ **số viết bằng chữ** (không, một…mười, mười lăm, hai mươi, một trăm, vài chục…) → số.
- T1.3 — Parser local: **bỏ từ thừa** đầu/giữa câu ("nhập", "thêm", "cho", "với", "và", "rồi", "à").
- T1.4 — Parser local: chuẩn hóa **giá** "15k / 15 nghìn / 15 ngàn / 1 triệu rưỡi / 150 nghìn" → int đồng.
- T1.5 — Parser local: mở rộng `_isUnit` (lon, gói, vỉ, lốc, bao, thùng, két, cây, ổ, quả, trái, cuộn, đôi, set…) + nhận dạng đơn vị đứng trước/sau số lượng.
- T1.6 — Parser local: tách **nhiều mặt hàng** theo "và"/","/";"/xuống dòng.
- T1.7 — Gemini prompt `parseStock`: thêm rule + ví dụ cho số bằng chữ, đơn vị rộng, giá "k/nghìn/triệu", trả thêm `quantity`; nhúng được danh mục kho (để khớp tên) — đối xứng với `parseSale`.
- T1.8 — Bộ test mẫu câu (≥15 câu thật của tạp hóa) để đối chiếu output 2 parser.

**File đụng tới:** `local_parser_service.dart`, `functions/index.js`, `voice_controller.dart` (truyền danh mục vào `parseStockTextAsync`).

---

## Phase 2 · Chống trùng sản phẩm (merge thay vì tạo mới)

**Mục tiêu:** nhập tên đã có trong kho ⇒ cập nhật, không sinh bản trùng.

- T2.1 — Helper **chuẩn hóa tên bỏ dấu tiếng Việt** (à/á/ả…→a, đ→d) + lowercase + gộp khoảng trắng. Dùng chung cho cả bán & nhập.
- T2.2 — `ProductService`: thêm **`upsertProduct`** (hoặc `addOrMergeProduct`) — tra `fetchProducts`, nếu khớp tên chuẩn hóa thì `update` (cộng `stock`, cập nhật `priceValue`/`unit` mới), không thì `add`.
- T2.3 — Đánh dấu trạng thái mỗi item ở tầng UI: **"Mới"** vs **"Đã có — sẽ cộng dồn"** (phục vụ Phase 3).
- T2.4 — Đảm bảo nhất quán với khóa khớp dùng ở trừ kho bán hàng ([decrementStockForSaleItems](lib/services/product_service.dart)) — cùng một hàm chuẩn hóa (giảm lệch dữ liệu).

**File đụng tới:** `product_service.dart`, tiện ích chuẩn hóa mới (vd `lib/utils/name_normalizer.dart`).

---

## Phase 3 · Màn xác nhận + nhập số lượng

**Mục tiêu:** không lưu ngay; cho người bán soát lại & nhập số lượng tồn.

- T3.1 — Đổi `_handleVoiceText`/`_openTextEntry`: parse xong **gom vào danh sách tạm** (state), KHÔNG `addProduct` ngay.
- T3.2 — **Bottom sheet xác nhận nhập kho**: liệt kê từng món (tên, đơn vị, giá, **số lượng** sửa được), badge "Mới/Đã có", cảnh báo món **giá 0**.
- T3.3 — Nút "Lưu vào kho" gọi `upsertProduct` cho từng món (Phase 2); báo số món mới / số món cộng dồn.
- T3.4 — Tile danh sách nhập hiển thị số lượng + đơn vị; dark-mode dùng `context.*` (đồng bộ phần đã làm).
- T3.5 — Sửa item trong sheet: dùng lại pattern dialog đã có, **dispose controller** đúng cách.

**File đụng tới:** `stock_entry_page.dart` (+ widget sheet/tile, có thể tách riêng).

---

## Phase 4 · Online/Offline fallback nhất quán

- T4.1 — `parseStockTextAsync`: online → Gemini (`functions parseStock`), offline/timeout → parser local; **cùng schema** `{name, unit, price, quantity}`.
- T4.2 — Truyền **danh mục sản phẩm** vào prompt Gemini để khớp tên (giảm trùng ngay từ AI).
- T4.3 — Khi chưa deploy Blaze: chạy hoàn toàn bằng parser local — không lỗi, không chặn người dùng.

---

## Phân công (theo framework .agents)

| Phase | Phụ trách đề xuất |
|---|---|
| P1 parse | coder/implementer + bộ test (debugger để đối chiếu output) |
| P2 merge | coder/implementer |
| P3 UI xác nhận | coder/implementer (frontend) |
| P4 fallback | coder/implementer |
| Toàn bộ | review bằng `/code-review` trước khi đóng |

---

## Checklist nghiệm thu (Phase X)

- [ ] Nói "ba thùng sting một trăm năm mươi nghìn" → `{Sting, thùng, 150000, qty 3}` (online & offline đều đúng).
- [ ] Nói câu có từ thừa ("cho nhập thêm 2 lốc cocacola 90k") → bóc đúng, bỏ từ thừa.
- [ ] Nhập tên đã có trong kho → **cộng dồn tồn**, KHÔNG tạo sản phẩm trùng.
- [ ] Tên khác dấu/hoa-thường ("Cocacola" vs "coca cola") → coi là cùng sản phẩm.
- [ ] Màn xác nhận hiện trước khi lưu; sửa được số lượng/giá; cảnh báo giá 0.
- [ ] Badge "Mới / Đã có — cộng dồn" hiển thị đúng.
- [ ] Chưa deploy Blaze vẫn nhập được bằng parser local.
- [ ] `dart analyze` sạch (không thêm error/warning).
- [ ] Dark mode đồng bộ ở màn/sheet mới.
- [ ] Đã gỡ log `[STT]`/debug tạm (nếu có).

---

## Rủi ro & lưu ý
- **Bỏ dấu tiếng Việt** phải xử lý cả `đ/Đ` và tổ hợp dấu — viết test riêng.
- Merge sản phẩm là thao tác ghi đè dữ liệu → cần màn xác nhận (Phase 3) làm "chốt chặn" trước khi ghi.
- Quy đổi đơn vị (thùng→lon) cố ý **không** làm ở plan này (D3) để tránh sai số lượng tồn.
- `firestore.rules` `validProduct` đã cho `priceValue` int + `quantity` không bắt buộc — kiểm tra lại nếu thêm field mới vào doc sản phẩm.

---

## Bước tiếp theo
- Xem lại plan này.
- Khi đồng ý, ra lệnh để bắt đầu code (theo framework của bạn là `/create`, hoặc nói "làm Phase 1" để tôi triển khai từng phase).
- Hoặc chỉnh sửa plan trực tiếp trong file.
