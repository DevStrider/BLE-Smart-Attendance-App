// lib/ProfilePage.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'database_service.dart';
import 'WelcomePage.dart';
import 'UpdateUsernamePage.dart';
import 'ChangePasswordPage.dart';
import 'DeleteAccountPage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();

  late final AnimationController _animationController;
  late final Animation<double> _headerFade;
  late final Animation<double> _optionsFade;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _headerFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
    );
    _optionsFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.grey[900],
        title: Text('Confirm Logout', style: GoogleFonts.poppins(color: Colors.white)),
        content: Text(
          'Do you really want to logout?',
          style: GoogleFonts.openSans(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.openSans(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout', style: GoogleFonts.openSans(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await authService.value.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage()),
            (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<Map<String, dynamic>?>(
        // kick off the DB read but still build UI immediately
        future: _dbService.read(path: 'students/${user.uid}'),
        builder: (context, snapshot) {
          final data = snapshot.data;
          final name = data?['name'] as String? ?? user.displayName ?? '';
          final email = data?['email'] as String? ?? user.email ?? '';
          final studentId = data?['studentId'] as String? ?? '';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                expandedHeight: 250,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF004D43), Color(0xFF046307)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      FadeTransition(
                        opacity: _headerFade,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Hero(
                                  tag: 'profile-avatar',
                                  child: CircleAvatar(
                                    radius: 48,
                                    backgroundColor: Colors.white24,
                                    child: Text(
                                      name.isNotEmpty ? name[0] : 'U',
                                      style: GoogleFonts.poppins(
                                        fontSize: 40,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  email,
                                  style: GoogleFonts.openSans(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                // Smooth appearance of ID when it becomes available
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 400),
                                  transitionBuilder: (child, anim) =>
                                      FadeTransition(opacity: anim, child: child),
                                  child: studentId.isNotEmpty
                                      ? Padding(
                                    key: ValueKey(studentId),
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'ID: $studentId',
                                      style: GoogleFonts.openSans(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                      : const SizedBox.shrink(
                                      key: ValueKey('empty')),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _optionsFade,
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Column(
                      children: [
                        _buildCardOption(
                          icon: Icons.edit,
                          text: 'Update Username',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const UpdateUsernamePage()),
                            );
                            // rebuild so FutureBuilder fires again
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildCardOption(
                          icon: Icons.lock_outline,
                          text: 'Change Password',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ChangePasswordPage()),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildCardOption(
                          icon: Icons.delete_outline,
                          text: 'Delete Account',
                          iconColor: Colors.redAccent,
                          textColor: Colors.redAccent,
                          onTap: () async {
                            final didDelete = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DeleteAccountPage()),
                            );
                            if (didDelete == true) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const WelcomePage()),
                                    (_) => false,
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _confirmLogout,
                          icon: const Icon(Icons.logout),
                          label: Text(
                            'Logout',
                            style: GoogleFonts.openSans(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCardOption({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    Color iconColor = Colors.white,
    Color textColor = Colors.white,
  }) {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: iconColor),
        title: Text(
          text,
          style: GoogleFonts.openSans(color: textColor, fontSize: 16),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      ),
    );
  }
}
