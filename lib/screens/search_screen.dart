// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../model/usermodel.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = false;
  bool _isStartingChat = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      _allUsers = snap.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where((u) => u.id != currentUid) // Exclude current user
          .toList();
      _filteredUsers = List.from(_allUsers);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      if (query.trim().isEmpty) {
        _filteredUsers = List.from(_allUsers);
      } else {
        final q = query.toLowerCase().trim();
        _filteredUsers = _allUsers.where((user) {
          return user.name.toLowerCase().contains(q) ||
              user.email.toLowerCase().contains(q) ||
              user.phone.toString().contains(q) ||
              user.occupation.toLowerCase().contains(q) ||
              user.place.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Future<void> _startChat(UserModel targetUser) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    setState(() => _isStartingChat = true);
    try {
      // Query chats involving current user
      final existingChatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUid)
          .get();

      String? chatId;
      for (var doc in existingChatQuery.docs) {
        final participants = doc.data()['participants'] as List?;
        if (participants != null && participants.contains(targetUser.id)) {
          chatId = doc.id;
          break;
        }
      }

      if (chatId == null) {
        // Create a new chat document if not exists
        final newChatDoc = await FirebaseFirestore.instance.collection('chats').add({
          'participants': [currentUid, targetUser.id],
          'createdAt': FieldValue.serverTimestamp(),
        });
        chatId = newChatDoc.id;
      }

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/chat',
          arguments: chatId,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting chat: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingChat = false);
    }
  }

  void _startCall(UserModel targetUser, String type) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    // Generate unique room ID
    final callId = 'call_${currentUid.substring(0, 5)}_${targetUser.id.substring(0, 5)}_${DateTime.now().millisecondsSinceEpoch}';

    Navigator.pushNamed(
      context,
      '/call',
      arguments: {
        'callId': callId,
        'type': type,
        'participants': [currentUid, targetUser.id],
      },
    );
  }

  Color _getAvatarColor(String name) {
    final hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    final colors = [
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
      Colors.teal,
      Colors.indigoAccent,
      Colors.redAccent,
    ];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Search Users'),
        backgroundColor: Colors.grey[900],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, phone, occupation, place...',
                    hintStyle: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredUsers.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? 'No other users registered yet'
                                  : 'No matches found',
                              style: GoogleFonts.inter(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              final avatarColor = _getAvatarColor(user.name);
                              final initials = user.name.isNotEmpty
                                  ? user.name.trim().substring(0, 1).toUpperCase()
                                  : '?';

                              return Card(
                                color: Colors.grey[950],
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: BorderSide(color: Colors.grey[900]!, width: 1),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: avatarColor,
                                    child: Text(
                                      initials,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    user.name,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email,
                                        style: GoogleFonts.inter(color: Colors.grey[450], fontSize: 12),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${user.occupation} • ${user.place}',
                                        style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.message),
                                        color: const Color(0xFF25D366), // WhatsApp Green
                                        onPressed: () => _startChat(user),
                                        tooltip: 'Chat',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.phone),
                                        color: Colors.blueAccent,
                                        onPressed: () => _startCall(user, 'audio'),
                                        tooltip: 'Voice Call',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.videocam),
                                        color: Colors.blueAccent,
                                        onPressed: () => _startCall(user, 'video'),
                                        tooltip: 'Video Call',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          if (_isStartingChat)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
