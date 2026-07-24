import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart' hide BleService;
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_service.dart';
import 'alarm_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final BleService _bleService = BleService();
  final List<BleDevice> _scannedDevices = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _connectingDeviceId; // 現在接続試行中のデバイスID

  @override
  void initState() {
    super.initState();
    _bleService.scanResultController.stream.listen((device) {
      if (!_scannedDevices.any((d) => d.deviceId == device.deviceId)) {
        setState(() {
          _scannedDevices.add(device);
        });
      }
    });

    // バックグラウンドで切断が起きた際にUIを再描画するためのリッスン
    _bleService.transferStatusController.stream.listen((status) {
      if (status == "Disconnected" || status == "Connected") {
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses[Permission.bluetoothScan] == PermissionStatus.granted &&
        statuses[Permission.bluetoothConnect] == PermissionStatus.granted &&
        statuses[Permission.location] == PermissionStatus.granted;
  }

  void _toggleScan() async {
    if (_isScanning) {
      await _bleService.stopScan();
      setState(() {
        _isScanning = false;
      });
    } else {
      setState(() {
        _scannedDevices.clear();
      });

      // Bluetooth権限の確認・要求
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth & Location permissions are required for scanning.')),
        );
        return;
      }

      setState(() {
        _isScanning = true;
      });

      try {
        await _bleService.startScan();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan Error: $e')),
        );
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _connectDevice(BleDevice device) async {
    setState(() {
      _isConnecting = true;
      _connectingDeviceId = device.deviceId;
    });
    try {
      await _bleService.connect(device);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.name}')),
      );
      // アラーム設定画面へ遷移
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AlarmScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection Failed: $e')),
      );
    } finally {
      setState(() {
        _isConnecting = false;
        _connectingDeviceId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Sleek Dark Slate
      appBar: AppBar(
        title: const Text('Device Scan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isScanning ? Icons.stop_circle : Icons.search,
              color: _isScanning ? Colors.redAccent : Colors.indigoAccent,
              size: 28,
            ),
            onPressed: _isConnecting ? null : _toggleScan,
            tooltip: _isScanning ? 'Stop Scan' : 'Start Scan',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E1E38)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_isScanning) ...[
                const LinearProgressIndicator(
                  color: Colors.indigoAccent,
                  backgroundColor: Colors.white10,
                ),
                const SizedBox(height: 12),
              ],
              
              Expanded(
                child: ListView.builder(
                  itemCount: _scannedDevices.length,
                  itemBuilder: (context, index) {
                    final device = _scannedDevices[index];
                    final isConnected = _bleService.connectedDevice?.deviceId == device.deviceId;
                    final isConnectingThis = _connectingDeviceId == device.deviceId;

                    return Card(
                      color: isConnected 
                          ? Colors.greenAccent.withValues(alpha: 0.02) 
                          : Colors.white.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: isConnected 
                              ? Colors.greenAccent.withValues(alpha: 0.4) 
                              : Colors.white.withValues(alpha: 0.08),
                          width: isConnected ? 1.2 : 1.0,
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 14),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor: isConnected 
                              ? const Color(0xFF064E3B) 
                              : const Color(0xFF312E81),
                          child: Icon(
                            isConnected ? Icons.bluetooth_connected : Icons.bluetooth, 
                            color: isConnected ? Colors.greenAccent : Colors.indigoAccent,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                device.name ?? 'Unknown Device',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isConnected) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.greenAccent, width: 0.8),
                                ),
                                child: const Text(
                                  'CONNECTED',
                                  style: TextStyle(
                                    color: Colors.greenAccent, 
                                    fontSize: 10, 
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            device.deviceId,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                        trailing: isConnectingThis
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.indigoAccent, 
                                  strokeWidth: 2.5,
                                ),
                              )
                            : isConnected
                                ? ElevatedButton(
                                    onPressed: () async {
                                      await _bleService.disconnect();
                                      setState(() {});
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Disconnect', 
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_ios, color: Colors.indigoAccent, size: 16),
                        onTap: (isConnected || _isConnecting) ? null : () => _connectDevice(device),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
