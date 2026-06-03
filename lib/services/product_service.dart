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
    required String price,
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
      price: price,
      priceValue: ProductItem.parsePriceToInt(price),
      stock: stock,
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('products')
        .add({...item.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required String unit,
    required String price,
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
          'price': price,
          'priceValue': ProductItem.parsePriceToInt(price),
          'stock': stock,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
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

  Future<int> decrementStockForSaleItems(List<BillItem> items) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User not signed in');
    }
    if (items.isEmpty) {
      return 0;
    }

    final soldByName = <String, int>{};
    for (final item in items) {
      final key = _normalizeKey(item.name);
      if (key.isEmpty) {
        continue;
      }
      soldByName[key] = (soldByName[key] ?? 0) + (item.quantity <= 0 ? 0 : item.quantity);
    }
    if (soldByName.isEmpty) {
      return 0;
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('products')
        .get();

    final productsByName = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in snapshot.docs) {
      final name = (doc.data()['name'] ?? '').toString();
      final key = _normalizeKey(name);
      if (key.isEmpty) {
        continue;
      }
      productsByName[key] = doc;
    }

    final batch = _firestore.batch();
    int updated = 0;
    for (final entry in soldByName.entries) {
      final doc = productsByName[entry.key];
      if (doc == null) {
        continue;
      }
      final currentStock = (doc.data()['stock'] as num?)?.toInt() ?? 0;
      final nextStock = (currentStock - entry.value);
      batch.set(
        doc.reference,
        {
          'stock': nextStock < 0 ? 0 : nextStock,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      updated += 1;
    }

    if (updated == 0) {
      return 0;
    }

    await batch.commit();
    return updated;
  }

  static String _normalizeKey(String input) {
    return input.trim().toLowerCase();
  }
}
