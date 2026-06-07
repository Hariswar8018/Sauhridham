// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_user_service.dart';
import '../widget/widget.dart';
import 'home_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _occupationController = TextEditingController();
  final _placeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _occupationController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _usernameController.text.trim();
    final phone = _phoneController.text.trim();
    final ageStr = _ageController.text.trim();
    final gender = _genderController.text.trim();
    final occupation = _occupationController.text.trim();
    final place = _placeController.text.trim();

    if (name.isEmpty || phone.isEmpty || ageStr.isEmpty || gender.isEmpty || occupation.isEmpty || place.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final age = int.tryParse(ageStr);
    if (age == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid age')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Not authenticated. Please log in again.');
      }

      // Store extra profile info in Firestore
      await FirestoreUserService().createUserProfile(
        uid: user.uid,
        email: user.email ?? "",
        username: name,
        phone: phone,
        age: age,
        gender: gender,
        occupation: occupation,
        place: place,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Image.network(
                  "https://cdn-icons-gif.flaticon.com/12999/12999687.gif",
                  width: 120,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "Setup Profile",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: Colors.black,
                ),
              ),
              const Text(
                "Fill in details to complete your account setup",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              
              // Username
              TextField(
                style: const TextStyle(color: Colors.black),
                controller: _usernameController,
                decoration: const InputDecoration(
                  hintText: "Username / Name",
                  hintStyle: TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
                ),
              ),
              const SizedBox(height: 12),

              // Phone
              TextField(
                style: const TextStyle(color: Colors.black),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: "Phone Number",
                  hintStyle: TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
                ),
              ),
              const SizedBox(height: 12),

              // Age
              TextField(
                style: const TextStyle(color: Colors.black),
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: "Age",
                  hintStyle: TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
                ),
              ),
              const SizedBox(height: 12),

              // Gender
              TextField(
                style: const TextStyle(color: Colors.black),
                controller: _genderController,
                decoration: const InputDecoration(
                  hintText: "Gender",
                  hintStyle: TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
                ),
              ),
              const SizedBox(height: 12),

              // Occupation
              TextField(
                style: const TextStyle(color: Colors.black),
                controller: _occupationController,
                decoration: const InputDecoration(
                  hintText: "Occupation",
                  hintStyle: TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
                ),
              ),
              const SizedBox(height: 12),

              // Place
              TextField(
                style: const TextStyle(color: Colors.black),
                controller: _placeController,
                decoration: const InputDecoration(
                  hintText: "Place",
                  hintStyle: TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
                ),
              ),
              const SizedBox(height: 24),

              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        backgroundColor: Colors.white,
                        color: Colors.green,
                      ),
                    )
                  : InkWell(
                      onTap: _register,
                      child: GlobalWidget.contain(w, "Complete Profile"),
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
