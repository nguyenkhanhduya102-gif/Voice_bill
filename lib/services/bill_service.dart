import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:voice_bill/models/bill_models.dart';
import 'package:voice_bill/services/product_service.dart';
import 'package:voice_bill/utils/price_parser.dart';

class BillService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<BillRecord>> streamBills() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value([]);

      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('bills')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(BillRecord.fromDoc).toList());
    });
  }

  Future<BillRecord> createBill({
    required List<BillItem> items,
    required int total,
    String status = 'paid',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User not signed in');

    final userRef = _firestore.collection('users').doc(user.uid);
    // Tạo trước ref với id tự sinh để dùng được trong transaction.
    final billRef = userRef.collection('bills').doc();

    // Cấp số hóa đơn VÀ ghi hóa đơn trong CÙNG một transaction để đảm bảo
    // tính nguyên tử: nếu ghi bill lỗi thì số hóa đơn cũng không bị tăng
    // (tránh nhảy số / trùng số).
    final invoiceNumber = await _firestore.runTransaction<int>((transaction) async {
      final snap = await transaction.get(userRef);
      final next = (snap.data()?['nextInvoiceNumber'] as num?)?.toInt() ?? 1;

      transaction.set(
        userRef,
        {'nextInvoiceNumber': next + 1},
        SetOptions(merge: true),
      );
      transaction.set(billRef, {
        'items': items.map((item) => item.toMap()).toList(),
        'total': total,
        'status': status,
        'invoiceNumber': next,
        'createdAt': FieldValue.serverTimestamp(),
        'clientCreatedAt': Timestamp.now(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return next;
    });

    try {
      await ProductService().decrementStockForSaleItems(items);
    } catch (_) {
      // Best-effort: trừ kho thất bại không làm hỏng hóa đơn đã lưu.
    }

    return BillRecord(
      id: billRef.id,
      items: items,
      total: total,
      status: status,
      createdAt: DateTime.now(),
      invoiceNumber: invoiceNumber,
    );
  }

  String formatInvoiceNumber(int num) {
    return 'HD-${num.toString().padLeft(6, '0')}';
  }

  Future<int> backfillBillItemPrices() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User not signed in');

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bills')
        .get();

    int updated = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final rawItems = (data['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      bool needsUpdate = false;
      final newItems = rawItems.map((item) {
        final priceText = (item['price'] ?? '').toString();
        final unitPrice = parsePriceToInt(priceText);
        final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
        final subtotal = unitPrice * quantity;
        if (item['unitPrice'] == null || item['subtotal'] == null) {
          needsUpdate = true;
        }
        return {...item, 'unitPrice': unitPrice, 'subtotal': subtotal};
      }).toList();

      if (!needsUpdate) continue;

      await doc.reference.set({
        'items': newItems,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      updated += 1;
    }

    return updated;
  }
}
