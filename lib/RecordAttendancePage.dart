import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';

class SessionRecord {
  final String date;
  final String time;
  final String status;
  SessionRecord({
    required this.date,
    required this.time,
    required this.status,
  });
}

class RecordAttendancePage extends StatefulWidget {
  final String selectedCourse;
  const RecordAttendancePage({Key? key, required this.selectedCourse})
      : super(key: key);

  @override
  _RecordAttendancePageState createState() => _RecordAttendancePageState();
}

class _RecordAttendancePageState extends State<RecordAttendancePage> {
  final DatabaseService _dbService = DatabaseService();

  bool _loading = true;
  List<SessionRecord> _history = [];
  int _warningLevel = 0;
  int attendanceCount = 0;
  int absenceCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final uid = user.uid;
    final course = widget.selectedCourse;

    // read entire attendance tree
    final attendanceData =
        await _dbService.read(path: 'attendance/$course') ?? {};
    // read just the sessions entries
    final sessionsData =
        await _dbService.read(path: 'attendance/$course/sessions') ?? {};

    int attended = 0, absent = 0;
    final List<SessionRecord> list = [];

    if (sessionsData is Map<String, dynamic>) {
      sessionsData.forEach((dateKey, info) {
        // info is e.g. { "time": "14:05:23" }
        final infoMap = Map<String, dynamic>.from(info);
        final time = infoMap['time'] as String? ?? '';

        // look up this student's record under attendance/<course>/<dateKey>/<uid>
        String status = 'absent';
        if (attendanceData[dateKey] is Map &&
            (attendanceData[dateKey] as Map).containsKey(uid)) {
          final rec = Map<String, dynamic>.from(
              (attendanceData[dateKey] as Map)[uid]);
          status = rec['status'] as String? ?? 'absent';
        }

        if (status == 'attended') attended++;
        else absent++;

        list.add(SessionRecord(date: dateKey, time: time, status: status));
      });
    }

    // sort chronologically
    list.sort((a, b) => a.date.compareTo(b.date));
    // cap to last 12 sessions
    final history =
    list.length > 12 ? list.sublist(list.length - 12) : list;

    // compute warning level:
    // level 1 when absent == 2,
    // level 2 when absent == 3,
    // level 3 when absent > 3
    int wl = 0;
    if (absenceCount == 0) {
      wl = 0;
    }
    if (absent == 2) wl = 1;
    if (absent == 3) wl = 2;
    if (absent > 3) wl = 3;

    setState(() {
      attendanceCount = attended;
      absenceCount = absent;
      _warningLevel = wl;
      _history = history;
      _loading = false;
    });
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
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

              // WARNING LEVEL
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _warningLevel == 0
                      ? 'No Warnings'
                      : '⚠️ Warning Level $_warningLevel',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: _warningLevel == 0
                        ? const Color(0xFF00D38C)
                        : const Color(0xFFFF5252),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // STATS ROWS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    _buildInfoRow(
                        Icons.book, 'Total Sessions', '$totalSessions'),
                    const Divider(color: Colors.white24),
                    _buildInfoRow(Icons.check_circle, 'Present',
                        '$attendanceCount'),
                    const Divider(color: Colors.white24),
                    _buildInfoRow(
                        Icons.cancel, 'Absent', '$absenceCount'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // HISTORY HEADER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'History',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // HISTORY LIST
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: _history.length,
                  itemBuilder: (ctx, i) {
                    final s = _history[i];
                    final attended = s.status == 'attended';
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      decoration: BoxDecoration(
                        color: attended
                            ? Colors.transparent
                            : const Color(0xFFFF5252).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Icon(
                          attended
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: attended
                              ? const Color(0xFF00D38C)
                              : const Color(0xFFFF5252),
                        ),
                        title: Text(
                          '${s.date}  •  ${s.time}',
                          style: GoogleFonts.openSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          s.status[0].toUpperCase() +
                              s.status.substring(1),
                          style: GoogleFonts.openSans(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
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