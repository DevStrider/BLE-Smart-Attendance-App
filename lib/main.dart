// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'auth_service.dart';
import 'WelcomePage.dart';

late ValueNotifier<AuthService> authService; // Declare it but don’t instantiate yet

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase first
  authService = ValueNotifier(AuthService()); // Now safe to create AuthService
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const WelcomePage(), // Your initial page
    );
  }
}
