// lib/screens/settings_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_user_service.dart';
import '../services/auth_service.dart';
import '../model/usermodel.dart';
import '../main.dart'; // Import themeModeProvider

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid ?? '';

    final profileAsync = ref.watch(userProfileProvider(uid));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Profile Section
            profileAsync.when(
              data: (userModel) {
                final name = userModel?.name ?? currentUser?.displayName ?? 'Guest User';
                final email = userModel?.email ?? currentUser?.email ?? 'No Email';
                final initials = name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : '?';

                return Card(
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              child: Text(
                                initials,
                                style: GoogleFonts.outfit(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    email,
                                    style: GoogleFonts.inter(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        // Display extra profile fields
                        _buildProfileField(context, Icons.info_outline, 'Age', '${userModel?.age ?? 0}'),
                        _buildProfileField(context, Icons.transgender, 'Gender', userModel?.gender.isNotEmpty == true ? userModel!.gender : 'Not specified'),
                        _buildProfileField(context, Icons.phone_android, 'Phone', userModel?.phone != null && userModel!.phone != 0 ? '+${userModel.phone}' : 'Not specified'),
                        _buildProfileField(context, Icons.work_outline, 'Occupation', userModel?.occupation.isNotEmpty == true ? userModel!.occupation : 'Not specified'),
                        _buildProfileField(context, Icons.location_on_outlined, 'Place', userModel?.place.isNotEmpty == true ? userModel!.place : 'Not specified'),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text('Edit Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            onPressed: () => _showEditProfileBottomSheet(context, uid, userModel),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Card(
                margin: EdgeInsets.all(16),
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (err, _) => Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading profile: $err'),
                ),
              ),
            ),

            // 2. Options Sections
            _buildSectionHeader('Preferences'),
            _buildSettingsList(context, [
              ListTile(
                leading: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
                title: const Text('Dark Mode'),
                trailing: Switch(
                  value: isDark,
                  onChanged: (val) {
                    ref.read(themeModeProvider.notifier).state = val ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
              ),
              ListTile(
                leading: Icon(_notificationsEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
                title: const Text('Push Notifications'),
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: (val) {
                    setState(() {
                      _notificationsEnabled = val;
                    });
                  },
                ),
              ),
            ]),

            _buildSectionHeader('Help & Info'),
            _buildSettingsList(context, [
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help & Support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showHelpDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAboutDialog(context),
              ),
            ]),

            const SizedBox(height: 16),
            // 3. Log Out Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: Text(
                    'Log Out',
                    style: GoogleFonts.outfit(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => _showLogoutConfirmationDialog(context),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 24, top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: children.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }

  Widget _buildProfileField(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.grey[500], fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- Show Edit Profile Modal Bottom Sheet ---
  void _showEditProfileBottomSheet(BuildContext context, String uid, UserModel? currentProfile) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: currentProfile?.name ?? '');
    final ageController = TextEditingController(text: currentProfile?.age != null && currentProfile!.age != 0 ? currentProfile.age.toString() : '');
    final phoneController = TextEditingController(text: currentProfile?.phone != null && currentProfile!.phone != 0 ? currentProfile.phone.toString() : '');
    final occupationController = TextEditingController(text: currentProfile?.occupation ?? '');
    final placeController = TextEditingController(text: currentProfile?.place ?? '');
    String gender = currentProfile?.gender ?? 'Male';

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Edit Profile',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Name Field
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Name cannot be empty';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Age Field
                      TextFormField(
                        controller: ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          prefixIcon: Icon(Icons.info_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val != null && val.isNotEmpty) {
                            final parsed = int.tryParse(val);
                            if (parsed == null || parsed <= 0) {
                              return 'Please enter a valid age';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Phone Field
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number (e.g. 919876543210)',
                          prefixIcon: Icon(Icons.phone_android),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val != null && val.isNotEmpty) {
                            final parsed = int.tryParse(val);
                            if (parsed == null) {
                              return 'Please enter a valid phone number';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Gender Dropdown
                      DropdownButtonFormField<String>(
                        value: ['Male', 'Female', 'Other'].contains(gender) ? gender : 'Male',
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.transgender),
                          border: OutlineInputBorder(),
                        ),
                        items: ['Male', 'Female', 'Other']
                            .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                            .toList(),
                        onChanged: (val) {
                          setModalState(() {
                            gender = val ?? 'Male';
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Occupation Field
                      TextFormField(
                        controller: occupationController,
                        decoration: const InputDecoration(
                          labelText: 'Occupation',
                          prefixIcon: Icon(Icons.work_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Place Field
                      TextFormField(
                        controller: placeController,
                        decoration: const InputDecoration(
                          labelText: 'Place',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isSaving ? null : () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.brightness == Brightness.dark ? Colors.black : Colors.white,
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (formKey.currentState!.validate()) {
                                        setModalState(() {
                                          isSaving = true;
                                        });

                                        try {
                                          final name = nameController.text.trim();
                                          final age = int.tryParse(ageController.text.trim()) ?? 0;
                                          final phone = int.tryParse(phoneController.text.trim()) ?? 0;
                                          final occupation = occupationController.text.trim();
                                          final place = placeController.text.trim();
                                          final email = currentProfile?.email ?? FirebaseAuth.instance.currentUser?.email ?? '';

                                          final updatedProfile = {
                                            'id': uid,
                                            'name': name,
                                            'age': age,
                                            'phone': phone,
                                            'gender': gender,
                                            'occupation': occupation,
                                            'place': place,
                                            'email': email,
                                          };

                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(uid)
                                              .set(updatedProfile, SetOptions(merge: true));

                                          // Invalidate the provider to refresh UI
                                          ref.invalidate(userProfileProvider(uid));

                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Profile updated successfully!')),
                                            );
                                          }
                                        } catch (e) {
                                          setModalState(() {
                                            isSaving = false;
                                          });
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error updating profile: $e')),
                                          );
                                        }
                                      }
                                    },
                              child: isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Show Help Dialog ---
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Help & Support', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Text(
            'For any queries, feedback, or support regarding the Sauhridam app, please reach out to us at: support@sauhridam.app',
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // --- Show About Dialog ---
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('About Sauhridam', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version: 1.0.0', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Sauhridam is a modern, real-time chat and video calling application designed to bring friends and family closer together.',
                style: GoogleFonts.inter(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // --- Show Logout Confirmation Dialog ---
  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Log Out', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to log out of Sauhridam?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                // Sign out Google and Firebase
                await GoogleAuthService.signOut();
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }
}
