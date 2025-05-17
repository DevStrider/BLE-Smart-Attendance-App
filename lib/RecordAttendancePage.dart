import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';

class SessionRecord {
  final DateTime date;
  final String status;    // 'attended' or 'absent'
  final String courseDesc;
  final String time;      // HH:mm:ss or empty
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
  int attendanceCount = 0;
  int absenceCount = 0;
  int _warningLevel = 0;
  Map<String, int> _allWarnings = {};
  DateTime? _lastAttendanceDate; // NEW: track the most recent attended date

  @override
  void initState() {
    super.initState();
    _loadAllWarnings();
    _loadAttendanceData();
  }

  /// 1) Build warning levels for *all* courses
  Future<void> _loadAllWarnings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final allAtt = await _dbService.read(path: 'students/$uid/attendance')
    as Map<String, dynamic>?;

    final warnings = <String, int>{};
    allAtt?.forEach((course, datesMap) {
      if (datesMap is Map<String, dynamic>) {
        var absCount = 0;
        datesMap.forEach((_, rec) {
          final m = rec as Map<String, dynamic>;
          final s = m['status'];
          if (!(s == true || s == 'attended')) absCount++;
        });
        var wl = 0;
        if (absCount == 2) wl = 1;
        else if (absCount == 3) wl = 2;
        else if (absCount > 3) wl = 3;
        if (wl > 0) warnings[course] = wl;
      }
    });

    setState(() => _allWarnings = warnings);
  }

  /// 2) Pull every date from account‐creation → today, merging in
  ///    ‘status’ & ‘time’ from students/$uid/attendance/<course>/<dateKey>
  Future<void> _loadAttendanceData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final uid = user.uid;
    final course = widget.selectedCourse;

    final attendanceData = await _dbService
        .read(path: 'students/$uid/attendance/$course')
    as Map<String, dynamic>? ?? {};

    final sessionsData = await _dbService
        .read(path: 'students/$uid/attendance/$course/sessions')
    as Map<String, dynamic>? ?? {};

    final created = user.metadata.creationTime ?? DateTime.now();
    var dt = DateTime(created.year, created.month, created.day);
    final todayDt = DateTime.now();
    final today = DateTime(todayDt.year, todayDt.month, todayDt.day);

    int attended = 0;
    final list = <SessionRecord>[];

    while (!dt.isAfter(today)) {
      final dateKey = DateFormat('dd-MM-yyyy').format(dt);

      String status = 'absent';
      String time = '';

      if (attendanceData[dateKey] is Map) {
        final rec = Map<String, dynamic>.from(attendanceData[dateKey]);
        final s = rec['status'];
        if (s == true || s == 'attended') {
          status = 'attended';
          attended++;
          time = rec['time']?.toString() ?? '';
        }
      }

      String courseDesc = course;
      if (sessionsData[dateKey] is Map<String, dynamic>) {
        final raw = sessionsData[dateKey]['desc'] as String?;
        if (raw != null) courseDesc = raw.split('@').first.trim();
      }

      list.add(SessionRecord(
        date: dt,
        status: status,
        courseDesc: courseDesc,
        time: time,
      ));

      dt = dt.add(const Duration(days: 1));
    }

    // NEW: find the most recent attended session
    DateTime? lastDate;
    if (attended > 0) {
      lastDate = list.lastWhere((r) => r.status == 'attended').date;
    }

    final totalDays = list.length;
    final absCount = totalDays - attended;
    var wl = 0;
    if (absCount == 2) wl = 1;
    else if (absCount == 3) wl = 2;
    else if (absCount > 3) wl = 3;

    setState(() {
      _history = list;
      attendanceCount = attended;
      absenceCount = absCount;
      _warningLevel = wl;
      _lastAttendanceDate = lastDate; // NEW
      _loading = false;
    });
  }

  /// 3) Remove a mistaken attendance
  Future<void> _deleteAttendance(SessionRecord rec) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final course = widget.selectedCourse;
    final dateKey = DateFormat('dd-MM-yyyy').format(rec.date);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Attendance?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Remove your attendance for $dateKey?',
          style: GoogleFonts.openSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.openSans()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.openSans(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbService.update(
        path: 'students/$uid/attendance/$course/$dateKey',
        data: {
          'status': false,
          'time': '00:00',
        },
      );
      await _loadAllWarnings();
      await _loadAttendanceData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance on $dateKey deleted')),
      );
    }
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
              if (_allWarnings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16),
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
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 8.0),
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
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.book, 'Total Sessions',
                        '$totalSessions'),
                    const Divider(color: Colors.white24),
                    _buildInfoRow(Icons.check_circle, 'Present',
                        '$attendanceCount'),
                    const Divider(color: Colors.white24),
                    _buildInfoRow(Icons.cancel, 'Absent',
                        '$absenceCount'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0),
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
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16),
                  child: DataTable(
                    columnSpacing: 24,
                    headingRowColor:
                    MaterialStateProperty.all(Colors.white12),
                    columns: [
                      DataColumn(
                        label: Text('Status',
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
                      DataColumn(
                        label: Text('Time',
                            style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600)),
                      ),
                      DataColumn(
                        label: Text('Action',
                            style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                    rows: _history.map((rec) {
                      final isAttended = rec.status == 'attended';
                      // NEW: only allow deletion of the most recent attended session
                      final isLastAttended =
                          isAttended && rec.date == _lastAttendanceDate;
                      return DataRow(cells: [
                        DataCell(Text(
                          isAttended ? 'Attended' : 'Absent',
                          style: GoogleFonts.openSans(
                            color: isAttended
                                ? const Color(0xFF00D38C)
                                : const Color(0xFFFF5252),
                          ),
                        )),
                        DataCell(Container(
                          width: 200,
                          child: Text(
                            rec.courseDesc,
                            style: GoogleFonts.openSans(
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                        DataCell(Text(
                          DateFormat('dd-MM-yyyy')
                              .format(rec.date),
                          style: GoogleFonts.openSans(
                              color: Colors.white70),
                        )),
                        DataCell(Text(
                          rec.time,
                          style: GoogleFonts.openSans(
                              color: Colors.white70),
                        )),
                        DataCell(
                          isLastAttended
                              ? IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () =>
                                _deleteAttendance(rec),
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

  Widget _buildInfoRow(
      IconData icon, String label, String value) =>
      Padding(
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