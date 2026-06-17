import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:voice_bill/models/bill_models.dart';
import 'package:voice_bill/models/product_item.dart';

class ProductService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ProductItem>> streamProducts() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('products')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductItem.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> addProduct({
    required String name,
    required String unit,
    required int priceValue,
    int stock = 1,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User not signed in');
    }

    final item = ProductItem(
      id: '',
      name: name,
      unit: unit,
      priceValue: priceValue < 0 ? 0 : priceValue,
      stock: stock,
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('products')
        .add({...item.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Gộp các dòng nhập trùng tên trong CÙNG một lô (summing quantity, lấy
  /// giá/đơn vị mới nhất). Thuần (không I/O) để test được. Khóa = tên chuẩn hóa.
  static Map<String, Map<String, dynamic>> aggregateStockItems(
      List<Map<String, dynamic>> items) {
    final agg = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final name = (item['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final key = _normalizeKey(name);
      final unit = (item['unit'] ?? 'cái').toString().trim();
      final price = (item['priceValue'] as num?)?.toInt() ??
          (item['price'] as num?)?.toInt() ??
          0;
      final rawQty = (item['quantity'] as num?)?.toInt() ?? 1;
      final qty = rawQty <= 0 ? 1 : rawQty;

      final existing = agg[key];
      if (existing == null) {
        agg[key] = {
          'name': name,
          'unit': unit.isEmpty ? 'cái' : unit,
          'priceValue': price < 0 ? 0 : price,
          'quantity': qty,
        };
      } else {
        existing['quantity'] = (existing['quantity'] as int) + qty;
        if (price > 0) existing['priceValue'] = price;
        if (unit.isNotEmpty) existing['unit'] = unit;
      }
    }
    return agg;
  }

  /// Lưu danh sách mặt hàng nhập: trùng tên (đã có trong kho) -> cộng dồn tồn +
  /// cập nhật giá/đơn vị mới; chưa có -> tạo mới. Trả về (added, merged).
  Future<({int added, int merged})> upsertProducts(
      List<Map<String, dynamic>> items) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User not signed in');
    }
    final aggregated = aggregateStockItems(items).values.toList();
    if (aggregated.isEmpty) return (added: 0, merged: 0);

    final col =
        _firestore.collection('users').doc(user.uid).collection('products');
    final snapshot = await col.get();
    final byName = <String, DocumentReference<Map<String, dynamic>>>{};
    for (final doc in snapshot.docs) {
      final key = _normalizeKey((doc.data()['name'] ?? '').toString());
      if (key.isNotEmpty) byName.putIfAbsent(key, () => doc.reference);
    }

    final batch = _firestore.batch();
    int added = 0, merged = 0;
    for (final item in aggregated) {
      final name = item['name'] as String;
      final unit = item['unit'] as String;
      final priceValue = item['priceValue'] as int;
      final qty = item['quantity'] as int;
      final key = _normalizeKey(name);

      final existing = byName[key];
      if (existing != null) {
        final update = <String, dynamic>{
          'stock': FieldValue.increment(qty),
          'unit': unit,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (priceValue > 0) update['priceValue'] = priceValue;
        batch.update(existing, update);
        merged++;
      } else {
        batch.set(col.doc(), {
          'name': name,
          'unit': unit,
          'priceValue': priceValue,
          'stock': qty,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        added++;
      }
    }
    await batch.commit();
    return (added: added, merged: merged);
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required String unit,
    required int priceValue,
    required int stock,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User not signed in');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('products')
        .doc(id)
        .set({
          'name': name,
          'unit': unit,
          'priceValue': priceValue < 0 ? 0 : priceValue,
          'stock': stock,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> deleteProduct(String id) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User not signed in');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('products')
        .doc(id)
        .delete();
  }

  Future<int> backfillPriceValues() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User not signed in');
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('products')
        .get();

    int updated = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final existingValue = (data['priceValue'] as num?)?.toInt() ?? 0;
      if (existingValue > 0) {
        continue;
      }
      final priceText = (data['price'] ?? '').toString();
      final parsed = ProductItem.parsePriceToInt(priceText);
      if (parsed <= 0) {
        continue;
      }
      await doc.reference.set({
        'priceValue': parsed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      updated += 1;
    }

    return updated;
  }

  /// Nạp toàn bộ sản phẩm 1 lần (không realtime). Dùng để đưa danh mục vào
  /// prompt Gemini và để resolve productId cho item bán.
  Future<List<ProductItem>> fetchProducts() async {
    final user = _auth.currentUser;
    if (user == null) {
      return [];
    }
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('products')
        .get();
    return snapshot.docs
        .map((doc) => ProductItem.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<int> decrementStockForSaleItems(List<BillItem> items) =>
      _adjustStockForSaleItems(items, -1);

  /// Hoàn lại tồn kho khi xóa hóa đơn (cộng trả số lượng đã trừ lúc bán).
  Future<int> restoreStockForSaleItems(List<BillItem> items) =>
      _adjustStockForSaleItems(items, 1);

  Future<int> _adjustStockForSaleItems(List<BillItem> items, int sign) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User not signed in');
    }
    if (items.isEmpty) {
      return 0;
    }

    final productsRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('products');

    // Gom số lượng bán theo từng document sản phẩm. Ưu tiên productId (chính
    // xác tuyệt đối); nếu item không có productId thì mới rơi về khớp tên.
    final snapshot = await productsRef.get();
    final refById = <String, DocumentReference<Map<String, dynamic>>>{};
    final refByName = <String, DocumentReference<Map<String, dynamic>>>{};
    for (final doc in snapshot.docs) {
      refById[doc.id] = doc.reference;
      final key = _normalizeKey((doc.data()['name'] ?? '').toString());
      if (key.isNotEmpty) {
        refByName[key] = doc.reference;
      }
    }

    final soldByRef = <DocumentReference<Map<String, dynamic>>, int>{};
    for (final item in items) {
      final qty = item.quantity <= 0 ? 0 : item.quantity;
      if (qty == 0) continue;

      DocumentReference<Map<String, dynamic>>? ref;
      if (item.productId != null) {
        ref = refById[item.productId];
      }
      ref ??= refByName[_normalizeKey(item.name)];
      if (ref == null) continue;

      soldByRef[ref] = (soldByRef[ref] ?? 0) + qty;
    }

    if (soldByRef.isEmpty) {
      return 0;
    }

    await _firestore.runTransaction((transaction) async {
      // Đọc tất cả trước khi ghi (yêu cầu của transaction Firestore).
      final snaps = <DocumentReference<Map<String, dynamic>>,
          DocumentSnapshot<Map<String, dynamic>>>{};
      for (final ref in soldByRef.keys) {
        snaps[ref] = await transaction.get(ref);
      }
      for (final entry in soldByRef.entries) {
        final snap = snaps[entry.key];
        if (snap == null || !snap.exists) continue;
        final currentStock = (snap.data()?['stock'] as num?)?.toInt() ?? 0;
        final nextStock = currentStock + sign * entry.value;
        transaction.update(entry.key, {
          'stock': nextStock < 0 ? 0 : nextStock,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    return soldByRef.length;
  }

  static String _normalizeKey(String input) {
    return input.trim().toLowerCase();
  }
}
