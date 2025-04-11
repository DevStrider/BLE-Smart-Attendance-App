import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'HomePage.dart';
import 'WelcomePage.dart';
import 'auth_service.dart';
import 'DeleteAccountPage.dart';
import 'UpdateUsernamePage.dart';
import 'ChangePasswordPage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<bool?> _showLogoutDialog() {
    final Color darkEmerald = const Color(0xFF014421);
    final Color logoutButtonColor = const Color(0xFF00D38C);

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: darkEmerald,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          content: const Text(
            'Are you sure you want to log out?',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          actions: [
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: 100),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: darkEmerald,
                  foregroundColor: logoutButtonColor,
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: 100),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: logoutButtonColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Logout'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> logout() async {
    final confirmed = await _showLogoutDialog();
    if (confirmed != true) return;

    try {
      await authService.value.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomePage()),
      );
    } on FirebaseAuthException catch (e) {
      print(e.message);
    }
  }

  Widget _buildSettingsItem({required String title, VoidCallback? onTap}) {
    return Container(
      constraints: BoxConstraints(minHeight: 50),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String fullName = currentUser?.displayName ?? 'Your Name';
    final String email = currentUser?.email ?? 'your.email@example.com';

    return Scaffold(
      backgroundColor: const Color(0xFF0C130E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C130E),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              Container(
                constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1C12),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _buildSettingsItem(
                title: 'Update username',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const UpdateUsernamePage()),
                  );
                },
              ),
              _buildSettingsItem(
                title: 'Change password',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ChangePasswordPage()),
                  );
                },
              ),
              _buildSettingsItem(
                title: 'Delete my account',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DeleteAccountPage()),
                  );
                },
              ),
              const SizedBox(height: 20),
              ListTile(
                onTap: logout,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.redAccent.shade200,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.logout, color: Colors.redAccent),
              ),
              const SizedBox(height: 20), // Extra bottom padding
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 60,
        child: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          currentIndex: 1,
          selectedItemColor: const Color(0xFF00D38C),
          unselectedItemColor: Colors.grey,
          backgroundColor: const Color(0xFF0C130E),
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            }
          },
        ),
      ),
    );
  }
}