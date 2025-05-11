// lib/RegisterPage.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'database_service.dart';
import 'auth_service.dart';
import 'HomePage.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  // Your original static list of courses
  static const List<String> coursesList = [
    'Transmission & Switching (NETW601)',
    'Networks Lab (NETW602)',
    'Computer Architecture (NETW603)',
    'Network Protocols (NETW703)',
    'Intro to Management (MNGT601)',
    'Modeling & Simulation (NETW707)',
    'Channel Coding (COMM604)',
  ];

  // Controllers & FocusNodes (unchanged)
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController  = TextEditingController();
  final TextEditingController idController        = TextEditingController();
  final TextEditingController emailController     = TextEditingController();
  final TextEditingController passwordController  = TextEditingController();

  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus  = FocusNode();
  final FocusNode _idFocus        = FocusNode();
  final FocusNode _emailFocus     = FocusNode();
  final FocusNode _passwordFocus  = FocusNode();

  final DatabaseService _dbService = DatabaseService();

  String errorMessage = '';
  bool isLoading   = false;
  bool _visible    = false;

  @override
  void initState() {
    super.initState();
    // Fade in the form
    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    idController.dispose();
    emailController.dispose();
    passwordController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _idFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> register() async {
    // 1) Validate inputs
    if (firstNameController.text.isEmpty ||
        lastNameController.text.isEmpty  ||
        idController.text.isEmpty        ||
        emailController.text.isEmpty     ||
        passwordController.text.isEmpty) {
      setState(() => errorMessage = 'Please fill in all fields');
      return;
    }

    setState(() {
      errorMessage = '';
      isLoading    = true;
    });

    try {
      // 2) Create the Firebase Auth user
      await authService.value.createAccount(
        email:    emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // 3) Update displayName
      final user = FirebaseAuth.instance.currentUser!;
      await user.updateDisplayName(
        '${firstNameController.text} ${lastNameController.text}',
      );
      final uid = user.uid;

      // 4) Compute the next 12 session‐dates, skipping Thursday & Friday
      final today = DateTime.now();
      final sessions = <DateTime>[];
      var cursor = today;
      while (sessions.length < 12) {
        if (cursor.weekday != DateTime.thursday &&
            cursor.weekday != DateTime.friday) {
          sessions.add(cursor);
        }
        cursor = cursor.add(const Duration(days: 1));
      }

      // 5) Build a nested attendance map: { course: { 'yyyy-MM-dd': {} } }
      final attendanceMap = <String, dynamic>{
        for (var course in coursesList)
          course: {
            for (var dt in sessions)
              DateFormat('yyyy-MM-dd').format(dt): <String, dynamic>{}
          }
      };

      // 6) Write the entire student record in one go
      await _dbService.create(
        path: 'students/$uid',
        data: {
          'name':       user.displayName,
          'email':      user.email,
          'studentId':  idController.text.trim(),
          'createdAt':  ServerValue.timestamp,
          'courses':    coursesList,
          'attendance': attendanceMap,
        },
        generateKey: false,
      );

      // 7) Navigate to Home
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = e.message ?? 'Registration error');
    } catch (e) {
      debugPrint('DB error: $e');
      setState(() => errorMessage = 'Could not save profile. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF004D43), Color(0xFF046307)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 800),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  left: 24, right: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ← Back arrow (unchanged)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white70),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 🔒 Lock icon
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock, size: 40, color: Colors.white),
                        ),
                        const SizedBox(height: 24),

                        // Title & subtitle
                        Text(
                          'Register',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your account',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.openSans(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // First Name
                        TextField(
                          controller: firstNameController,
                          focusNode: _firstNameFocus,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => FocusScope.of(context).requestFocus(_lastNameFocus),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'First Name',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true, fillColor: Colors.white24,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Last Name
                        TextField(
                          controller: lastNameController,
                          focusNode: _lastNameFocus,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => FocusScope.of(context).requestFocus(_idFocus),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Last Name',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true, fillColor: Colors.white24,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Student ID
                        TextField(
                          controller: idController,
                          focusNode: _idFocus,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocus),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Student ID',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true, fillColor: Colors.white24,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Email
                        TextField(
                          controller: emailController,
                          focusNode: _emailFocus,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Email',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true, fillColor: Colors.white24,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextField(
                          controller: passwordController,
                          focusNode: _passwordFocus,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => register(),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true, fillColor: Colors.white24,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Error message
                        if (errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              errorMessage,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const Spacer(),

                        // Register button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF046307),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: isLoading
                                ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(const Color(0xFF046307)),
                              ),
                            )
                                : Text(
                              'Register',
                              style: GoogleFonts.openSans(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}