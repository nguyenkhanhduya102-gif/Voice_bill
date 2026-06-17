import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:voice_bill/utils/price_parser.dart';

class BillItem {
  final String name;
  final int quantity;

  /// Đơn giá, đơn vị đồng (int). Đây là nguồn sự thật duy nhất cho tiền;
  /// việc định dạng "15.000đ" chỉ làm ở tầng hiển thị.
  final int unitPrice;

  /// Id sản phẩm trong kho nếu khớp được — dùng để trừ kho chính xác,
  /// thay vì khớp theo tên (dễ sai). Null nếu là mặt hàng tự do.
  final String? productId;

  /// Đơn vị tính (kg, lon, gói…) — để hóa đơn đủ thông tin. '' nếu không rõ.
  final String unit;

  const BillItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.productId,
    this.unit = '',
  });

  int get subtotal => unitPrice * quantity;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'subtotal': subtotal,
      if (productId != null) 'productId': productId,
      if (unit.isNotEmpty) 'unit': unit,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> data) {
    // Ưu tiên unitPrice (int). Đọc dữ liệu cũ: rơi về 'price' dạng chuỗi.
    final int unitPrice = (data['unitPrice'] as num?)?.toInt() ??
        parsePriceToInt((data['price'] ?? '').toString());
    return BillItem(
      name: (data['name'] ?? '').toString(),
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: unitPrice,
      productId: data['productId']?.toString(),
      unit: (data['unit'] ?? '').toString(),
    );
  }
}

/// Nhãn hiển thị trạng thái/phương thức thanh toán của hóa đơn.
String paymentLabel(String status, String paymentMethod) {
  if (status == 'debt') return 'Ghi nợ';
  switch (paymentMethod) {
    case 'cash':
      return 'Tiền mặt';
    case 'transfer':
      return 'Chuyển khoản';
    default:
      return 'Đã thanh toán';
  }
}

class BillRecord {
  final String id;
  final List<BillItem> items;
  final int total;

  /// 'paid' (đã thu) | 'debt' (ghi nợ).
  final String status;

  /// 'cash' (tiền mặt) | 'transfer' (chuyển khoản) | '' (ghi nợ chưa trả).
  final String paymentMethod;
  final DateTime? createdAt;
  final int invoiceNumber;

  /// Snapshot thông tin người bán tại thời điểm xuất (để hóa đơn cũ luôn đúng
  /// dù hồ sơ đổi sau). Rỗng với hóa đơn cũ.
  final String sellerName;
  final String sellerTaxCode;
  final String sellerAddress;
  final String sellerPhone;

  const BillRecord({
    required this.id,
    required this.items,
    required this.total,
    required this.status,
    this.paymentMethod = '',
    required this.createdAt,
    this.invoiceNumber = 0,
    this.sellerName = '',
    this.sellerTaxCode = '',
    this.sellerAddress = '',
    this.sellerPhone = '',
  });

  factory BillRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawItems = (data['items'] as List<dynamic>? ?? [])
        .map((e) => BillItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final Timestamp? timestamp = data['createdAt'] as Timestamp?;
    return BillRecord(
      id: doc.id,
      items: rawItems,
      total: (data['total'] as num?)?.toInt() ?? 0,
      status: (data['status'] ?? 'paid').toString(),
      paymentMethod: (data['paymentMethod'] ?? '').toString(),
      createdAt: timestamp?.toDate(),
      invoiceNumber: (data['invoiceNumber'] as num?)?.toInt() ?? 0,
      sellerName: (data['sellerName'] ?? '').toString(),
      sellerTaxCode: (data['sellerTaxCode'] ?? '').toString(),
      sellerAddress: (data['sellerAddress'] ?? '').toString(),
      sellerPhone: (data['sellerPhone'] ?? '').toString(),
    );
  }
}
