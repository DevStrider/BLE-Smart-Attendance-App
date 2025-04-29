import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

/// Central emerald color definitions
class AppColors {
  static const deepEmerald  = Color(0xFF004D43);
  static const jewelEmerald = Color(0xFF046307);
  static const cardBg       = Color(0xFF191E1D);
  // 24% opacity white
  static const white24      = Color(0x3DFFFFFF);
}

class ResetPasswordPage extends StatefulWidget {
  final String? email;
  const ResetPasswordPage({super.key, this.email});

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  late AnimationController _iconController;
  late Animation<double> _iconBounce;
  bool _formVisible = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.email != null) {
      _emailController.text = widget.email!;
    }

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _iconBounce = Tween(begin: 1.0, end: 1.2)
        .animate(CurvedAnimation(parent: _iconController, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() => _formVisible = true);
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await authService.value.resetPassword(email: _emailController.text.trim());
      _showSnackBar('Please check your email for a reset link.');
      setState(() => _errorMessage = '');
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Something went wrong.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        backgroundColor: AppColors.jewelEmerald,
        showCloseIcon: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.deepEmerald, AppColors.jewelEmerald],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Animated lock icon
              Expanded(
                flex: 2,
                child: Center(
                  child: ScaleTransition(
                    scale: _iconBounce,
                    child: Icon(Icons.lock_reset, size: 80, color: Colors.yellow.shade600),
                  ),
                ),
              ),

              // Title & subtitle
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Text(
                      'Reset Password',
                      style: GoogleFonts.poppins(
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your email to receive a reset link',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.openSans(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                flex: 3,
                child: AnimatedOpacity(
                  opacity: _formVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 600),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            style: const TextStyle(color: Colors.white),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Email is required';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: 'Email',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: AppColors.cardBg, //or white24
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_errorMessage.isNotEmpty)
                            Text(
                              _errorMessage,
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          const Spacer(),

                          // Send Reset Link button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _resetPassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.jewelEmerald,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text(
                                'Send Reset Link',
                                style: GoogleFonts.openSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}