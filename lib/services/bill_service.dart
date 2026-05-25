import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BillItem {
  final String name;
  final int quantity;
  final String price;

  const BillItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'quantity': quantity, 'price': price};
  }

  factory BillItem.fromMap(Map<String, dynamic> data) {
    return BillItem(
      name: (data['name'] ?? '').toString(),
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      price: (data['price'] ?? '').toString(),
    );
  }
}

class BillRecord {
  final String id;
  final List<BillItem> items;
  final int total;
  final String status;
  final DateTime? createdAt;

  const BillRecord({
    required this.id,
    required this.items,
    required this.total,
    required this.status,
    required this.createdAt,
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
    );
  }
}

class BillService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<BillRecord>> streamBills() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value([]);
      }

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
    if (user == null) {
      throw StateError('User not signed in');
    }

    final payload = {
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'status': status,
      'createdAt': Timestamp.now(),
    };

    final docRef = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bills')
        .add(payload);

    return BillRecord(
      id: docRef.id,
      items: items,
      total: total,
      status: status,
      createdAt: DateTime.now(),
    );
  }
}
