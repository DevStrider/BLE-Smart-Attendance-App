import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ProfilePage.dart';
import 'RecordAttendancePage.dart';
import 'TakeAttendancePage.dart';

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
    final String welcomeName = FirebaseAuth.instance.currentUser?.displayName ?? 'Student';

    return Scaffold(
      backgroundColor: const Color(0xFF0C130E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C130E),
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Welcome text
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

                  // Dropdown button
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      dropdownColor: const Color(0xFF191E1D),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
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
                          child: Text(
                            course,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedCourse = newValue;
                        });
                      },
                      menuMaxHeight: 300,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Row with buttons placed side by side using Expanded widgets
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selectedCourse == null
                              ? null
                              : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TakeAttendancePage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D38C),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          ),
                          child: const Text(
                            'Take Attendance',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: selectedCourse == null
                              ? null
                              : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecordAttendancePage(
                                  selectedCourse: selectedCourse!,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D38C),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          ),
                          child: const Text(
                            'Record Attendance',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
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
        backgroundColor: const Color(0xFF1E1E1E),
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
