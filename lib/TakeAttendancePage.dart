import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'database_service.dart';

class TakeAttendancePage extends StatefulWidget {
  final String selectedCourse;
  const TakeAttendancePage({Key? key, required this.selectedCourse})
      : super(key: key);

  @override
  _TakeAttendancePageState createState() => _TakeAttendancePageState();
}

class _TakeAttendancePageState extends State<TakeAttendancePage>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();

  bool _isScanning = false;
  bool _found = false;
  ScanResult? _result;
  StreamSubscription<List<ScanResult>>? _scanSub;
  final Map<String, DeviceBlip> _blips = {};
  Set<String> _allowedMacs = {};

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // New variables for connection tracking
  DateTime? _connectionStartTime;
  Timer? _connectionTimer;
  bool _isConnected = false;
  bool _attendanceMarked = false;
  int _remainingSeconds = 120;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _loadBeacons().then((_) {
      _markMissedAbsent().then((_) {
        _requestPermissions().then((_) => _startScan());
      });
    });
  }

  Future<void> _loadBeacons() async {
    final data = await _db.read(path: 'beacons');
    if (data == null) return;
    final allowed = <String>{};
    data.forEach((_, def) {
      final courses = List<String>.from(def['courses']);
      final mac = (def['mac'] as String).toUpperCase();
      if (courses.contains(widget.selectedCourse)) {
        allowed.add(mac);
      }
    });
    setState(() => _allowedMacs = allowed);
  }

  Future<void> _markMissedAbsent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final snapshot = await _db.read(
        path: 'students/$uid/attendance/${widget.selectedCourse}'
    );
    if (snapshot == null) return;

    final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
    snapshot.forEach((dateKey, val) {
      if (dateKey.compareTo(today) < 0) {
        final entry = val as Map;
        if (!entry.containsKey('status')) {
          _db.update(
            path: 'students/$uid/attendance/${widget.selectedCourse}/$dateKey',
            data: {'status': 'absent'},
          );
        }
      }
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();
  }

  Future<void> _startScan() async {
    if (_allowedMacs.isEmpty) {
      _showNoBeaconDialog();
      return;
    }

    setState(() {
      _isScanning = true;
      _found = false;
      _isConnected = false;
      _attendanceMarked = false;
      _connectionStartTime = null;
      _remainingSeconds = 120;
      _blips.clear();
    });

    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (var r in results) {
        final id = r.device.id.toString().toUpperCase();
        if (!_blips.containsKey(id)) {
          final rng = Random(id.hashCode);
          final angle = rng.nextDouble() * 2 * pi;
          final dist = pow(10, (-59 - r.rssi) / 20).toDouble();
          final norm = (dist > 10.0) ? 1.0 : dist / 10.0;
          _blips[id] = DeviceBlip(angle, norm);
        }

        if (_allowedMacs.contains(id)) {
          if (!_isConnected) {
            // First time connecting to this beacon
            setState(() {
              _isConnected = true;
              _found = true;
              _result = r;
              _connectionStartTime = DateTime.now();
            });

            // Start the 2-minute countdown
            _connectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (mounted) {
                setState(() {
                  _remainingSeconds = 120 - timer.tick;
                });

                if (_remainingSeconds <= 0) {
                  timer.cancel();
                  _writeAttendance(r);
                  setState(() => _attendanceMarked = true);
                  _showResultDialog();
                }
              }
            });
          }
          break;
        }
      }
      setState(() {});
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));
  }

  void _stopScan() {
    _connectionTimer?.cancel();
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    setState(() {
      _isScanning = false;
      _isConnected = false;
      _connectionStartTime = null;
    });
  }

  Future<void> _writeAttendance(ScanResult r) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final now = DateTime.now();
    final dateKey = DateFormat('dd-MM-yyyy').format(now);
    final timeKey = DateFormat('hh:mm:ss a').format(now); // Add time formatting
    final ms = now.millisecondsSinceEpoch;
    final dist = pow(10, (-59 - r.rssi) / 20).toDouble();

    await _db.update(
      path: 'students/$uid/attendance/${widget.selectedCourse}/$dateKey',
      data: {
        'status': dist <= 2.0 ? 'attended' : 'absent',
        'timestamp': ms,
        'time': timeKey, // Add time field
        'connection_duration': 120 - _remainingSeconds,
      },
    );
  }

  void _showNoBeaconDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('No Beacon Configured',
            style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold)),
        content: Text(
          'No beacons are associated with "${widget.selectedCourse}".',
          style: GoogleFonts.openSans(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK',
                style: GoogleFonts.openSans(color: AppColors.beam)),
          ),
        ],
      ),
    );
  }

  void _showResultDialog() {
    final r = _result!;
    final dist = pow(10, (-59 - r.rssi) / 20).toStringAsFixed(2);
    final time = DateFormat('hh:mm:ss a').format(DateTime.now());
    final duration = _connectionStartTime != null
        ? DateTime.now().difference(_connectionStartTime!).inSeconds
        : 0;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Attendance Details',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, a1, a2) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            width: MediaQuery.of(ctx).size.width * 0.8,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _attendanceMarked ? 'Attendance Recorded!' : 'Connected to Beacon',
                  style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 16),
                _row('Course', widget.selectedCourse),
                _row('Device', r.device.id.toString()),
                _row('Signal', '${r.rssi} dBm'),
                _row('Distance', '$dist m'),
                _row('Connected Time', '$duration seconds'),
                if (!_attendanceMarked) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 1 - (_remainingSeconds / 120),
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(AppColors.beam),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Remaining: $_remainingSeconds seconds',
                    style: GoogleFonts.openSans(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _stopScan();
                    _startScan();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.beam,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    _attendanceMarked ? 'Scan Again' : 'Cancel',
                    style: GoogleFonts.openSans(
                        color: Colors.black,
                        fontSize: 16
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(
        opacity: a1,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: a1, curve: Curves.easeOutBack),
          child: child,
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text('$label:',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(value,
                style: const TextStyle(color: AppColors.textPrimary))),
      ],
    ),
  );

  @override
  void dispose() {
    _scanSub?.cancel();
    _connectionTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width * 0.8;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundStart,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Take Attendance',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.backgroundStart, AppColors.backgroundEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.beam.withOpacity(0.3),
                    ),
                    child: Center(
                      child: Icon(
                        _attendanceMarked
                            ? Icons.check_circle
                            : _isConnected
                            ? Icons.bluetooth_connected
                            : Icons.wifi_tethering,
                        size: 60,
                        color: _attendanceMarked
                            ? AppColors.beam
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _attendanceMarked
                    ? 'Attendance Recorded!'
                    : _isConnected
                    ? 'Connected to Beacon...'
                    : 'Scanning for Beacons...',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 20),
              ),
              if (_isConnected && !_attendanceMarked) ...[
                const SizedBox(height: 8),
                Text(
                  'Please stay connected for 2 minutes',
                  style: GoogleFonts.openSans(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    value: 1 - (_remainingSeconds / 120),
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(AppColors.beam),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_remainingSeconds seconds remaining',
                  style: GoogleFonts.openSans(color: Colors.white70),
                ),
              ],
              const SizedBox(height: 24),
              if (!_found)
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _blips.entries.map((e) {
                      final percent = (1 - e.value.distNorm).clamp(0.0, 1.0);
                      return Container(
                        width: w * 0.4,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(e.key.substring(e.key.length - 5),
                                style: const TextStyle(color: Colors.white)),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: percent,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation(
                                  AppColors.beam),
                            ),
                            const SizedBox(height: 4),
                            Text('${(percent * 100).toInt()}%',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? _stopScan : _startScan,
                  icon: Icon(_isScanning ? Icons.stop : Icons.search),
                  label: Text(
                      _isScanning ? 'Stop Scanning' : 'Start Scan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.card,
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceBlip {
  final double angle;
  final double distNorm;
  DeviceBlip(this.angle, this.distNorm);
}

class AppColors {
  static const backgroundStart = Color(0xFF004D43);
  static const backgroundEnd = Color(0xFF046307);
  static const card = Color(0xFF1E1E1E);
  static const beam = Color(0xFF00D38C);
  static const textPrimary = Colors.white;
  static const textSecondary = Colors.white70;
}