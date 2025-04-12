import 'package:flutter/material.dart';
import 'HomePage.dart';

class RecordAttendancePage extends StatelessWidget {
  final String selectedCourse;
  const RecordAttendancePage({Key? key, required this.selectedCourse}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C130E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C130E),
        // Title removed for minimalism.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recorded Attendance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Card for attendance details with extra vertical space
            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  // Increased vertical spacing for a taller appearance.
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAttendanceRow('Course Name', selectedCourse),
                    const Divider(color: Colors.white24),
                    _buildAttendanceRow('Number of Attendance', '0'),
                    const Divider(color: Colors.white24),
                    _buildAttendanceRow('Number of Absence', '0'),
                    const Divider(color: Colors.white24),
                    _buildAttendanceRow('Date', '03/02/2025'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build a row that displays a label and its value.
  // The label is given a fixed width, and the value is allowed to wrap into multiple lines.
  Widget _buildAttendanceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
