import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:math';


class BLEScannerScreen extends StatefulWidget {
  const BLEScannerScreen({super.key});

  @override
  State<BLEScannerScreen> createState() => _BLEScannerScreenState();
}

class _BLEScannerScreenState extends State<BLEScannerScreen> {
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  double _calculateDistance(int rssi, {int txPower = -59}) {
    if (rssi == 0) return -1.0;
    return pow(10, (txPower - rssi) / 20).toDouble();
  }
  @override
  void initState() {
    super.initState();
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        _startScan();
      }
    });
  }
  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    try {
      setState(() => _isScanning = true);
      _devices.clear();

      if (!await FlutterBluePlus.isAvailable) {
        throw 'Bluetooth not available';
      }

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          if (!_devices.any((d) => d.id == result.device.id)) {
            setState(() {
              _devices.add(result.device);
            });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Scanner'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.search),
            onPressed: _isScanning ? _stopScan : _startScan,
          )
        ],
      ),
      body: _devices.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the search button to scan',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(device.name ?? 'Unknown Device'),
            subtitle: Text(device.id.toString()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BeaconDetailsScreen(
                    device: device,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    setState(() => _isScanning = false);
  }
}

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name ?? 'Device Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bluetooth,
                          color: _isConnected ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            color: _isConnected ? Colors.blue : Colors.grey,
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
                      const SizedBox(height: 16),
                      Text(
                        _distance! <= 8.0 ? '✅ In Range' : '❌ Too Far',
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
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }
}