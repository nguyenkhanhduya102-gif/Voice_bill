import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductItem {
  final String id;
  final String name;
  final String unit;
  final String price;
  final int stock;

  const ProductItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.stock,
  });

  factory ProductItem.fromMap(String id, Map<String, dynamic> data) {
    return ProductItem(
      id: id,
      name: (data['name'] ?? '').toString(),
      unit: (data['unit'] ?? '').toString(),
      price: (data['price'] ?? '').toString(),
      stock: (data['stock'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'price': price,
      'stock': stock,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

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
      stock: stock,
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('products')
        .add(item.toMap());
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
          'stock': stock,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
