import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'providers/chat_provider.dart';
import 'services/connectivity_service.dart';
import 'services/auth_service.dart';
import 'ui/screens/contacts_screen.dart';
import 'ui/screens/auth_screen.dart';

class FirebaseWebConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');

  static bool get isComplete {
    return apiKey.isNotEmpty &&
        authDomain.isNotEmpty &&
        projectId.isNotEmpty &&
        storageBucket.isNotEmpty &&
        messagingSenderId.isNotEmpty &&
        appId.isNotEmpty;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kIsWeb) {
      if (FirebaseWebConfig.isComplete) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: FirebaseWebConfig.apiKey,
            authDomain: FirebaseWebConfig.authDomain,
            projectId: FirebaseWebConfig.projectId,
            storageBucket: FirebaseWebConfig.storageBucket,
            messagingSenderId: FirebaseWebConfig.messagingSenderId,
            appId: FirebaseWebConfig.appId,
          ),
        );
      } else {
        debugPrint(
          'Firebase web config is missing. Provide --dart-define values before enabling auth.',
        );
      }
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProxyProvider<ConnectivityService, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, connectivity, chatProvider) {
            chatProvider!.setBleMeshService(connectivity.bleMeshService);
            return chatProvider;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF6750A4);
    
    return MaterialApp(
      title: 'Mesh Messenger',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const ContactsScreen();
        }
        return const AuthScreen();
      },
    );
  }
}
