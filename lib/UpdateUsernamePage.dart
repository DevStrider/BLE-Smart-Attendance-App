import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';

class UpdateUsernamePage extends StatefulWidget {
  final String? email;

  const UpdateUsernamePage({super.key, this.email});

  @override
  _UpdateUsernamePage createState() => _UpdateUsernamePage();
}

class _UpdateUsernamePage extends State<UpdateUsernamePage> {
  final TextEditingController usernameController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String errorMessage = '';

  @override
  void dispose() {
    usernameController.dispose();
    super.dispose();
  }

  void updateUsername() async {
    try {
      await authService.value.updateUsername(username: usernameController.text);
      showSnackBarSuccess();
    } on FirebaseAuthException catch (e) {
      showSnackBarFailure(e.message ?? "Username update failed");
    }
  }

  void showSnackBarSuccess() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        content: Text(
          "Username updated successfully",
          style: GoogleFonts.roboto(textStyle: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  void showSnackBarFailure(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: GoogleFonts.roboto(textStyle: const TextStyle(fontSize: 16)),
        ),
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
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        // Header text
                        Text(
                          'Update Username',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Icon
                        Text(
                          '✏️',
                          style: TextStyle(
                            fontSize: 50,
                            color: Colors.yellow.shade600,
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Username TextField
                        TextFormField(
                          controller: usernameController,
                          style: const TextStyle(color: Colors.white),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your Username';
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
                        const SizedBox(height: 20),
                        const Spacer(),
                        // Update Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState?.validate() ?? false) {
                                updateUsername();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00D38C),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Update username',
                              style: TextStyle(
                                  color: Colors.black, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
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