import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ProfilePage.dart';
import 'BLE_Utility.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C130E),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? selectedCourse;
  final List<String> courses = [
    'Transmission and Switching (NETW601)',
    'Computer System Architecture (NETW603)',
    'Network Protocols (NETW703)',
    'Introduction to Management (MNGT601)',
    'Modelling and Simulation (NETW707)',
    'Channel Coding (COMM604)',
  ];

  @override
  Widget build(BuildContext context) {
    // Get the current user’s display name; default to 'Student' if not available.
    final String welcomeName = FirebaseAuth.instance.currentUser?.displayName ?? 'Student';

    return Scaffold(
      backgroundColor: const Color(0xFF0C130E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C130E),
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Updated header text using the user's first name.
          Text(
            'Welcome $welcomeName',
            style: GoogleFonts.roboto(
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF191E1D),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Select Course',
                labelStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.school, color: Colors.white54),
              ),
              value: selectedCourse,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
              items: courses.map((String course) {
                return DropdownMenuItem<String>(
                  value: course,
                  child: Text(course),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedCourse = newValue;
                });
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: selectedCourse == null
                      ? null
                      : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BLEScannerScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D38C),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text(
                    'Take Attendance',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: selectedCourse == null
                      ? null
                      : () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D38C),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text(
                    'Record Attendance',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
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
        currentIndex: 0,
        selectedItemColor: const Color(0xFF00D38C),
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF0C130E),
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfilePage(),
              ),
            );
          }
        },
      ),
    );
  }
}