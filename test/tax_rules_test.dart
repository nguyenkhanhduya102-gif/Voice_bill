import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bill/services/tax_rules.dart';

void main() {
  group('xacDinhBac - biên ngưỡng', () {
    test('0 đồng -> miễn thuế', () {
      expect(xacDinhBac(0), TaxTier.mienThue);
    });
    test('đúng 1 tỷ -> vẫn miễn (≤ 1 tỷ)', () {
      expect(xacDinhBac(1000000000), TaxTier.mienThue);
    });
    test('1 tỷ + 1 đồng -> bậc 1–3 tỷ', () {
      expect(xacDinhBac(1000000001), TaxTier.tu1Den3Ty);
    });
    test('đúng 3 tỷ -> vẫn 1–3 tỷ', () {
      expect(xacDinhBac(3000000000), TaxTier.tu1Den3Ty);
    });
    test('3 tỷ + 1 -> 3–50 tỷ', () {
      expect(xacDinhBac(3000000001), TaxTier.tu3Den50Ty);
    });
    test('60 tỷ -> trên 50 tỷ', () {
      expect(xacDinhBac(60000000000), TaxTier.tren50Ty);
    });
  });

  group('uocTinhThue', () {
    test('miễn thuế -> 0', () {
      final e = uocTinhThue(bac: TaxTier.mienThue, doanhThuNam: 800000000);
      expect(e.gtgt, 0);
      expect(e.tncn, 0);
      expect(e.tinhDuoc, true);
    });

    test('1–3 tỷ tạp hóa: GTGT 1% DT, TNCN 0,5% phần vượt 1 tỷ', () {
      // DT 2 tỷ: GTGT = 1% * 2 tỷ = 20tr; TNCN = 0,5% * (2 tỷ - 1 tỷ) = 5tr.
      final e = uocTinhThue(
        bac: TaxTier.tu1Den3Ty,
        doanhThuNam: 2000000000,
        nganh: phanPhoiHangHoa,
      );
      expect(e.gtgt, 20000000);
      expect(e.tncn, 5000000);
      expect(e.tong, 25000000);
    });

    test('bậc > 3 tỷ -> chưa tính được (cần chi phí)', () {
      final e = uocTinhThue(bac: TaxTier.tu3Den50Ty, doanhThuNam: 4000000000);
      expect(e.tinhDuoc, false);
    });
  });

  group('trangThaiNguong', () {
    test('dưới 80% -> an toàn', () {
      expect(trangThaiNguong(700000000), NguongStatus.antoan);
    });
    test('800tr (=80%) -> sắp vượt', () {
      expect(trangThaiNguong(800000000), NguongStatus.sapVuot);
    });
    test('trên 1 tỷ -> đã vượt', () {
      expect(trangThaiNguong(1200000000), NguongStatus.daVuot);
    });
  });

  group('hanNopThongBaoNam', () {
    test('năm 2026 -> 31/01/2027', () {
      final h = hanNopThongBaoNam(2026);
      expect(h, DateTime(2027, 1, 31));
    });
  });
}
