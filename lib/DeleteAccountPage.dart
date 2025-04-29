import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'WelcomePage.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({Key? key, this.email}) : super(key: key);
  final String? email;

  @override
  _DeleteAccountPageState createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  late final AnimationController _animController;
  late final Animation<double> _headerFade;
  late final Animation<double> _iconScale;
  late final Animation<double> _emailFade;
  late final Animation<double> _passwordFade;
  late final Animation<double> _buttonFade;

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.email != null) _emailController.text = widget.email!;

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
    _passwordFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.55, 0.75, curve: Curves.easeIn),
    );
    _buttonFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.75, 1.0, curve: Curves.easeInOut),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<bool?> _confirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.red[700],
        title: Text(
          'Confirm Deletion',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Text(
          'This will permanently delete your account.',
          style: GoogleFonts.openSans(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.openSans(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.openSans(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final confirmed = await _confirmDialog();
    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      await authService.value.deleteAccount(
        email: _emailController.text,
        password: _passwordController.text,
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      'Delete Account',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ScaleTransition(
                    scale: _iconScale,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.delete_outline,
                          size: 40, color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(height: 40),
                  FadeTransition(
                    opacity: _emailFade,
                    child: TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_passwordFocus),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Enter your email'
                          : null,
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF191E1D),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _passwordFade,
                    child: TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      style: const TextStyle(color: Colors.white),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _deleteAccount(),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Enter your password'
                          : null,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF191E1D),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.openSans(
                            color: Colors.redAccent, fontSize: 14),
                      ),
                    ),
                  const Spacer(),
                  FadeTransition(
                    opacity: _buttonFade,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _deleteAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              valueColor:
                              AlwaysStoppedAnimation<Color>(
                                  Colors.white)),
                        )
                            : Text(
                          'Delete Account',
                          style: GoogleFonts.openSans(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
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