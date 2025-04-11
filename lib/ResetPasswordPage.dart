import 'package:ble_smart_attendance_app/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ResetPasswordPage extends StatefulWidget {
  final String? email;

  const ResetPasswordPage({Key? key, this.email}) : super(key: key);

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  // Variable for error messages.
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    // If an email is passed to the widget, set it to the controller.
    if (widget.email != null) {
      emailController.text = widget.email!;
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  // Function to reset the password.
  void resetPassword() async {
    try {
      await authService.value.resetPassword(email: emailController.text);
      showSnackBar();
      setState(() {
        errorMessage = '';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message ?? 'Something went wrong.';
      });
    }
  }

  // Function to show a snack bar confirmation.
  void showSnackBar() {
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        content: const Text(
          'Please check your email for a reset link.',
        ),
        showCloseIcon: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C130E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C130E),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey.shade400),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 100),
              Text(
                'Reset Password',
                style: GoogleFonts.roboto(
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '🔐',
                style: TextStyle(
                  fontSize: 50,
                  color: Colors.yellow.shade600,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Enter your email to receive a reset password link.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Email input field.
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF191E1D),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Display error message if any.
              if (errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              const Spacer(),
              // Button to send reset password link.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: resetPassword, // Corrected callback reference.
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D38C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Send Reset Link',
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
