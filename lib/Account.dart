import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Profile UI',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF0C130E),
        scaffoldBackgroundColor: const Color(0xFF0C130E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0C130E),
          elevation: 0,
        ),
      ),
      home: const MyProfilePage(),
    );
  }
}

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  int _currentIndex = 1; // Suppose 'My Profile' is index 1 in bottom nav

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            // Profile Card: Avatar + Name + Email
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D1C12),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                children: [
                  // Avatar or emoji
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    alignment: Alignment.center,
                    child: const Text('😎', style: TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 16),
                  // Name and Email
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Abdulrahman Mansour',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'abdulrahman.mansour',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Settings List
            _buildSettingsItem(
              title: 'Update username',
              onTap: () {
                // Handle tap
              },
            ),
            _buildSettingsItem(
              title: 'Change password',
              onTap: () {
                // Handle tap
              },
            ),
            _buildSettingsItem(
              title: 'Delete my account',
              onTap: () {
                // Handle tap
              },
            ),
            const SizedBox(height: 20),
            // Logout
            ListTile(
              onTap: () {
                // Handle logout
              },
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
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF0D1C12),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Navigate to pages accordingly
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'My Profile',
          ),
          // Add more items if needed
        ],
      ),
    );
  }

  Widget _buildSettingsItem({required String title, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
