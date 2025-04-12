import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'HomePage.dart';
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String errorMessage = '';
  bool isLoading = false;
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void signIn() async {
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
        email: emailController.text,
        password: passwordController.text,
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message ?? 'An error occurred during sign in';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        'Login',
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
                        '🔑',
                        style: TextStyle(
                          fontSize: 50,
                          color: Colors.yellow.shade600,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Email TextField
                      TextField(
                        controller: emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Email',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF191E1D),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_passwordFocusNode);
                        },
                      ),
                      const SizedBox(height: 20),
                      // Password TextField
                      TextField(
                        controller: passwordController,
                        focusNode: _passwordFocusNode,
                        style: const TextStyle(color: Colors.white),
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF191E1D),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => signIn(),
                      ),
                      const SizedBox(height: 10),
                      // Error message
                      if (errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            errorMessage,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      // Reset Password Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // Add navigation to reset password page
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF00D38C),
                          ),
                          child: const Text('Forgot Password?'),
                        ),
                      ),
                      const Spacer(),
                      // Login button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D38C),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: isLoading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black),
                            ),
                          )
                              : const Text(
                            'Sign in',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}