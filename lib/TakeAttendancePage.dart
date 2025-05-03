import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_service.dart';

// Smoothed radar with motion blur effect and eased beam
class AppColors {
  static const backgroundStart = Color(0xFF004D43);
  static const backgroundEnd = Color(0xFF046307);
  static const card = Color(0xFF1E1E1E);
  static const beam = Color(0xFF00D38C);
  static const rings = Color(0xFF00D38C);
  static const textPrimary = Colors.white;
  static const textSecondary = Colors.white70;
  static const error = Color(0xFFFF5252);
}

class DeviceBlip {
  final double angle;     // in radians
  final double distNorm;  // 0.0–1.0, fraction of max radius
  DeviceBlip(this.angle, this.distNorm);
}

class TakeAttendancePage extends StatefulWidget {
  final String selectedCourse;
  const TakeAttendancePage({super.key, required this.selectedCourse});

  @override
  _TakeAttendancePageState createState() => _TakeAttendancePageState();
}

class _TakeAttendancePageState extends State<TakeAttendancePage>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  bool _isScanning = false;
  bool _found = false;
  ScanResult? _result;
  StreamSubscription<List<ScanResult>>? _scanSub;

  // map deviceId → blip so we only add each once
  final Map<String, DeviceBlip> _blipsMap = {};

  // target MAC for “official” attendance
  final String targetMac = 'BC:57:29:00:4B:3A';

  late AnimationController _beamCtrl;
  late Animation<double> _beamAnim;

  @override
  void initState() {
    super.initState();
    _beamCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _beamAnim = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _beamCtrl, curve: Curves.easeInOut),
    );
    _requestPermissions().then((_) {
      _startScan();
      _beamCtrl.repeat();
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.location.request();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _beamCtrl.dispose();
    super.dispose();
  }

  void _toggleScan() {
    if (_isScanning) {
      _stopScan();
      _beamCtrl.stop();
    } else {
      _startScan();
      _beamCtrl.repeat();
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _found = false;
      _blipsMap.clear();
    });

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (var r in results) {
        final id = r.device.id.toString();
        // create a blip for each new device
        if (!_blipsMap.containsKey(id)) {
          final rng = Random(id.hashCode);
          final angle = rng.nextDouble() * 2 * pi;
          final dist = pow(10, (-59 - r.rssi) / 20).toDouble();
          const maxDist = 10.0; // 10 meters
          final distNorm = dist > maxDist ? 1.0 : dist / maxDist;
          _blipsMap[id] = DeviceBlip(angle, distNorm);
        }
        // check for our attendance target
        if (id.toUpperCase() == targetMac) {
          _stopScan();
          setState(() {
            _found = true;
            _result = r;
          });
          _recordAttendance(r);
          break;
        }
      }
      setState(() {}); // redraw with new blips
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
  }

  Future<void> _recordAttendance(ScanResult result) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final uid = user.uid;
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final distance = pow(10, (-59 - result.rssi) / 20).toDouble();
      final status = distance <= 8 ? 'attended' : 'absent';

      await _dbService.create(
        path: 'attendance/${widget.selectedCourse}/$dateStr/$uid',
        data: {
          'timestampStart': nowMs,
          'timestampEnd': nowMs,
          'status': status,
          'beaconUuid': result.device.id.toString(),
        },
        generateKey: false,
      );
    } catch (e) {
      debugPrint('Error recording attendance: $e');
    }
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    setState(() => _isScanning = false);
  }

  @override
  Widget build(BuildContext context) {
    // Radar uses 85% of screen width
    final double radarSize = MediaQuery.of(context).size.width * 0.85;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundStart,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Take Attendance',
            style: TextStyle(color: AppColors.textPrimary)),
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
          child: Stack(
            children: [
              // Radar moved up (y = -0.2)
              Align(
                alignment: const Alignment(0, -0.2),
                child: AnimatedBuilder(
                  animation: _beamAnim,
                  builder: (_, child) => CustomPaint(
                    size: Size(radarSize, radarSize),
                    painter: _SmoothRadarPainter(
                      angle: _beamAnim.value,
                      blips: _blipsMap.values.toList(),
                    ),
                    child: child,
                  ),
                  child: SizedBox(width: radarSize, height: radarSize),
                ),
              ),

              Positioned(
                bottom: 100,
                left: MediaQuery.of(context).size.width / 2 - 28,
                child: FloatingActionButton(
                  backgroundColor: AppColors.card,
                  child: Icon(_isScanning ? Icons.stop : Icons.search),
                  onPressed: _toggleScan,
                ),
              ),

              if (_found && _result != null)
                DraggableScrollableSheet(
                  initialChildSize: 0.3,
                  minChildSize: 0.1,
                  maxChildSize: 0.6,
                  builder: (context, sc) => Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: ListView(
                      controller: sc,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Attendance Details',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const Divider(color: Colors.white24),
                        _infoRow('Subject', widget.selectedCourse),
                        _infoRow('Device', _result!.device.id.toString()),
                        _infoRow('Signal', '${_result!.rssi} dBm'),
                        _infoRow(
                          'Distance',
                          '${pow(10, (-59 - _result!.rssi) / 20).toStringAsFixed(2)} m',
                        ),
                        _infoRow('Date',
                            DateFormat('yyyy-MM-dd').format(DateTime.now())),
                        _infoRow('Time',
                            DateFormat('hh:mm:ss a').format(DateTime.now())),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            (pow(10, (-59 - _result!.rssi) / 20) <= 8)
                                ? '✅ Attendance Recorded'
                                : '❌ Too Far',
                            style: TextStyle(
                                color: (pow(10, (-59 - _result!.rssi) / 20) <=
                                    8)
                                    ? AppColors.beam
                                    : AppColors.error,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Text('$label:',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
            child:
            Text(value, style: TextStyle(color: AppColors.textPrimary))),
      ],
    ),
  );
}

class _SmoothRadarPainter extends CustomPainter {
  final double angle;
  final List<DeviceBlip> blips;

  _SmoothRadarPainter({required this.angle, required this.blips});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.width / 2;

    // Draw concentric rings
    final ringPaint = Paint()
      ..color = AppColors.rings.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxR * i / 3, ringPaint);
    }

    // Draw sweeping beam
    final beamPaint = Paint()
      ..shader = SweepGradient(
        startAngle: angle,
        endAngle: angle + pi / 8,
        colors: [AppColors.beam.withOpacity(0.3), Colors.transparent],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, beamPaint);

    // Glow
    canvas.drawCircle(center, maxR,
        Paint()..color = AppColors.beam.withOpacity(0.1));

    // Draw red device blips
    for (var b in blips) {
      final r = b.distNorm * maxR;
      // rotate so 0 rad = upward
      final dx = center.dx + r * cos(b.angle - pi / 2);
      final dy = center.dy + r * sin(b.angle - pi / 2);
      canvas.drawCircle(
          Offset(dx, dy),
          6,
          Paint()
            ..color = Colors.redAccent.withOpacity(0.9)
            ..style = PaintingStyle.fill);
    }

    // Center dot
    canvas.drawCircle(center, 3, Paint()..color = AppColors.beam);
  }

  @override
  bool shouldRepaint(covariant _SmoothRadarPainter old) =>
      old.angle != angle || old.blips.length != blips.length;
}
