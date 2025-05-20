import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'ProfilePage.dart';
import 'TakeAttendancePage.dart';
import 'RecordAttendancePage.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic>? studentProfile;
  const HomePage({Key? key, this.studentProfile}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String? selectedCourse;

  final List<String> courses = [
    'Transmission & Switching (NETW601)', // slot 0: 08:00–09:00
    'Networks Lab (NETW602)',            // slot 1: 09:15–10:15
    'Intro to Management (MNGT601)',   // slot 2: 10:30–11:30
    'Network Protocols (NETW703)',       // slot 3: 11:45–12:45
    'Computer Architecture (NETW603)',     // slot 4: 13:00–14:00
    'Modeling & Simulation (NETW707)',   // slot 5: 14:15–15:15
    'Channel Coding (COMM604)',          // slot 6: 15:30–16:30
  ];

  late final AnimationController _ctrl;
  late final Animation<double> _greetAnim;
  late final Animation<double> _dropdownAnim;
  late final Animation<double> _buttonsAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _greetAnim = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.3));
    _dropdownAnim = CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.6));
    _buttonsAnim = CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1.0));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _showCoursePicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black54,
      barrierColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF000000), Color(0xFF004D43)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 8),
                Text('Select Course',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                ...courses.map((course) {
                  final isSelected = course == selectedCourse;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white10 : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? Colors.white60 : Colors.transparent),
                    ),
                    child: ListTile(
                      title: Text(course,
                          style: GoogleFonts.openSans(color: Colors.white, fontSize: 14)),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF00D38C)) : null,
                      onTap: () {
                        setState(() => selectedCourse = course);
                        Navigator.pop(context);
                      },
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isWithinCourseWindow() {
    if (selectedCourse == null) return false;
    final idx = courses.indexOf(selectedCourse!);
    if (idx < 0) return false;

    final now = DateTime.now();
    // Base 08:00 today
    final today = DateTime(now.year, now.month, now.day);
    final slotStart = today.add(Duration(
      hours: 8 + idx * 1 + idx * 0, // each slot adds 1h, gap handled below
      minutes: idx * 15,
    ));
    final slotEnd = slotStart.add(const Duration(hours: 1));

    return now.isAfter(slotStart) && now.isBefore(slotEnd);
  }

  void _onTakeAttendancePressed() {
    if (_isWithinCourseWindow()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TakeAttendancePage(selectedCourse: selectedCourse!),
        ),
      );
    } else {
      // compute human-readable window
      final idx = courses.indexOf(selectedCourse!);
      final today = DateTime.now();
      final base = DateTime(today.year, today.month, today.day, 8);
      final start = base.add(Duration(hours: idx * 1, minutes: idx * 15));
      final end = start.add(const Duration(hours: 1));
      final fmt = DateFormat.jm();
      final startStr = fmt.format(start);
      final endStr = fmt.format(end);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Outside Attendance Window', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
            'You can only take attendance for\n'
                '"$selectedCourse"\n'
                'between $startStr and $endStr.\n'
                'Please try again during that time.',
            style: GoogleFonts.openSans(),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('OK', style: GoogleFonts.openSans()),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.studentProfile?['name'] as String? ??
        FirebaseAuth.instance.currentUser?.displayName ??
        'Student';
    final studentId = widget.studentProfile?['studentId'] as String? ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF004D43), Color(0xFF046307)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _greetAnim,
                child: SlideTransition(
                  position: _greetAnim.drive(Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white24,
                          child: const Icon(Icons.person, size: 32, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Welcome, $name',
                                  style: GoogleFonts.poppins(fontSize: 26, color: Colors.white, fontWeight: FontWeight.w600)),
                              if (studentId.isNotEmpty)
                                Text('ID: $studentId',
                                    style: GoogleFonts.openSans(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white70),
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => const ProfilePage(),
                                transitionsBuilder: (_, anim, __, child) =>
                                    FadeTransition(opacity: anim, child: child),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _dropdownAnim,
                child: SlideTransition(
                  position: _dropdownAnim.drive(Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _showCoursePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: selectedCourse != null ? Colors.white54 : Colors.white24,
                          borderRadius: BorderRadius.circular(selectedCourse != null ? 24 : 16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.menu_book, color: Colors.white70),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedCourse ?? 'Select Course',
                                style: GoogleFonts.openSans(
                                    color: selectedCourse != null ? Colors.white : Colors.white70, fontSize: 16),
                              ),
                            ),
                            AnimatedRotation(
                              turns: selectedCourse != null ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              FadeTransition(
                opacity: _buttonsAnim,
                child: SlideTransition(
                  position: _buttonsAnim.drive(Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedCourse == null ? null : _onTakeAttendancePressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF046307),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              minimumSize: const Size(double.infinity, 140),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.qr_code_scanner, size: 32),
                                const SizedBox(height: 8),
                                Text('Scan to\nTake\nAttendance',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedCourse == null
                                ? null
                                : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RecordAttendancePage(selectedCourse: selectedCourse!),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF046307),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              minimumSize: const Size(double.infinity, 140),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.list_alt, size: 32),
                                const SizedBox(height: 8),
                                Text('Record\nAttendance',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}