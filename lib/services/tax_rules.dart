/// Quy tắc thuế Hộ kinh doanh (HKD) — TÁCH RIÊNG dạng cấu hình để khi luật
/// thay đổi theo năm chỉ cần sửa file này, không rải khắp code.
///
/// ⚠️ Dựa trên bản đặc tả luật do người dùng cung cấp (2026). Chỉ ƯỚC TÍNH
/// tham khảo, KHÔNG thay tư vấn thuế và KHÔNG nộp thay. Ngưỡng xét theo
/// NĂM DƯƠNG LỊCH (01/01–31/12), reset mỗi năm.
library;

/// Các mốc doanh thu năm (đơn vị: đồng).
class TaxThresholds {
  /// ≤ 1 tỷ: miễn GTGT & TNCN.
  static const int mienThue = 1000000000;

  /// > 1–3 tỷ: bắt buộc HĐĐT, kê khai.
  static const int baTy = 3000000000;

  /// > 3–50 tỷ: thuế suất TNCN 17% (trên thu nhập).
  static const int namMuoiTy = 50000000000;
}

/// Bậc thuế suy ra từ doanh thu năm.
enum TaxTier {
  /// ≤ 1 tỷ — miễn thuế, chỉ nộp Mẫu 01/TKN-CNKD + Sổ S1a.
  mienThue,

  /// > 1–3 tỷ — HĐĐT bắt buộc; PP1 (trên doanh thu) hoặc PP2 (trên thu nhập).
  tu1Den3Ty,

  /// > 3–50 tỷ — kê khai, TNCN 17% trên thu nhập.
  tu3Den50Ty,

  /// > 50 tỷ — kê khai theo tháng, TNCN 20% trên thu nhập.
  tren50Ty,
}

/// Tỷ lệ % tính thuế theo nhóm ngành nghề.
class IndustryRate {
  final String id;
  final String label;

  /// Tỷ lệ % GTGT trên doanh thu (vd 1.0 = 1%).
  final double gtgtPercent;

  /// Thuế suất % TNCN tạm tính ở bậc 1–3 tỷ theo PP1 (vd 0.5 = 0,5%).
  final double tncnPercent;

  const IndustryRate({
    required this.id,
    required this.label,
    required this.gtgtPercent,
    required this.tncnPercent,
  });
}

/// Bảng tỷ lệ ngành nghề (đặc tả 2026). Tạp hóa = "Phân phối, cung cấp hàng hóa".
const IndustryRate phanPhoiHangHoa = IndustryRate(
  id: 'phan_phoi_hang_hoa',
  label: 'Phân phối, cung cấp hàng hóa',
  gtgtPercent: 1.0,
  tncnPercent: 0.5,
);

const List<IndustryRate> bangTyLeNganhNghe = [
  phanPhoiHangHoa,
  IndustryRate(
    id: 'san_xuat_van_tai_dichvu_hanghoa',
    label: 'SX, vận tải, dịch vụ gắn hàng hóa, XD có bao thầu NVL',
    gtgtPercent: 3.0,
    tncnPercent: 1.5,
  ),
  IndustryRate(
    id: 'dichvu_xaydung_khong_baothau',
    label: 'Dịch vụ, xây dựng không bao thầu NVL',
    gtgtPercent: 5.0,
    tncnPercent: 2.0,
  ),
  IndustryRate(
    id: 'kinh_doanh_khac',
    label: 'Hoạt động kinh doanh khác',
    gtgtPercent: 2.0,
    tncnPercent: 1.0,
  ),
];

/// Xác định bậc thuế từ doanh thu năm (đồng). Biên ≤ là miễn, > mới lên bậc.
TaxTier xacDinhBac(int doanhThuNam) {
  if (doanhThuNam <= TaxThresholds.mienThue) return TaxTier.mienThue;
  if (doanhThuNam <= TaxThresholds.baTy) return TaxTier.tu1Den3Ty;
  if (doanhThuNam <= TaxThresholds.namMuoiTy) return TaxTier.tu3Den50Ty;
  return TaxTier.tren50Ty;
}

/// Ước tính thuế phải nộp.
class TaxEstimate {
  final int gtgt;
  final int tncn;

  /// false khi cần dữ liệu chi phí mới tính được (bậc > 3 tỷ, tính trên thu nhập).
  final bool tinhDuoc;

  const TaxEstimate({
    required this.gtgt,
    required this.tncn,
    this.tinhDuoc = true,
  });

  int get tong => gtgt + tncn;

  static const TaxEstimate khongTinhDuoc =
      TaxEstimate(gtgt: 0, tncn: 0, tinhDuoc: false);
}

/// Ước tính thuế cho bậc miễn thuế và bậc 1–3 tỷ (PP1 — trên doanh thu).
/// Bậc > 3 tỷ cần chi phí được trừ ⇒ trả [TaxEstimate.khongTinhDuoc].
TaxEstimate uocTinhThue({
  required TaxTier bac,
  required int doanhThuNam,
  IndustryRate nganh = phanPhoiHangHoa,
}) {
  switch (bac) {
    case TaxTier.mienThue:
      return const TaxEstimate(gtgt: 0, tncn: 0);
    case TaxTier.tu1Den3Ty:
      // PP1: GTGT = %ngành × doanh thu; TNCN = (DT − 1 tỷ) × suất TNCN ngành.
      final gtgt = (doanhThuNam * nganh.gtgtPercent / 100).round();
      final base = doanhThuNam - TaxThresholds.mienThue;
      final tncn = base > 0 ? (base * nganh.tncnPercent / 100).round() : 0;
      return TaxEstimate(gtgt: gtgt, tncn: tncn);
    case TaxTier.tu3Den50Ty:
    case TaxTier.tren50Ty:
      return TaxEstimate.khongTinhDuoc;
  }
}

/// Hạn nộp tờ khai/thông báo doanh thu năm (bậc miễn thuế):
/// Mẫu 01/TKN-CNKD — chậm nhất 31/01 năm sau.
DateTime hanNopThongBaoNam(int nam) => DateTime(nam + 1, 1, 31);

/// Mức cảnh báo so với ngưỡng miễn thuế (1 tỷ).
enum NguongStatus { antoan, sapVuot, daVuot }

NguongStatus trangThaiNguong(int doanhThuNam) {
  if (doanhThuNam > TaxThresholds.mienThue) return NguongStatus.daVuot;
  if (doanhThuNam >= (TaxThresholds.mienThue * 0.8).round()) {
    return NguongStatus.sapVuot;
  }
  return NguongStatus.antoan;
}

/// Tỷ lệ doanh thu năm so với ngưỡng 1 tỷ (0.0–1.0+), dùng cho thanh tiến độ.
double tyLeNguong(int doanhThuNam) =>
    doanhThuNam / TaxThresholds.mienThue;
