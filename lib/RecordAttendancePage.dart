import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';

class SessionRecord {
  final DateTime date;
  final String status;    // 'attended' or 'absent'
  final String courseDesc;
  final String time;
  SessionRecord({
    required this.date,
    required this.status,
    required this.courseDesc,
    required this.time,
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
  int _presentCount = 0;
  int _absentCount = 0;
  int _warningLevel = 0;
  Map<String, int> _allWarnings = {};

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  Future<void> _reloadAll() async {
    setState(() => _loading = true);
    await _loadAllWarnings();
    await _loadAttendanceData();
    setState(() => _loading = false);
  }

  /// 1) Build warning levels for *all* courses
  Future<void> _loadAllWarnings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final allAtt = await _dbService
        .read(path: 'students/$uid/attendance') as Map<String, dynamic>?;

    final warnings = <String, int>{};
    allAtt?.forEach((course, datesMap) {
      if (datesMap is Map<String, dynamic>) {
        var absCount = 0;
        datesMap.forEach((_, rec) {
          // rec['status'] might be `true` or the string 'absent'
          final status = rec['status'];
          if (status != true) absCount++;
        });
        int wl = 0;
        if      (absCount == 2) wl = 1;
        else if (absCount == 3) wl = 2;
        else if (absCount >  3) wl = 3;
        if (wl > 0) warnings[course] = wl;
      }
    });

    setState(() => _allWarnings = warnings);
  }

  /// 2) Load this course’s attendance from account‐creation → today
  Future<void> _loadAttendanceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid    = user.uid;
    final course = widget.selectedCourse;

    // **FIX**: read under students/$uid/attendance/<course>
    final attendanceData = await _dbService
        .read(path: 'students/$uid/attendance/$course')
    as Map<String, dynamic>? ?? {};

    // Determine range: account‐creation → today
    final created = user.metadata.creationTime ?? DateTime.now();
    final startDate = DateTime(created.year, created.month, created.day);
    final today = DateTime.now();

    int present = 0;
    final List<SessionRecord> rows = [];

    for (var dt = startDate;
    !dt.isAfter(today);
    dt = dt.add(const Duration(days: 1))) {
      final key = DateFormat('dd-MM-yyyy').format(dt);

      final recMap = attendanceData[key] as Map<String, dynamic>?;

      // Interpret status:
      final bool didAttend = recMap != null && recMap['status'] == true;
      final status = didAttend ? 'attended' : 'absent';
      final time   = didAttend ? (recMap!['time'] as String? ?? '') : '';

      if (didAttend) present++;

      // (You can extend this to pull per-session descriptions if you store them.)
      final courseDesc = course;

      rows.add(SessionRecord(
        date: dt,
        status: status,
        courseDesc: courseDesc,
        time: time,
      ));
    }

    final totalDays  = rows.length;
    final absentDays = totalDays - present;
    int wl = 0;
    if      (absentDays == 2) wl = 1;
    else if (absentDays == 3) wl = 2;
    else if (absentDays >  3) wl = 3;

    setState(() {
      _history       = rows;
      _presentCount  = present;
      _absentCount   = absentDays;
      _warningLevel  = wl;
    });
  }

  Future<void> _confirmAndDelete(DateTime date) async {
    final key = DateFormat('dd-MM-yyyy').format(date);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Attendance?', style: GoogleFonts.poppins()),
        content: Text('Remove your ✔️ for $key?', style: GoogleFonts.openSans()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),  child: Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final uid   = user.uid;
      final course = widget.selectedCourse;

      // **DELETE** that date entry
      await _dbService.delete(path: 'students/$uid/attendance/$course/$key');

      // reload everything
      await _reloadAll();

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted attendance for $key'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const totalSessions = 12;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF004D43),
        title: Text('Record Attendance', style: GoogleFonts.poppins()),
        leading: BackButton(color: Colors.white),
      ),
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
              // ── All‐courses warnings ────────────────────
              if (_allWarnings.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _allWarnings.entries.map((e) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('⚠️ ${e.key} Lv ${e.value}',
                            style: GoogleFonts.poppins(color: Colors.orangeAccent)),
                      );
                    }).toList(),
                  ),
                ),

              // ── Header ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Attendance Overview',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(widget.selectedCourse,
                        style: GoogleFonts.openSans(color: Colors.white70)),
                  ],
                ),
              ),

              // ── Selected‐course warning ────────────────
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
                    fontSize: 20,
                  ),
                ),
              ),

              // ── Stats ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    _infoRow(Icons.book, 'Total Sessions', '$totalSessions'),
                    const Divider(color: Colors.white24),
                    _infoRow(Icons.check_circle, 'Present', '$_presentCount'),
                    const Divider(color: Colors.white24),
                    _infoRow(Icons.cancel, 'Absent', '$_absentCount'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── History table ─────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text('History',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 18)),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DataTable(
                    columnSpacing: 20,
                    headingRowColor: MaterialStateProperty.all(Colors.white12),
                    columns: const [
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Course')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Time')),
                      DataColumn(label: Text('')),  // for delete icon
                    ],
                    rows: _history.map((rec) {
                      final didAttend = rec.status == 'attended';
                      return DataRow(cells: [
                        DataCell(Text(
                          didAttend ? 'Attended' : 'Absent',
                          style: GoogleFonts.openSans(
                            color: didAttend
                                ? const Color(0xFF00D38C)
                                : const Color(0xFFFF5252),
                          ),
                        )),
                        DataCell(SizedBox(
                          width: 200,
                          child: Text(rec.courseDesc,
                            style: GoogleFonts.openSans(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                        DataCell(Text(
                          DateFormat('dd-MM-yyyy').format(rec.date),
                          style: GoogleFonts.openSans(color: Colors.white70),
                        )),
                        DataCell(Text(
                          rec.time,
                          style: GoogleFonts.openSans(color: Colors.white70),
                        )),
                        DataCell(
                          didAttend
                              ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => _confirmAndDelete(rec.date),
                          )
                              : const SizedBox.shrink(),
                        ),
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: GoogleFonts.openSans(color: Colors.white, fontSize: 16)),
          ),
          Text(value,
              style: GoogleFonts.openSans(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }
}