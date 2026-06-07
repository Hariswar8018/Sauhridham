// lib/services/firestore_user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/usermodel.dart';

final userProfileProvider = FutureProvider.family<UserModel?, String>((ref, uid) async {
  if (uid.isEmpty) return null;
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  if (!doc.exists || doc.data() == null) return null;
  return UserModel.fromMap(doc.data()!);
});

class FirestoreUserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Creates a user document in the `users` collection with the given fields.
  /// All fields are stored as strings except `age` which is stored as an int.
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String username,
    required String phone,
    required int age,
    required String gender,
    required String occupation,
    required String place,
  }) async {
    final data = {
      'id': uid,
      'uid': uid,
      'email': email,
      'name': username,
      'username': username,
      'phone': phone,
      'age': age,
      'gender': gender,
      'occupation': occupation,
      'place': place,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await _db.collection('users').doc(uid).set(data);
  }
}
