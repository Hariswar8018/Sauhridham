// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'phone_login_screen.dart';
import 'package:sauhridam/services/auth_service.dart';
import 'package:sauhridam/widget/widget.dart'; // GlobalWidget

final loginProvider = Provider((ref) => FirebaseAuth.instance);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailC = TextEditingController();
  final passC = TextEditingController();

  final auth = AuthService();
  bool loading = false;

  Future<void> login() async {
    if (emailC.text.trim().isEmpty || passC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both email and password")),
      );
      return;
    }
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
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Authentication failed")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
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
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Google Sign-In failed")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
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
            const SizedBox(height: 40),
            Center(
              child: Image.network(
                "https://cdn-icons-gif.flaticon.com/12999/12999687.gif",
                width: 140,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              "Welcome Back",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: Colors.black,
              ),
            ),
            const Text(
              "Sign in to do Live Chats, Video & Voice Calls with ease",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 17,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),
            TextField(
              style: const TextStyle(
                color: Colors.black, // typed text color
              ),
              controller: emailC,
              decoration: InputDecoration(
                hintText: "Email",
                hintStyle: TextStyle(color: Colors.black54),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: passC,
              obscureText: true,
              style: const TextStyle(
                color: Colors.black, // typed text color
              ),
              decoration: InputDecoration(
                hintText: "Password",
                labelStyle: TextStyle(color: Colors.black),
                hintStyle: TextStyle(color: Colors.black54),

                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
              ),
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
            loading
                ? const SizedBox()
                : const Center(
                    child: Text("OR", style: TextStyle(color: Colors.black)),
                  ),
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
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 10),
            loading
                ? const SizedBox()
                : InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                      );
                    },
                    child: Container(
                      width: w,
                      height: 55,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.phone, color: Colors.white),
                          const SizedBox(width: 15),
                          const Text(
                            "Login with Phone",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
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
