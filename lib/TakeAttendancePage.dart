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

  DateTime? _connectionStartTime;
  Timer? _connectionTimer;
  bool _isConnected = false;
  bool _attendanceMarked = false;
  int _remainingSeconds = 120;

  static const double _maxDistanceMeters = 2.0; // only within 2 m

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
      _markMissedAbsent();
      _requestPermissions().then((_) => _startScan());
    });
  }

  String _onlyCode(String full) {
    final match = RegExp(r"\b[A-Z]{4}\d{3}\b").firstMatch(full);
    return match != null ? match.group(0)!.toLowerCase() : full.toLowerCase();
  }

  String _normalizeMac(String mac) =>
      mac.toUpperCase().replaceAll('-', ':').trim();

  Future<void> _loadBeacons() async {
    final data = await _db.read(path: 'beacons');
    if (data == null) return;
    final selectedCode = _onlyCode(widget.selectedCourse);
    final allowed = <String>{};
    data.forEach((key, def) {
      final mac = _normalizeMac(def['mac'] as String? ?? '');
      final courses = (def['courses'] as List).cast<String>();
      for (var c in courses) {
        if (_onlyCode(c) == selectedCode) {
          allowed.add(mac);
          break;
        }
      }
    });
    setState(() => _allowedMacs = allowed);
  }

  Future<void> _markMissedAbsent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final snapshot = await _db.read(
      path: 'students/$uid/attendance/${widget.selectedCourse}',
    );
    if (snapshot == null) return;
    final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
    snapshot.forEach((dateKey, val) {
      if (dateKey.compareTo(today) < 0) {
        final entry = val as Map;
        if (!entry.containsKey('status')) {
          _db.update(
            path:
            'students/$uid/attendance/${widget.selectedCourse}/$dateKey',
            data: {'status': false},
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
      _remainingSeconds = 120;
      _connectionStartTime = null;
      _blips.clear();
    });

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      bool beaconInRange = false;
      ScanResult? current;

      for (var r in results) {
        final id = _normalizeMac(r.device.id.toString());

        // estimate distance from RSSI
        final dist = pow(10, (-59 - r.rssi) / 20).toDouble();

        // keep the little radar‐blip positions
        if (!_blips.containsKey(id)) {
          final rng = Random(id.hashCode);
          final angle = rng.nextDouble() * 2 * pi;
          final norm = (dist > 10.0) ? 1.0 : dist / 10.0;
          _blips[id] = DeviceBlip(angle, norm);
        }

        // only treat as “in range” if it's an allowed MAC AND ≤ 2 m
        if (_allowedMacs.contains(id) && dist <= _maxDistanceMeters) {
          beaconInRange = true;
          current = r;
          break;
        }
      }

      if (beaconInRange && current != null && !_attendanceMarked) {
        if (!_isConnected) {
          setState(() {
            _isConnected = true;
            _found = true;
            _result = current;
            _connectionStartTime = DateTime.now();
          });
          _startConnectionTimer();
        } else {
          // keep updating the result so RSSI/time stay current
          _result = current;
        }
      } else if (_isConnected && !_attendanceMarked) {
        // lost valid connection or out of range → reset
        _connectionTimer?.cancel();
        setState(() {
          _isConnected = false;
          _remainingSeconds = 120;
          _connectionStartTime = null;
        });
      }

      setState(() {});
    });

    await FlutterBluePlus.startScan();
  }

  void _startConnectionTimer() {
    _connectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final rem = 120 - timer.tick;
      if (!mounted) return;
      setState(() => _remainingSeconds = rem.clamp(0, 120));
      if (rem <= 0) {
        timer.cancel();
        _writeAttendance(_result!);
        setState(() => _attendanceMarked = true);
        _showResultDialog();
      }
    });
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
    final timeKey = DateFormat('HH:mm:ss').format(now);
    await _db.update(
      path: 'students/$uid/attendance/${widget.selectedCourse}/$dateKey',
      data: {
        'status': true,
        'time': timeKey,
      },
    );
  }

  Future<void> _deleteAttendance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final now = DateTime.now();
    final dateKey = DateFormat('dd-MM-yyyy').format(now);
    await _db.update(
      path: 'students/$uid/attendance/${widget.selectedCourse}/$dateKey',
      data: {
        'status': false,
        'time': '00:00',
      },
    );
    setState(() => _attendanceMarked = false);
  }

  void _showNoBeaconDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('No Beacon Configured',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'No beacons are associated with "${widget.selectedCourse}".',
          style: GoogleFonts.openSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: GoogleFonts.openSans()),
          ),
        ],
      ),
    );
  }

  void _showResultDialog() {
    final r = _result!;
    final dist = pow(10, (-59 - r.rssi) / 20).toStringAsFixed(2);
    final duration = _connectionStartTime != null
        ? DateTime.now().difference(_connectionStartTime!).inSeconds
        : 0;
    final nowTime = DateFormat('HH:mm:ss').format(DateTime.now());

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
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _attendanceMarked
                      ? 'Attendance Recorded!'
                      : 'Connected to Beacon',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _row('Course', widget.selectedCourse),
                _row('Device', r.device.id.toString()),
                _row('Signal', '${r.rssi} dBm'),
                _row('Distance', '$dist m'),
                _row('Connected Time', '$duration seconds'),
                _row('Marked At', nowTime),
                if (!_attendanceMarked) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 1 - (_remainingSeconds / 120),
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(Colors.tealAccent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Remaining: $_remainingSeconds seconds',
                    style: GoogleFonts.openSans(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 24),
                if (_attendanceMarked)
                  ElevatedButton(
                    onPressed: () async {
                      await _deleteAttendance();
                      Navigator.pop(ctx);
                      _stopScan();
                      _startScan();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Delete Attendance',
                      style: GoogleFonts.openSans(color: Colors.white, fontSize: 16),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _stopScan();
                      _startScan();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.openSans(color: Colors.black, fontSize: 16),
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
        Text('$label:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(child: Text(value, style: TextStyle(color: Colors.white))),
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
        backgroundColor: Colors.teal[800],
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Take Attendance', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal, Colors.tealAccent],
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
                    decoration:
                    BoxDecoration(shape: BoxShape.circle, color: Colors.tealAccent.withOpacity(0.3)),
                    child: Center(
                      child: Icon(
                        _attendanceMarked ? Icons.check_circle : _isConnected
                            ? Icons.bluetooth_connected
                            : Icons.wifi_tethering,
                        size: 60,
                        color: _attendanceMarked ? Colors.tealAccent : Colors.white,
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
                    ? 'Connected to Beacon…'
                    : 'Scanning for Beacons…',
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
                    valueColor: AlwaysStoppedAnimation(Colors.tealAccent),
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
                        decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(e.key.substring(e.key.length - 5),
                                style: const TextStyle(color: Colors.white)),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: percent,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation(Colors.tealAccent),
                            ),
                            const SizedBox(height: 4),
                            Text('${(percent * 100).toInt()}%',
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                  label: Text(_isScanning ? 'Stop Scanning' : 'Start Scan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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