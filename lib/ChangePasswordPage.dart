import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({Key? key, this.email}) : super(key: key);
  final String? email;

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _currentFocus = FocusNode();
  final FocusNode _newFocus = FocusNode();

  late final AnimationController _animController;
  late final Animation<double> _headerFade;
  late final Animation<double> _iconScale;
  late final Animation<double> _emailFade;
  late final Animation<double> _currentFade;
  late final Animation<double> _newFade;
  late final Animation<double> _buttonFade;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.email != null) {
      _emailController.text = widget.email!;
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _headerFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.2, curve: Curves.easeIn),
    );
    _iconScale = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 0.35, curve: Curves.elasticOut),
    );
    _emailFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.35, 0.55, curve: Curves.easeIn),
    );
    _currentFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.55, 0.75, curve: Curves.easeIn),
    );
    _newFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.75, 0.9, curve: Curves.easeIn),
    );
    _buttonFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.9, 1.0, curve: Curves.easeInOut),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _emailFocus.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      await authService.value.resetPasswordFromCurrentPassword(
        currentPassword: _currentPassController.text,
        newPassword: _newPassController.text,
        email: _emailController.text,
      );
      _showSnackbar('Password changed successfully', success: true);
      _newPassController.clear();
    } on FirebaseAuthException catch (e) {
      _showSnackbar(e.message ?? 'Password update failed', success: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        backgroundColor: success
            ? const Color(0xFF00D38C)
            : Theme.of(context).colorScheme.error,
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
          icon: Icon(Icons.arrow_back, color: Colors.white70),
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
                      'Change Password',
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
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.lock_outline,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeTransition(
                    opacity: _emailFade,
                    child: TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_currentFocus),
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter your email' : null,
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF191E1D),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _currentFade,
                    child: TextFormField(
                      controller: _currentPassController,
                      focusNode: _currentFocus,
                      style: const TextStyle(color: Colors.white),
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_newFocus),
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter current password' : null,
                      decoration: InputDecoration(
                        hintText: 'Current Password',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF191E1D),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _newFade,
                    child: TextFormField(
                      controller: _newPassController,
                      focusNode: _newFocus,
                      style: const TextStyle(color: Colors.white),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _changePassword(),
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter new password' : null,
                      decoration: InputDecoration(
                        hintText: 'New Password',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF191E1D),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FadeTransition(
                    opacity: _buttonFade,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D38C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
                        )
                            : Text(
                          'Change Password',
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
