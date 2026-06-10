import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _countryCodeController = TextEditingController(text: "+91");
  final _otpController = TextEditingController();
  final _auth = AuthService();

  bool _isOtpSent = false;
  bool _isLoading = false;
  String _verificationId = '';
  int? _resendToken;

  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _countryCodeController.dispose();
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown == 0) {
        setState(() {
          _timer?.cancel();
        });
      } else {
        setState(() {
          _resendCountdown--;
        });
      }
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    final countryCode = _countryCodeController.text.trim();

    if (phone.isEmpty) {
      _showSnackBar("Please enter your phone number");
      return;
    }
    if (countryCode.isEmpty) {
      _showSnackBar("Please enter country code");
      return;
    }

    final fullPhoneNumber = "$countryCode$phone";

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval or instant verification
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          _showSnackBar(e.message ?? "Verification failed. Check your number.");
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _isOtpSent = true;
            _isLoading = false;
          });
          _startCountdown();
          _showSnackBar("OTP code sent to $fullPhoneNumber");
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error: ${e.toString()}");
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      _showSnackBar("Please enter the 6-digit OTP code");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );
      await _signInWithCredential(credential);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Incorrect OTP. Please try again.");
    }
  }

  Future<void> _signInWithCredential(AuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final exists = await _auth.userProfileExists(user.uid);
        if (!mounted) return;

        if (exists) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Authentication failed: ${e.toString()}");
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87),
          onPressed: () {
            if (_isOtpSent) {
              setState(() {
                _isOtpSent = false;
                _otpController.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Icon Header with neon accent glow
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF25D366).withOpacity(0.12),
                    border: Border.all(color: const Color(0xFF25D366).withOpacity(0.4), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.phone_iphone_rounded,
                    size: 64,
                    color: Color(0xFF25D366),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              Text(
                _isOtpSent ? "Verification Code" : "Phone Login",
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isOtpSent
                    ? "Enter the 6-digit verification OTP code sent to your mobile phone number."
                    : "Enter your phone number to get signed in immediately. We'll send a 6-digit OTP code.",
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: isDark ? Colors.grey[400] : Colors.grey[650],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              if (!_isOtpSent) ...[
                // Phone number inputs
                Row(
                  children: [
                    // Country code input
                    Container(
                      width: 80,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          width: 1.2,
                        ),
                      ),
                      child: TextField(
                        controller: _countryCodeController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Phone input
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                            width: 1.2,
                          ),
                        ),
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: "Phone Number",
                            hintStyle: GoogleFonts.inter(
                              color: Colors.grey[500],
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                
                // Submit Button
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF25D366),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366).withOpacity(0.35),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _sendOtp,
                          child: Text(
                            "Send Verification OTP",
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
              ] else ...[
                // OTP Entry Input fields using custom visual code grid
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Hidden TextField for input
                      Opacity(
                        opacity: 0,
                        child: SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            autofocus: true,
                            onChanged: (val) {
                              setState(() {});
                              if (val.length == 6) {
                                _verifyOtp();
                              }
                            },
                            decoration: const InputDecoration(
                              counterText: "",
                            ),
                          ),
                        ),
                      ),
                      // Visual Digit Boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) {
                          String char = "";
                          if (_otpController.text.length > index) {
                            char = _otpController.text[index];
                          }
                          bool isFocused = _otpController.text.length == index;

                          return Container(
                            width: size.width * 0.12,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isFocused
                                    ? const Color(0xFF25D366)
                                    : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
                                width: isFocused ? 2 : 1.2,
                              ),
                              boxShadow: isFocused
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF25D366).withOpacity(0.2),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                char,
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                
                // Countdown/Resend row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _resendCountdown > 0
                          ? "Resend code in ${_resendCountdown}s"
                          : "Didn't receive the code?",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[650],
                      ),
                    ),
                    if (_resendCountdown == 0) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sendOtp,
                        child: Text(
                          "Resend OTP",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF25D366),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 36),
                
                // Action verify button
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF25D366),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366).withOpacity(0.35),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _verifyOtp,
                          child: Text(
                            "Verify & Continue",
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isOtpSent = false;
                        _otpController.clear();
                      });
                    },
                    child: Text(
                      "Change Phone Number",
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
