// lib/services/firestore_user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

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
      'uid': uid,
      'email': email,
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
