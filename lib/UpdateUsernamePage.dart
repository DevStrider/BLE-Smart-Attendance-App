// lib/UpdateUsernamePage.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_service.dart';
import 'database_service.dart';

class UpdateUsernamePage extends StatefulWidget {
  final String? email;
  const UpdateUsernamePage({Key? key, this.email}) : super(key: key);

  @override
  _UpdateUsernamePageState createState() => _UpdateUsernamePageState();
}

class _UpdateUsernamePageState extends State<UpdateUsernamePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // <-- Inject DatabaseService
  final DatabaseService _dbService = DatabaseService();

  late final AnimationController _animController;
  late final Animation<double> _headerFade;
  late final Animation<double> _iconScale;
  late final Animation<double> _fieldFade;
  late final Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _headerFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    );

    _iconScale = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.3, 0.5, curve: Curves.elasticOut),
    );

    _fieldFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.5, 0.7, curve: Curves.easeIn),
    );

    _buttonFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _updateUsername() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final newName = _usernameController.text.trim();

    setState(() {}); // rebuild to disable button if you like

    try {
      // 1) Update Auth displayName
      await authService.value.updateUsername(username: newName);

      // 2) Also persist in Realtime Database under students/$uid/name
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await _dbService.update(
        path: 'students/$uid',
        data: {'name': newName},
      );

      _showSnackbar('Username updated successfully', success: true);
    } on FirebaseAuthException catch (e) {
      _showSnackbar(e.message ?? 'Username update failed', success: false);
    } catch (e) {
      _showSnackbar('Could not save to database', success: false);
    }
  }

  void _showSnackbar(String message, {required bool success}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.openSans(fontSize: 16),
        ),
        backgroundColor:
        success ? const Color(0xFF00D38C) : Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF004D43), Color(0xFF046307)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  FadeTransition(
                    opacity: _headerFade,
                    child: Text(
                      'Update Username',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ScaleTransition(
                    scale: _iconScale,
                    child: const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.edit, size: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeTransition(
                    opacity: _fieldFade,
                    child: TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your username';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'New Username',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF191E1D),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FadeTransition(
                    opacity: _buttonFade,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _updateUsername,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D38C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Update Username',
                          style: GoogleFonts.openSans(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
    );
  }
}