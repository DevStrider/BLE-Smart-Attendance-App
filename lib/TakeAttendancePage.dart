// lib/TakeAttendancePage.dart

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'database_service.dart';

// — your color palette —
class AppColors {
  static const backgroundStart = Color(0xFF004D43);
  static const backgroundEnd   = Color(0xFF046307);
  static const card            = Color(0xFF1E1E1E);
  static const beam            = Color(0xFF00D38C);
  static const rings           = Color(0xFF00D38C);
  static const textPrimary     = Colors.white;
  static const textSecondary   = Colors.white70;
  static const error           = Color(0xFFFF5252);
}

class DeviceBlip {
  final double angle;     // in radians
  final double distNorm;  // 0.0–1.0
  DeviceBlip(this.angle, this.distNorm);
}

class TakeAttendancePage extends StatefulWidget {
  final String selectedCourse;
  const TakeAttendancePage({Key? key, required this.selectedCourse})
      : super(key: key);

  @override
  _TakeAttendancePageState createState() => _TakeAttendancePageState();
}

class _TakeAttendancePageState extends State<TakeAttendancePage>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();

  bool _isScanning = false;
  bool _found      = false;
  ScanResult? _result;
  StreamSubscription<List<ScanResult>>? _scanSub;
  final Map<String, DeviceBlip> _blipsMap = {};
  Set<String> _allowedMacs = {};

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    // pulsing center icon
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // load beacon definitions to filter by course
    _loadDefinitions().then((_) {
      _requestPermissions().then((_) => _startScan());
    });
  }

  /// Reads your `/beacons` node and builds the set of MACs for the selected course.
  Future<void> _loadDefinitions() async {
    final data = await _dbService.read(path: 'beacons');
    final allowed = <String>{};
    if (data != null) {
      data.forEach((_, def) {
        final courses = List<String>.from(def['courses'] as List<dynamic>);
        final mac     = (def['mac'] as String).toUpperCase();
        if (courses.contains(widget.selectedCourse)) {
          allowed.add(mac);
        }
      });
    }
    setState(() => _allowedMacs = allowed);
  }

  Future<void> _requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_allowedMacs.isEmpty) {
      // show an alert instead of a SnackBar
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'No Beacon Configured',
            style: GoogleFonts.poppins(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'No beacons are associated with "${widget.selectedCourse}".\n'
                'Please contact your instructor or select another course.',
            style: GoogleFonts.openSans(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('OK', style: GoogleFonts.openSans(color: AppColors.beam)),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _found      = false;
      _blipsMap.clear();
    });

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (var r in results) {
        final id = r.device.id.toString().toUpperCase();

        // always add a radar blip
        if (!_blipsMap.containsKey(id)) {
          final rng = Random(id.hashCode);
          final angle = rng.nextDouble() * 2 * pi;
          final dist  = pow(10, (-59 - r.rssi) / 20).toDouble();
          const maxDist = 10.0;
          final distNorm = dist > maxDist ? 1.0 : dist / maxDist;
          _blipsMap[id] = DeviceBlip(angle, distNorm);
        }

        // only trigger on allowed MACs
        if (_allowedMacs.contains(id)) {
          _stopScan();
          setState(() {
            _found  = true;
            _result = r;
          });
          _recordAttendance(r);
          _showResultDialog();
          break;
        }
      }
      setState(() {}); // redraw blips
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    setState(() => _isScanning = false);
  }

  Future<void> _recordAttendance(ScanResult result) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid     = user.uid;
    final now     = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final ms      = now.millisecondsSinceEpoch;
    final distance = pow(10, (-59 - result.rssi) / 20).toDouble();
    final status   = distance <= 2.0 ? 'attended' : 'absent';

    // log raw beacon event
    await _dbService.create(
      path: 'beacons',
      data: {
        'uuid':       result.device.id.toString(),
        'course':     widget.selectedCourse,
        'studentUid': uid,
        'timestamp':  ms,
        'rssi':       result.rssi,
        'distance':   distance,
      },
      generateKey: true,
    );

    // record attendance under date/uid
    await _dbService.create(
      path: 'attendance/${widget.selectedCourse}/$dateStr/$uid',
      data: {
        'timestampStart': ms,
        'timestampEnd':   ms,
        'status':         status,
        'beaconUuid':     result.device.id.toString(),
      },
      generateKey: false,
    );
  }

  void _showResultDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Attendance Details',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (ctx, anim1, anim2) {
        final r = _result!;
        final dist = pow(10, (-59 - r.rssi) / 20).toStringAsFixed(2);
        final time = DateFormat('hh:mm:ss a').format(DateTime.now());
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.8,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Attendance Details',
                      style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _infoRow('Course', widget.selectedCourse),
                  _infoRow('Device', r.device.id.toString()),
                  _infoRow('Signal', '${r.rssi} dBm'),
                  _infoRow('Distance', '$dist m'),
                  _infoRow('Time', time),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() => _found = false);
                      _startScan();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.beam,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text('Scan Again',
                        style: GoogleFonts.openSans(
                            color: Colors.black, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text('$label:',
              style: TextStyle(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double cardWidth = MediaQuery.of(context).size.width * 0.8;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundStart,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Take Attendance',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
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

              // pulsing beacon icon
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
                        _found ? Icons.check_circle : Icons.wifi_tethering,
                        size: 60,
                        color: _found ? AppColors.beam : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                _found ? 'Beacon Found!' : 'Scanning for Beacons…',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 20),
              ),

              const SizedBox(height: 24),

              // live blip list
              if (!_found)
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _blipsMap.entries.map((e) {
                      final id = e.key;
                      final d  = (e.value.distNorm * 100).toInt();
                      return Container(
                        width: cardWidth * 0.4,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(id.substring(id.length - 5),
                                style: const TextStyle(color: Colors.white)),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: 1 - e.value.distNorm,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation(AppColors.beam),
                            ),
                            const SizedBox(height: 4),
                            Text('$d%',
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const Spacer(),

              // scan/stop button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? _stopScan : _startScan,
                  icon: Icon(_isScanning ? Icons.stop : Icons.search),
                  label: Text(_isScanning ? 'Stop Scanning' : 'Start Scan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.card,
                    foregroundColor: AppColors.textPrimary,
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