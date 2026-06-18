





import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sauhridam/model/usermodel.dart';
class AuthService {

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;

  Future<User?> loginOrCreate(String email, String password) async {
    try {
      final res = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return res.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        rethrow;
      }
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        try {
          final res = await auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          return res.user;
        } on FirebaseAuthException catch (createError) {
          if (createError.code == 'email-already-in-use') {
            throw FirebaseAuthException(
              code: 'wrong-password',
              message: 'Incorrect password for this account.',
            );
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<bool> userProfileExists(String uid) async {
    final doc = await db.collection("users").doc(uid).get();
    if (!doc.exists) return false;
    final data = doc.data();
    if (data == null) return false;
    final phone = data['phone'];
    if (phone == null || phone == "") {
      return false;
    }
    return true;
  }

  Future<UserModel> getUser(String uid) async {

    final doc = await db.collection("users").doc(uid).get();

    return UserModel.fromMap(doc.data()!);
  }

  Future<void> createProfile(UserModel user) async {

    await db.collection("users").doc(user.id).set(user.toMap());
  }
}
class GoogleAuthService {

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static StreamSubscription<GoogleSignInAuthenticationEvent>? _authSub;

  static Future<void> init() async {

    await _googleSignIn.initialize();

    _authSub = _googleSignIn.authenticationEvents.listen(
      _handleAuthEvent,
      onError: (e) => print("Auth error: $e"),
    );

    // _googleSignIn.attemptLightweightAuthentication();
  }

  static Future<User?> signIn() async {

    try {

      if (_googleSignIn.supportsAuthenticate()) {
        final result = await _googleSignIn.authenticate();
        if (result == null) return null;

        final auth = await result.authentication;

        final credential = GoogleAuthProvider.credential(
          idToken: auth.idToken,
        );

        final userCred =
        await FirebaseAuth.instance.signInWithCredential(credential);

        return userCred.user;
      }

    } catch (e) {
      print(e);
    }

    return null;
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
  }

  static Future<void> _handleAuthEvent(
      GoogleSignInAuthenticationEvent event) async {

    if (event is GoogleSignInAuthenticationEventSignIn) {

      final account = event.user;
      if (account == null) return;

      final googleAuth = await account.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCred =
      await FirebaseAuth.instance.signInWithCredential(credential);

      await _createUserIfNotExists(userCred.user!);
    }
  }

  static Future<void> _createUserIfNotExists(User user) async {

    final db = FirebaseFirestore.instance;

    final doc = await db.collection("users").doc(user.uid).get();

    if (!doc.exists) {

      await db.collection("users").doc(user.uid).set({
        "id": user.uid,
        "name": user.displayName ?? "",
        "email": user.email ?? "",
        "age": 0,
        "gender": "",
        "phone": "",
        "occupation": "",
        "place": "",
        "createdAt": FieldValue.serverTimestamp()
      });
    }
  }

  static void dispose() {
    _authSub?.cancel();
  }
}