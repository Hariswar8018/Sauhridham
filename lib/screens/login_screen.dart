


// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import 'package:sauhridam/services/auth_service.dart';
import 'package:sauhridam/widget/global.widget.dart'; // GlobalWidget

final loginProvider = Provider((ref) => FirebaseAuth.instance);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailC = TextEditingController();
  final passC = TextEditingController();

  final auth = AuthService();
  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);
    try {
      final user = await auth.loginOrCreate(
        emailC.text.trim(),
        passC.text.trim(),
      );
      if (user == null) return;
      final exists = await auth.userProfileExists(user.uid);
      if (!mounted) return;
      if (exists) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RegisterScreen(uid: user.uid)),
        );
      }
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> google() async {
    setState(() => loading = true);
    try {
      final user = await GoogleAuthService.signIn();
      if (user == null) return;
      final exists = await auth.userProfileExists(user.uid);
      if (!mounted) return;
      if (exists) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RegisterScreen(uid: user.uid)),
        );
      }
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(child: Image.asset("assets/logo.jpg", width: 140)),
            const Text(
              "Welcome Back",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
            ),
            const Text(
              "Sign in to manage your Appointments and manage live Tokens",
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 17,
                  color: Colors.grey),
            ),
            TextField(
              controller: emailC,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passC,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            loading
                ? const Center(
                    child: CircularProgressIndicator(
                      backgroundColor: Colors.white,
                      color: Colors.green,
                    ),
                  )
                : InkWell(
                    onTap: login,
                    child: GlobalWidget.contain(w, "Login"),
                  ),
            const SizedBox(height: 10),
            loading ? const SizedBox() : const Center(child: Text("OR")),
            const SizedBox(height: 10),
            loading
                ? const SizedBox()
                : InkWell(
                    onTap: google,
                    child: Container(
                      width: w,
                      height: 55,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset("assets/img.png", width: 20),
                          const SizedBox(width: 15),
                          const Text(
                            "Login with Google",
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
