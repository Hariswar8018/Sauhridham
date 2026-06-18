import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sauhridam/widget/widget.dart'; // GlobalWidget

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar("Please enter your email address");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _showSnackBar("Password reset email sent! Please check your inbox.");
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message ?? "Failed to send reset email");
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF014A8E).withOpacity(0.12),
                    border: Border.all(color: const Color(0xFF014A8E).withOpacity(0.4), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    size: 64,
                    color: Color(0xFF014A8E),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "Reset Password",
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Enter your registered email address below. We'll send you instructions to reset your password.",
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: "Email Address",
                  hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.black54),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: isDark ? Colors.white30 : Colors.black),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: isDark ? Colors.white30 : Colors.black),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        backgroundColor: Colors.white,
                        color: Color(0xff014A8E),
                      ),
                    )
                  : InkWell(
                      onTap: _resetPassword,
                      child: GlobalWidget.contain(w, "Send Reset Link"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
