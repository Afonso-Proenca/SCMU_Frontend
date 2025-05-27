import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// Request permissions
Future<void> requestPermissions() async {
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();
}


class BleSensorSelector extends StatefulWidget {
  const BleSensorSelector({Key? key}) : super(key: key);

  @override
  State<BleSensorSelector> createState() => _BleSensorSelectorState();
}

class _BleSensorSelectorState extends State<BleSensorSelector> {
  bool _bluetoothState = false;
  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;
  String _receivedData = "No data received yet.";
  bool _isConnecting = false;

  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;

  static const String SERVICE_UUID = "928327fa-5f8a-4dc6-a795-4c08ca7f4ea8";
  static const String CHARACTERISTIC_UUID = "00f6c4aa-a0ef-4e74-960c-78a34b9ac1ef";

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _characteristicSubscription?.cancel();
    FlutterBluePlus.stopScan();
    _connectedDevice?.disconnect();
    super.dispose();
  }

  void _initializeBluetooth() async {
    await requestPermissions();

    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        _bluetoothState = state == BluetoothAdapterState.on;
      });
    });

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      print("Scanned ${results.length} devices:");

      for (var r in results) {
        final name = r.device.platformName.isNotEmpty ? r.device.platformName : "(No Name)";
        print("Device: '$name' | ID: ${r.device.remoteId}");
      }

      setState(() {
        _scanResults = results.where((r) {
          final name = r.device.platformName.toLowerCase();
          return name.contains('esp32_dev');
        }).toList();

        if (_scanResults.isEmpty) {
          print("No matching 'esp32_dev' devices found.");
        }
      });
    });
  }


  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_connectedDevice?.remoteId == device.remoteId || _isConnecting) {
      print("Already connected or connecting to this device.");
      return;
    }

    setState(() {
      _isConnecting = true;
      _receivedData = "Connecting...";
    });

    try {
      await device.disconnect();
      await Future.delayed(Duration(milliseconds: 300));
      FlutterBluePlus.stopScan();
      await Future.delayed(Duration(milliseconds: 500));

      bool connected = false;
      int attempts = 0;
      const maxAttempts = 3;

      while (!connected && attempts < maxAttempts) {
        attempts++;
        try {
          print("Attempt $attempts to connect to ${device.platformName}...");
          await device.connect();
          connected = true;
          print("Connected on attempt $attempts");
        } catch (e) {
          print("Attempt $attempts failed: $e");
          await Future.delayed(Duration(seconds: 1));
        }
      }

      if (!connected) {
        throw Exception("Failed to connect after $maxAttempts attempts.");
      }

      _connectedDevice = device;

      // Listen for disconnection
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = device.connectionState.listen((state) {
        print("Connection state: $state");
        if (state == BluetoothConnectionState.disconnected) {
          setState(() {
            _connectedDevice = null;
            _receivedData = "Disconnected from ${device.platformName}";
            _isConnecting = false;
          });
          _characteristicSubscription?.cancel();
        }
      });

      // Discover services and characteristics
      List<BluetoothService> services = await device.discoverServices();
      BluetoothCharacteristic? targetCharacteristic;

      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
              targetCharacteristic = characteristic;
              break;
            }
          }
        }
        if (targetCharacteristic != null) break;
      }

      if (targetCharacteristic != null) {
        _characteristicSubscription?.cancel();
        if (targetCharacteristic.properties.notify) {
          await targetCharacteristic.setNotifyValue(true);
          _characteristicSubscription = targetCharacteristic.onValueReceived.listen((value) {
            setState(() {
              _receivedData = "Received: ${String.fromCharCodes(value)}";
            });
          });
          setState(() {
            _receivedData = "Connected to ${device.platformName}. Waiting for data...";
          });
        } else if (targetCharacteristic.properties.read) {
          List<int> value = await targetCharacteristic.read();
          setState(() {
            _receivedData = "Connected to ${device.platformName}. Read: ${String.fromCharCodes(value)}";
          });
        } else {
          setState(() {
            _receivedData = "Connected but cannot read or receive notifications.";
          });
        }
      } else {
        setState(() {
          _receivedData = "Characteristic not found.";
        });
        await device.disconnect();
        _connectedDevice = null;
      }
    } catch (e) {
      print("Connection Error: $e");
      setState(() {
        _receivedData = "Connection failed: $e";
        _connectedDevice = null;
      });
      await device.disconnect();
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

//Change
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("BLE Device Selector"), backgroundColor: Color(0xFF015164)),
      body: Column(
        children: [
          // Bluetooth toggle
          ListTile(
            title: Text("Activate Bluetooth"),
            trailing: Switch(
              value: _bluetoothState,
              onChanged: (value) async {
                if (value) {
                  await FlutterBluePlus.turnOn();
                }
              },
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_connectedDevice == null
                  ? "No device connected."
                  : "Connected to: ${_connectedDevice!.platformName}"),
              SizedBox(height: 8),
              Text(_receivedData),
              if (_isConnecting) LinearProgressIndicator(),
            ]),
          ),
          Divider(),
          Expanded(
            child: _scanResults.isEmpty
                ? Center(child: Text("No 'ESP32_dev' devices found."))
                : ListView.builder(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                return ListTile(
                  title: Text(result.device.platformName.isEmpty
                      ? 'Unknown Device'
                      : result.device.platformName),
                  subtitle: Text(result.device.remoteId.str),
                  trailing: Text("${result.rssi} dBm"),
                  onTap: _isConnecting ? null : () => _connectToDevice(result.device),
                );
              },
            ),
          )
        ],
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBluePlus.isScanning,
        initialData: false,
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return FloatingActionButton(
              onPressed: FlutterBluePlus.stopScan,
              child: Icon(Icons.stop, color: Colors.red),
              backgroundColor: Colors.white,
            );
          } else {
            return FloatingActionButton(
              onPressed: () {
                if (_bluetoothState) {
                  FlutterBluePlus.startScan(timeout: Duration(seconds: 10));
                  setState(() => _scanResults.clear());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Enable Bluetooth first.")));
                }
              },
              child: Icon(Icons.search),
              backgroundColor: Colors.white,
            );
          }
        },
      ),
    );
  }
}
