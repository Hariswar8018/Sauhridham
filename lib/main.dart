

// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/notification_service.dart';
import 'screens/chat_screen.dart';
import 'screens/call_screen.dart';
import 'screens/search_screen.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

// Background message handler (required for Android & iOS)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Handle background notification (e.g., store call log, show notification)
  // For simplicity, we just print the message.
  print('Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    // Configure foreground notification handling
    FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    return MaterialApp(
      title: 'Sauhridam Chat',
      theme: ThemeData.light().copyWith(
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF25D366), // WhatsApp green accent
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF25D366), // WhatsApp green accent
          surface: const Color(0xFF121212),
          onSurface: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: themeMode,
      home: const AuthWrapper(),
      routes: {
        '/chat': (context) => const ChatScreen(),
        '/call': (context) => const CallScreen(),
        '/search': (context) => const SearchScreen(),
      },
      builder: (context, child) {
        // Initialize notification listeners once
        NotificationService.init(context, ref);
        return child!;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

