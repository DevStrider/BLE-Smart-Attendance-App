import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';

class SessionRecord {
  final DateTime date;
  final String time;
  final String status;
  final String desc;
  SessionRecord({
    required this.date,
    required this.time,
    required this.status,
    required this.desc,
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

  // per‐course
  List<SessionRecord> _history = [];
  int attendanceCount = 0;
  int absenceCount = 0;
  int _warningLevel = 0;

  // all courses
  Map<String, int> _allWarnings = {};

  @override
  void initState() {
    super.initState();
    _loadAllWarnings();
    _loadAttendanceData();
  }

  /// Load warning levels across *all* courses for this student
  Future<void> _loadAllWarnings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final allAtt = await _dbService.read(path: 'students/$uid/attendance')
    as Map<String, dynamic>?;

    final warnings = <String,int>{};
    if (allAtt != null) {
      allAtt.forEach((course, datesMap) {
        if (datesMap is Map<String,dynamic>) {
          var absent = 0;
          datesMap.forEach((_, rec) {
            final m = rec as Map<String,dynamic>;
            if (m['status'] != 'attended') absent++;
          });
          int wl = 0;
          if      (absent == 2) wl = 1;
          else if (absent == 3) wl = 2;
          else if (absent >  3) wl = 3;
          if (wl > 0) warnings[course] = wl;
        }
      });
    }

    setState(() => _allWarnings = warnings);
  }

  /// Load only the *selected* course’s sessions up to TODAY
  Future<void> _loadAttendanceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final uid    = user.uid;
    final course = widget.selectedCourse;

    // entire course attendance tree: date → { uid → {status,…} }
    final attendanceData =
        await _dbService.read(path: 'attendance/$course') ?? {};

    // your sessions node: date → { time: "...", desc: "SessionDesc..." }
    final sessionsData =
        await _dbService.read(path: 'attendance/$course/sessions') ?? {};

    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int attended = 0, absent = 0;
    final List<SessionRecord> list = [];

    if (sessionsData is Map<String, dynamic>) {
      sessionsData.forEach((dateKey, info) {
        DateTime sessionDate;
        try {
          sessionDate = DateFormat('dd-MM-yyyy').parse(dateKey);
        } catch (_) {
          return; // skip bad keys
        }
        if (sessionDate.isAfter(today)) return;

        final infoMap = Map<String, dynamic>.from(info);
        final time    = infoMap['time'] as String? ?? '';
        final desc    = infoMap['desc'] as String? ??
            '${widget.selectedCourse} @ $dateKey';

        String status = 'absent';
        if (attendanceData[dateKey] is Map &&
            (attendanceData[dateKey] as Map).containsKey(uid)) {
          final rec = Map<String, dynamic>.from(
              (attendanceData[dateKey] as Map)[uid]);
          status = rec['status'] as String? ?? 'absent';
        }

        if (status == 'attended') attended++;
        else absent++;

        list.add(SessionRecord(
          date: sessionDate,
          time: time,
          status: status,
          desc: desc,
        ));
      });
    }

    // sort & cap to last 12
    list.sort((a, b) => a.date.compareTo(b.date));
    final history = list.length > 12 ? list.sublist(list.length - 12) : list;

    int wl = 0;
    if      (absent == 2) wl = 1;
    else if (absent == 3) wl = 2;
    else if (absent >  3) wl = 3;

    setState(() {
      _history        = history;
      attendanceCount = attended;
      absenceCount    = absent;
      _warningLevel   = wl;
      _loading        = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const totalSessions = 12;

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
              // ── Warnings for all courses ─────────────────────
              if (_allWarnings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _allWarnings.entries.map((e) {
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 6),
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '⚠️ ${e.key} Lv ${e.value}',
                            style: GoogleFonts.poppins(
                              color: Colors.orangeAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              // ── Header ───────────────────────────────────────
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
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
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

              // ── Selected course warning ────────────────────
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

              // ── Stats ───────────────────────────────────────
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

              // ── History ─────────────────────────────────────
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24.0),
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

              // ── Three-column table ──────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DataTable(
                    columnSpacing: 32,
                    columns: [
                      DataColumn(
                        label: Text('Attendance',
                            style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600)),
                      ),
                      DataColumn(
                        label: Text('Course',
                            style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600)),
                      ),
                      DataColumn(
                        label: Text('Date',
                            style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                    rows: _history.map((rec) {
                      final attended = rec.status == 'attended';
                      return DataRow(cells: [
                        DataCell(Text(
                          attended ? 'Attended' : 'Absent',
                          style: GoogleFonts.openSans(
                            color: attended
                                ? const Color(0xFF00D38C)
                                : const Color(0xFFFF5252),
                          ),
                        )),
                        DataCell(Container(
                          width: 300,
                          child: Text(
                            rec.desc,
                            style: GoogleFonts.openSans(
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                        DataCell(Text(
                          DateFormat('dd-MM-yyyy').format(rec.date),
                          style: GoogleFonts.openSans(
                              color: Colors.white70),
                        )),
                      ]);
                    }).toList(),
                  ),
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