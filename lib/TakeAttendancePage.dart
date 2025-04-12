import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';

// Define a color scheme for the app.
class AppColors {
  static const background = Color(0xFF0C130E);
  static const appBarColor = Color(0xFF1C1C1C);
  static const cardBackground = Color(0xFF1E1E1E); // Dark card for details.
  static const iconColor = Colors.white70;
  static const textColor = Colors.white;
  static const accentConnected = Colors.greenAccent;
  static const accentDisconnected = Colors.redAccent;
}

/// Screen that scans for BLE devices.
class TakeAttendancePage extends StatefulWidget {
  const TakeAttendancePage({super.key});

  @override
  State<TakeAttendancePage> createState() => _TakeAttendancePageState();
}

class _TakeAttendancePageState extends State<TakeAttendancePage> {
  // Since we only look for one device, a full list is not necessary.
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  // Define the target MAC address.
  final String targetMac = "BC:57:29:00:4B:3A";

  double _calculateDistance(int rssi, {int txPower = -59}) {
    if (rssi == 0) return -1.0;
    return pow(10, (txPower - rssi) / 20).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    // Start scanning when the Bluetooth adapter is on.
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        _startScan();
      }
    });
  }

  /// Check and request the necessary permissions.
  Future<void> _checkPermissions() async {
    // Request location permission (used on older Android versions).
    if (await Permission.location.request().isGranted) {
      debugPrint("Location permission granted");
    } else {
      debugPrint("Location permission denied");
    }

    // Android 12+ permissions.
    if (await Permission.bluetoothScan.request().isGranted) {
      debugPrint("Bluetooth scan permission granted");
    } else {
      debugPrint("Bluetooth scan permission denied");
    }
    if (await Permission.bluetoothConnect.request().isGranted) {
      debugPrint("Bluetooth connect permission granted");
    } else {
      debugPrint("Bluetooth connect permission denied");
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    try {
      setState(() => _isScanning = true);

      if (!await FlutterBluePlus.isAvailable) {
        throw 'Bluetooth not available';
      }

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        debugPrint("Received ${results.length} scan results");

        // Check each device to see if it matches the target MAC address.
        for (final result in results) {
          final deviceId = result.device.id.toString().toUpperCase();
          debugPrint("Discovered device: $deviceId - ${result.device.name}");

          if (deviceId == targetMac) {
            debugPrint("Target device found: $deviceId");
            _stopScan(); // Stop scanning once the target is found.

            // Navigate to the BeaconDetailsScreen for the target device.
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BeaconDetailsScreen(device: result.device),
              ),
            );
            break; // Exit loop once target is found.
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    setState(() => _isScanning = false);
    _scanSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        title: const Text('Take Attendance'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.search, color: AppColors.iconColor),
            onPressed: _isScanning ? _stopScan : _startScan,
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth, size: 64, color: AppColors.iconColor),
            const SizedBox(height: 16),
            Text(
              _isScanning ? 'Scanning for target device...' : 'Target device not found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textColor),
            ),
            if (!_isScanning)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Tap the search button to scan again',
                  style: TextStyle(color: AppColors.textColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Beacon details screen which connects to the device and shows its signal strength.
class BeaconDetailsScreen extends StatefulWidget {
  final BluetoothDevice device;
  final int initialRssi;

  const BeaconDetailsScreen({
    super.key,
    required this.device,
    this.initialRssi = -59,
  });

  @override
  State<BeaconDetailsScreen> createState() => _BeaconDetailsScreenState();
}

class _BeaconDetailsScreenState extends State<BeaconDetailsScreen> {
  double? _distance;
  bool _isConnected = false;
  Timer? _rssiTimer;
  int? _currentRssi;

  double _calculateDistance(int rssi, {int txPower = -59}) {
    if (rssi == 0) return -1.0;
    return pow(10, (txPower - rssi) / 20).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _currentRssi = widget.initialRssi;
    _distance = _calculateDistance(widget.initialRssi);
    _connectAndMonitor();
  }

  Future<void> _connectAndMonitor() async {
    try {
      await widget.device.connect(autoConnect: false);
      setState(() => _isConnected = true);

      _rssiTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          final rssi = await widget.device.readRssi();
          setState(() {
            _currentRssi = rssi;
            _distance = _calculateDistance(rssi);
          });
        } catch (e) {
          debugPrint('RSSI update failed: $e');
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _rssiTimer?.cancel();
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Format the current date and time using intl.
    final String currentTime = DateFormat('hh:mm:ss a').format(DateTime.now());
    final String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        title: Text(widget.device.name.isNotEmpty ? widget.device.name : 'Device Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          color: AppColors.cardBackground,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Connection status row.
                Row(
                  children: [
                    Icon(
                      Icons.bluetooth,
                      color: _isConnected
                          ? AppColors.accentConnected
                          : AppColors.accentDisconnected,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        color: _isConnected
                            ? AppColors.accentConnected
                            : AppColors.accentDisconnected,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Device ID:', widget.device.id.toString()),
                if (_currentRssi != null)
                  _buildInfoRow('Signal Strength:', '$_currentRssi dBm'),
                if (_distance != null) ...[
                  _buildInfoRow('Distance:', '${_distance!.toStringAsFixed(2)} meters'),
                  _buildInfoRow('Subject:', 'Network Protocol NETW 703'),
                  _buildInfoRow('Time:', currentTime),
                  _buildInfoRow('Date:', currentDate),
                  const SizedBox(height: 16),
                  Text(
                    _distance! <= 8.0 ? '✅ Attendance Recorded' : '❌ Too Far',
                    style: TextStyle(
                      color: _distance! <= 8.0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build info rows with consistent styling.
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textColor),
            ),
          ),
        ],
      ),
    );
  }
}