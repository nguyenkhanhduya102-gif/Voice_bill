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

  const BillItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.productId,
  });

  int get subtotal => unitPrice * quantity;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'subtotal': subtotal,
      if (productId != null) 'productId': productId,
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
    );
  }
}

class BillRecord {
  final String id;
  final List<BillItem> items;
  final int total;
  final String status;
  final DateTime? createdAt;
  final int invoiceNumber;

  const BillRecord({
    required this.id,
    required this.items,
    required this.total,
    required this.status,
    required this.createdAt,
    this.invoiceNumber = 0,
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
      createdAt: timestamp?.toDate(),
      invoiceNumber: (data['invoiceNumber'] as num?)?.toInt() ?? 0,
    );
  }
}
