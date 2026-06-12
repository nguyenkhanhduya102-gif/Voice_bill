import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class UserProfile {
  final String displayName;
  final String storeName;
  final String phone;
  final String address;
  final String photoUrl;
  final String bankName;
  final String bankShortName;
  final String bankBin;
  final String accountNumber;
  final String accountName;
  final String qrImageUrl;
  final String qrMode;

  const UserProfile({
    required this.displayName,
    required this.storeName,
    required this.phone,
    required this.address,
    required this.photoUrl,
    required this.bankName,
    required this.bankShortName,
    required this.bankBin,
    required this.accountNumber,
    required this.accountName,
    required this.qrImageUrl,
    required this.qrMode,
  });

  factory UserProfile.fromMap(Map<String, dynamic> data) {
    return UserProfile(
      displayName: (data['displayName'] ?? '').toString(),
      storeName: (data['storeName'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      photoUrl: (data['photoUrl'] ?? '').toString(),
      bankName: (data['bankName'] ?? '').toString(),
      bankShortName: (data['bankShortName'] ?? '').toString(),
      bankBin: (data['bankBin'] ?? '').toString(),
      accountNumber: (data['accountNumber'] ?? '').toString(),
      accountName: (data['accountName'] ?? '').toString(),
      qrImageUrl: (data['qrImageUrl'] ?? '').toString(),
      qrMode: (data['qrMode'] ?? 'auto').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'storeName': storeName,
      'phone': phone,
      'address': address,
      'photoUrl': photoUrl,
      'bankName': bankName,
      'bankShortName': bankShortName,
      'bankBin': bankBin,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'qrImageUrl': qrImageUrl,
      'qrMode': qrMode,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<UserProfile> streamProfile() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(
        const UserProfile(
          displayName: '',
          storeName: '',
          phone: '',
          address: '',
          photoUrl: '',
          bankName: '',
          bankShortName: '',
          bankBin: '',
          accountNumber: '',
          accountName: '',
          qrImageUrl: '',
          qrMode: 'auto',
        ),
      );
    }

    return _firestore.collection('users').doc(user.uid).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data() ?? {};
      return UserProfile.fromMap(data);
    });
  }

  Future<void> updateProfile({
    required String displayName,
    required String storeName,
    required String phone,
    required String address,
    String? photoUrl,
    String? bankName,
    String? bankShortName,
    String? bankBin,
    String? accountNumber,
    String? accountName,
    String? qrImageUrl,
    String? qrMode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User not signed in');

    await _firestore.collection('users').doc(user.uid).set({
      'displayName': displayName,
      'storeName': storeName,
      'phone': phone,
      'address': address,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (bankName != null) 'bankName': bankName,
      if (bankShortName != null) 'bankShortName': bankShortName,
      if (bankBin != null) 'bankBin': bankBin,
      if (accountNumber != null) 'accountNumber': accountNumber,
      if (accountName != null) 'accountName': accountName,
      if (qrImageUrl != null) 'qrImageUrl': qrImageUrl,
      if (qrMode != null) 'qrMode': qrMode,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> uploadAvatar(XFile file) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User not signed in');

    final ref = _storage
        .ref()
        .child('users')
        .child(user.uid)
        .child('avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');

    final uploadTask = kIsWeb
        ? ref.putData(await file.readAsBytes())
        : ref.putFile(File(file.path));

    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  Future<String> uploadQrImage(XFile file) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User not signed in');

    final ref = _storage
        .ref()
        .child('users')
        .child(user.uid)
        .child('qr_${DateTime.now().millisecondsSinceEpoch}.png');

    final uploadTask = kIsWeb
        ? ref.putData(await file.readAsBytes())
        : ref.putFile(File(file.path));

    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }
}
