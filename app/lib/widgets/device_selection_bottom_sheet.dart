import 'dart:async';
import 'package:flutter/material.dart';
import 'package:universal_ble/universal_ble.dart' hide BleService;
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_service.dart';

class DeviceSelectionBottomSheet extends StatefulWidget {
  const DeviceSelectionBottomSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DeviceSelectionBottomSheet(),
    );
    return result ?? false;
  }

  @override
  State<DeviceSelectionBottomSheet> createState() => _DeviceSelectionBottomSheetState();
}

class _DeviceSelectionBottomSheetState extends State<DeviceSelectionBottomSheet> {
  final BleService _bleService = BleService();
  final List<BleDevice> _scannedDevices = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _connectingDeviceId;
  StreamSubscription<BleDevice>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _scanSubscription = _bleService.scanResultController.stream.listen((device) {
      if (!_scannedDevices.any((d) => d.deviceId == device.deviceId)) {
        if (mounted) {
          setState(() {
            _scannedDevices.add(device);
          });
        }
      }
    });

    // 起動時に自動でスキャンを開始
    _startScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    if (_isScanning) {
      _bleService.stopScan();
    }
    super.dispose();
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

  Future<void> _startScan() async {
    if (_isScanning) return;

    setState(() {
      _scannedDevices.clear();
    });

    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth権限が必要です')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isScanning = true;
      });
    }

    try {
      await _bleService.startScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('スキャンエラー: $e')),
        );
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _stopScan() async {
    await _bleService.stopScan();
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connectDevice(BleDevice device) async {
    setState(() {
      _isConnecting = true;
      _connectingDeviceId = device.deviceId;
    });

    // 接続前にスキャンを停止
    if (_isScanning) {
      await _stopScan();
    }

    try {
      await _bleService.connect(device);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${device.name ?? "デバイス"} に接続しました')),
        );
        Navigator.pop(context, true); // 接続成功
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('接続に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingDeviceId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 上部バー & ヘッダー
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bluetooth_searching_rounded, color: Color(0xFF6366F1), size: 24),
                    const SizedBox(width: 10),
                    const Text(
                      '接続先デバイスの選択',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_isScanning)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        tooltip: '再スキャン',
                        onPressed: _isConnecting ? null : _startScan,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // スキャン結果一覧
          Expanded(
            child: _scannedDevices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isScanning) ...[
                          const CircularProgressIndicator(color: Color(0xFF6366F1)),
                          const SizedBox(height: 16),
                          const Text(
                            'ConnectedDoll2 デバイスをスキャン中...',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ] else ...[
                          const Icon(Icons.bluetooth_disabled_rounded, size: 48, color: Colors.white24),
                          const SizedBox(height: 12),
                          const Text(
                            'デバイスが見つかりませんでした',
                            style: TextStyle(color: Colors.white60, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF334155),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _startScan,
                            icon: const Icon(Icons.refresh, color: Colors.white, size: 16),
                            label: const Text('再スキャン', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: _scannedDevices.length,
                    itemBuilder: (context, index) {
                      final device = _scannedDevices[index];
                      final isConnected = _bleService.connectedDevice?.deviceId == device.deviceId;
                      final isConnectingThis = _connectingDeviceId == device.deviceId;
                      final deviceName = (device.name != null && device.name!.isNotEmpty)
                          ? device.name!
                          : 'Unknown Device';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isConnected
                                ? const Color(0xFF10B981)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFF6366F1).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                              color: isConnected ? const Color(0xFF10B981) : const Color(0xFF818CF8),
                              size: 22,
                            ),
                          ),
                          title: Text(
                            deviceName,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          subtitle: Text(
                            device.deviceId,
                            style: const TextStyle(fontSize: 11, color: Colors.white38),
                          ),
                          trailing: isConnectingThis
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isConnected
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF4F46E5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  onPressed: (_isConnecting || isConnected) ? null : () => _connectDevice(device),
                                  child: Text(
                                    isConnected ? '接続中' : '接続',
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
