import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';

class RecordAttendancePage extends StatefulWidget {
  final String selectedCourse;
  const RecordAttendancePage({Key? key, required this.selectedCourse}) : super(key: key);

  @override
  _RecordAttendancePageState createState() => _RecordAttendancePageState();
}

class _RecordAttendancePageState extends State<RecordAttendancePage>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  late AnimationController _animController;
  late Animation<double> _progressAnim;

  int attendanceCount = 0;
  int absenceCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnim = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.5, 0.8, curve: Curves.easeOut)),
    );
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final uid = user.uid;
    final path = 'attendance/${widget.selectedCourse}';
    final data = await _dbService.read(path: path);

    int attended = 0;
    int absent = 0;
    if (data != null) {
      data.forEach((date, records) {
        if (records is Map<String, dynamic> && records.containsKey(uid)) {
          final record = Map<String, dynamic>.from(records[uid]);
          final status = record['status'] as String? ?? '';
          if (status == 'attended') attended++;
          else if (status == 'absent') absent++;
        }
      });
    }

    final total = attended + absent;
    final rate = total > 0 ? attended / total : 0.0;

    setState(() {
      attendanceCount = attended;
      absenceCount = absent;
      _loading = false;
      _progressAnim = Tween<double>(begin: 0.0, end: rate).animate(
        CurvedAnimation(parent: _animController, curve: const Interval(0.5, 0.8, curve: Curves.easeOut)),
      );
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSessions = attendanceCount + absenceCount;

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
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attendance Overview',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.selectedCourse,
                            style: GoogleFonts.openSans(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Chart
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16.0),
                height: 180,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: AnimatedBuilder(
                          animation: _progressAnim,
                          builder: (context, child) => CircularProgressIndicator(
                            value: _progressAnim.value,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF00D38C)),
                            strokeWidth: 12,
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _progressAnim,
                        builder: (context, child) => Text(
                          '${(_progressAnim.value * 100).toInt()}%',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Info rows
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.book, 'Total Sessions', '$totalSessions'),
                    const Divider(color: Colors.white24),
                    _buildInfoRow(Icons.check_circle, 'Present', '$attendanceCount'),
                    const Divider(color: Colors.white24),
                    _buildInfoRow(Icons.cancel, 'Absent', '$absenceCount'),
                    const Divider(color: Colors.white24),
                    _buildInfoRow(
                      Icons.date_range,
                      'Date',
                      DateFormat('dd/MM/yyyy').format(DateTime.now()),
                    ),
                  ],
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.openSans(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.openSans(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
