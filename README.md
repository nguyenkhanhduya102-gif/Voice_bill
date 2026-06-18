# VoiceBill — Hóa Đơn Giọng Nói

Tạo hóa đơn và nhập hàng cho tạp hóa **bằng giọng nói**. Không cần gõ phím, không cần thành thạo công nghệ.

## Tính năng chính

| Tính năng | Mô tả |
|---|---|
| **Bán hàng bằng giọng nói** | Đọc tên mặt hàng, số lượng, giá → app tự tạo hóa đơn. Hỗ trợ tiền mặt / chuyển khoản / ghi nợ |
| **Nhập hàng bằng giọng nói** | Đọc hàng nhập về → app tự thêm vào kho. Soát lại trước khi lưu, chống trùng sản phẩm |
| **Quản lý kho** | Danh sách mặt hàng, tìm kiếm, lọc hàng sắp hết, chỉnh sửa/xóa |
| **Lịch sử hóa đơn** | Xem lại toàn bộ hóa đơn, lọc theo trạng thái (đã thanh toán / ghi nợ), xuất CSV |
| **Thuế & Báo cáo** | Đồng hồ doanh thu năm, cảnh báo ngưỡng 1 tỷ, ước tính thuế HKD, xuất Sổ S1a |
| **QR chuyển khoản** | Tự sinh VietQR cho hóa đơn chuyển khoản, hỗ trợ 10 ngân hàng phổ biến |
| **In & chia sẻ PDF** | Xuất hóa đơn ra file PDF, in hoặc chia sẻ qua Zalo/Messenger |
| **Chế độ tối / Chữ lớn** | Hỗ trợ dark mode và phóng chữ 1.3x cho người lớn tuổi, mắt kém |
| **Online + Offline** | Dùng AI (Gemini) khi có mạng, tự chuyển sang parser local khi mất mạng |

## Công nghệ

- **Flutter** (Dart 3.12+) — Android, iOS, Web, Windows, macOS, Linux
- **Firebase** — Auth, Firestore, Functions, Storage
- **Gemini AI** (qua Cloud Functions) — phân tích câu nói tự nhiên tiếng Việt
- **speech_to_text** — nhận dạng giọng nói trên thiết bị

## Cài đặt & chạy

### Yêu cầu

- Flutter SDK ^3.12.0
- Firebase project (Blaze plan để dùng Cloud Functions)

### Các bước

```bash
# 1. Clone
git clone <repo-url>
cd voice_bill

# 2. Tạo file .env
cp .env.example assets/.env
# Sửa assets/.env với thông tin Firebase của bạn

# 3. Cài dependencies
flutter pub get

# 4. Deploy Cloud Functions
cd functions
npm install
firebase deploy --only functions
cd ..

# 5. Chạy app
flutter run
```

## Cấu trúc dự án

```
lib/
├── main.dart              # Entry point, theme, Firebase init
├── firebase_options.dart  # Cấu hình Firebase
├── models/                # Data models
│   ├── bill_models.dart   # BillItem, BillRecord
│   └── product_item.dart  # ProductItem
├── pages/                 # Các màn hình
│   ├── auth_gate.dart     # Điều hướng đăng nhập
│   ├── auth_page.dart     # Đăng nhập / đăng ký
│   ├── onboarding_page.dart    # Hướng dẫn lần đầu
│   ├── main_tabs_page.dart     # Tab chính (Home, Kho, Lịch sử, Hồ sơ)
│   ├── home_page.dart          # Trang chủ: doanh thu hôm nay + bán hàng
│   ├── create_bill_page.dart   # Tạo hóa đơn bằng giọng nói
│   ├── qr_payment_page.dart    # Màn thanh toán QR sau khi tạo bill
│   ├── bill_detail_page.dart   # Chi tiết hóa đơn
│   ├── stock_entry_page.dart   # Nhập hàng bằng giọng nói
│   ├── warehouse_page.dart     # Quản lý kho
│   ├── history_page.dart       # Lịch sử hóa đơn
│   ├── tax_page.dart           # Thuế & Báo cáo
│   └── profile_page.dart       # Hồ sơ & Cài đặt
├── services/              # Tầng logic
│   ├── auth_service.dart        # Xác thực Firebase
│   ├── bill_service.dart        # CRUD hóa đơn
│   ├── product_service.dart     # CRUD sản phẩm + upsert
│   ├── tax_service.dart         # Tổng hợp doanh thu, xuất S1a
│   ├── tax_rules.dart           # Cấu hình luật thuế HKD
│   ├── voice_controller.dart    # Điều khiển giọng nói (online/offline)
│   ├── gemini_service.dart      # Gọi Gemini qua Cloud Functions
│   ├── local_parser_service.dart # Parser tiếng Việt offline
│   ├── export_service.dart      # Xuất CSV
│   ├── invoice_pdf_service.dart # Tạo PDF hóa đơn
│   └── profile_service.dart     # CRUD hồ sơ người dùng
├── widgets/               # Widget dùng chung
│   ├── empty_state.dart         # Màn "chưa có dữ liệu"
│   ├── voice_recorder_overlay.dart  # Overlay ghi âm
│   ├── bill_item_tile.dart      # Dòng mặt hàng trong bill
│   ├── skeletons.dart           # Loading skeleton
│   └── wave_pulse.dart          # Hiệu ứng sóng nút mic
└── utils/                 # Tiện ích
    ├── app_theme.dart           # Theme, màu sắc, text scale
    ├── currency_formatter.dart  # Format tiền VND
    ├── date_formatter.dart      # Format ngày tháng
    ├── price_parser.dart        # Parse chuỗi giá → int
    ├── short_id.dart            # Sinh ID ngắn
    ├── vietnamese_number.dart   # Số viết bằng chữ → int
    └── coach_marks.dart         # Hướng dẫn overlay
```

## Firestore schema

### `users/{uid}/bills/{billId}`
```
{
  items: [{ name, quantity, unitPrice, unit, productId, subtotal }],
  total: int,
  status: 'paid' | 'debt',
  paymentMethod: 'cash' | 'transfer' | '',
  invoiceNumber: int,
  createdAt: timestamp,
  sellerName, sellerTaxCode, sellerAddress, sellerPhone
}
```

### `users/{uid}/products/{productId}`
```
{
  name, unit, priceValue: int, stock: int,
  createdAt: timestamp, updatedAt: timestamp
}
```

### `users/{uid}/profile/{profile}`
```
{
  displayName, storeName, phone, address, taxCode,
  photoUrl, bankName, bankShortName, bankBin,
  accountNumber, accountName, qrImageUrl, qrMode
}
```

## Kế hoạch phát triển

Đọc chi tiết trong:
- [`nhap-hang-giong-noi.md`](nhap-hang-giong-noi.md) — Cải thiện nhập hàng bằng giọng nói (Phase 1–4)
- [`tro-ly-thue-hkd.md`](tro-ly-thue-hkd.md) — Trợ lý ảo Thuế HKD (Giai đoạn 1–4)

## Lưu ý

- App chỉ **ước tính thuế tham khảo**, không nộp thay. Người dùng tự đối chiếu với cơ quan thuế.
- Cần Firebase Blaze plan để dùng Cloud Functions (Gemini AI).
- Chưa deploy Blaze vẫn dùng được parser local (offline).
