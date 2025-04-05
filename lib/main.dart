import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:math';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(

        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: Text(widget.title),
      ),
      body: Center(

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
/////////////////////////////////////////////////////////////////
class BLEScannerScreen extends StatefulWidget {
  const BLEScannerScreen({super.key});

  @override
  State<BLEScannerScreen> createState() => _BLEScannerScreenState();
}

class _BLEScannerScreenState extends State<BLEScannerScreen> {
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // Distance calculation function
  double _calculateDistance(int rssi, {int txPower = -59}) {
    if (rssi == 0) return -1.0;
    return pow(10, (txPower - rssi) / 20).toDouble();
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
      appBar: AppBar(title: const Text('BLE Scanner')),
      body: ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          final device = _devices[index];
          return ListTile(
            title: Text(device.name ?? 'Unknown'),
            subtitle: Text(device.id.toString()),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : _startScan,
        child: const Icon(Icons.search),
      ),
    );
  }
}

class BeaconDetailsScreen extends StatefulWidget {
  final BluetoothDevice device;
  final int initialRssi;

  const BeaconDetailsScreen({
    super.key,
    required this.device,
    this.initialRssi = -59, // Make optional with default value
  });

  @override
  State<BeaconDetailsScreen> createState() => _BeaconDetailsScreenState();
}

class _BeaconDetailsScreenState extends State<BeaconDetailsScreen> {
  double? _distance;
  bool _isConnected = false;
  Timer? _rssiTimer;
  int? _currentRssi;

  // Distance calculation (same as scanner)
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
      appBar: AppBar(title: const Text('Device Details')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              size: 50,
              color: _isConnected ? Colors.blue : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text('Device: ${widget.device.name ?? 'Unknown'}'),
            Text('ID: ${widget.device.id}'),
            const SizedBox(height: 20),
            if (_currentRssi != null) Text('RSSI: $_currentRssi dBm'),
            if (_distance != null) ...[
              Text('Distance: ${_distance!.toStringAsFixed(2)} meters'),
              Text(
                _distance! <= 8.0 ? 'Attendance Recorded' : 'Too Far Away',
                style: TextStyle(
                  color: _distance! <= 8.0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


