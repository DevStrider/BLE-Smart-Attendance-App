import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'HomePage.dart';
import 'ResetPasswordPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  // Controllers & focus nodes
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  // State
  String errorMessage = '';
  bool isLoading = false;
  bool _visible = false;
  bool _obscurePassword = true;

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
    emailController.dispose();
    passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// Same slide-&-fade transition used on WelcomePage
  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnim = Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        final fadeAnim = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeIn),
        );
        return SlideTransition(
          position: slideAnim,
          child: FadeTransition(opacity: fadeAnim, child: child),
        );
      },
    );
  }

  Future<void> signIn() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      setState(() {
        errorMessage = 'Please enter both email and password';
      });
      return;
    }
    setState(() {
      errorMessage = '';
      isLoading = true;
    });
    try {
      await authService.value.signIn(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      // replace with animated transition
      Navigator.of(context).pushReplacement(_createRoute(const HomePage()));
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message ?? 'An error occurred during sign in';
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gradient background
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
                  left: 24,
                  right: 24,
                ),
                child: ConstrainedBox(
                  constraints:
                  BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Back arrow
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white70,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Icon
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.login,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Title
                        Text(
                          'Sign In',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          'Welcome back!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.openSans(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Email field
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => FocusScope.of(context)
                              .requestFocus(_passwordFocusNode),
                          decoration: InputDecoration(
                            hintText: 'Email',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white24,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Password with toggle
                        TextField(
                          controller: passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => signIn(),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white24,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white54,
                              ),
                              onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Error message
                        if (errorMessage.isNotEmpty)
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              errorMessage,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context)
                                .push(_createRoute(const ResetPasswordPage())),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.openSans(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Sign In button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF046307),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding:
                              const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: isLoading
                                ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                AlwaysStoppedAnimation<Color>(
                                    const Color(0xFF046307)),
                              ),
                            )
                                : Text(
                              'Sign In',
                              style: GoogleFonts.openSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
          ),
        ),
      ),
    );
  }
}