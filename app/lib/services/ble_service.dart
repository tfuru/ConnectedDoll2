import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_ble/universal_ble.dart';

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // BLE UUID 定義 (ファームウェア board/firmware/src/ble/ble_manager.h の定義に完全一致)
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String charTimeUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String charFileCtrlUuid = 'e32a4e2b-fbc6-4b95-a22a-28d88b409600';
  static const String charFileDataUuid = '7b01d784-fb3b-4ce1-897b-cfd1264c7847';
  static const String charAlarmConfigUuid = 'e82d0001-fbc6-4b95-a22a-28d88b409600';
  static const String charLedBrightnessUuid = 'e82d0002-fbc6-4b95-a22a-28d88b409600';

  BleDevice? connectedDevice;
  bool isConnected = false;

  final StreamController<BleDevice> scanResultController = StreamController<BleDevice>.broadcast();
  final StreamController<String> alarmStateController = StreamController<String>.broadcast();
  final StreamController<double> transferProgressController = StreamController<double>.broadcast();
  final StreamController<String> transferStatusController = StreamController<String>.broadcast();

  StreamSubscription<BleDevice>? _scanSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<Uint8List>? _alarmSubscription;

  // 初期化
  void init() {
    // スキャンの Stream を購読
    _scanSubscription = UniversalBle.scanStream.listen((BleDevice device) {
      final name = device.name?.toLowerCase() ?? '';
      if (name.contains('connecteddoll2')) {
        scanResultController.add(device);
      }
    });
  }

  // スキャン開始
  Future<void> startScan() async {
    print('Starting BLE scan with relaxed filter...');
    await UniversalBle.startScan();
  }

  // スキャン停止
  Future<void> stopScan() async {
    await UniversalBle.stopScan();
  }

  // 接続
  Future<void> connect(BleDevice device) async {
    print('Connecting to device: ${device.name} (${device.deviceId})');
    await stopScan();
    await UniversalBle.connect(device.deviceId);
    connectedDevice = device;
    isConnected = true;

    // コネクション状態変更の監視
    _connectionSubscription?.cancel();
    _connectionSubscription = UniversalBle.connectionStream(device.deviceId).listen((bool connected) {
      print('Connection stream updated: $connected');
      isConnected = connected;
      if (!connected) {
        connectedDevice = null;
        transferStatusController.add("Disconnected");
        _alarmSubscription?.cancel();
      } else {
        transferStatusController.add("Connected");
      }
    });

    // MTUの引き上げを試みる (ファイル転送の高速化)
    try {
      final mtu = await UniversalBle.requestMtu(device.deviceId, 517); // ボード側設定の517に合わせる
      print('MTU updated to: $mtu');
    } catch (e) {
      print('Failed to update MTU: $e');
    }

    // サービスと特性の検索
    await UniversalBle.discoverServices(device.deviceId);

    // アラーム設定特性の通知登録
    await UniversalBle.subscribeNotifications(device.deviceId, serviceUuid, charAlarmConfigUuid);
    _alarmSubscription?.cancel();
    _alarmSubscription = UniversalBle.characteristicValueStream(device.deviceId, charAlarmConfigUuid).listen((Uint8List value) {
      final dataStr = utf8.decode(value);
      print('Received Alarm state: $dataStr');
      alarmStateController.add(dataStr);
    });

    // 初期アラーム状態の取得要求
    await readAlarmState();

    // スマートフォンの現在時刻をボードへ自動同期
    await syncTime();
  }

  // 切断
  Future<void> disconnect() async {
    if (connectedDevice != null) {
      await UniversalBle.disconnect(connectedDevice!.deviceId);
      connectedDevice = null;
      isConnected = false;
      _connectionSubscription?.cancel();
      _alarmSubscription?.cancel();
    }
  }

  // スマートフォンの時刻をボードのRTCへ自動同期
  Future<void> syncTime() async {
    if (connectedDevice == null) return;
    try {
      final now = DateTime.now();
      final timeStr = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      
      print('Syncing smartphone time to RTC: $timeStr');
      await UniversalBle.write(
        connectedDevice!.deviceId,
        serviceUuid,
        charTimeUuid,
        Uint8List.fromList(utf8.encode(timeStr)),
        withoutResponse: false,
      );
    } catch (e) {
      print('Failed to sync time via BLE: $e');
    }
  }

  // ボードのRTCから現在時刻を取得 (Read)
  Future<String?> readDeviceTime() async {
    if (connectedDevice == null) return null;
    try {
      final val = await UniversalBle.read(
        connectedDevice!.deviceId,
        serviceUuid,
        charTimeUuid,
      );
      final timeStr = utf8.decode(val);
      print('Read device time: $timeStr');
      return timeStr;
    } catch (e) {
      print('Error reading device time: $e');
      return null;
    }
  }

  // LEDの明るさを取得 (Read)
  Future<int?> readLedBrightness() async {
    if (connectedDevice == null) return null;
    try {
      final val = await UniversalBle.read(
        connectedDevice!.deviceId,
        serviceUuid,
        charLedBrightnessUuid,
      );
      final brightStr = utf8.decode(val);
      final bright = int.tryParse(brightStr);
      print('Read LED brightness: $bright');
      return bright;
    } catch (e) {
      print('Error reading LED brightness: $e');
      return null;
    }
  }

  // LEDの明るさを設定 (Write)
  Future<void> writeLedBrightness(int brightness) async {
    if (connectedDevice == null) return;
    try {
      print('Setting LED brightness to: $brightness');
      await UniversalBle.write(
        connectedDevice!.deviceId,
        serviceUuid,
        charLedBrightnessUuid,
        Uint8List.fromList(utf8.encode(brightness.toString())),
        withoutResponse: false,
      );
    } catch (e) {
      print('Failed to write LED brightness: $e');
    }
  }

  // アラーム情報要求 (Read)
  Future<void> readAlarmState() async {
    if (connectedDevice == null) return;
    try {
      final val = await UniversalBle.read(
        connectedDevice!.deviceId,
        serviceUuid,
        charAlarmConfigUuid,
      );
      final stateStr = utf8.decode(val);
      alarmStateController.add(stateStr);
    } catch (e) {
      print('Error reading alarm state: $e');
    }
  }

  // アラーム送信
  Future<void> sendAlarmCommand(String command) async {
    if (connectedDevice == null) return;
    print('Sending alarm command: $command');
    final data = utf8.encode(command);
    await UniversalBle.write(
      connectedDevice!.deviceId,
      serviceUuid,
      charAlarmConfigUuid,
      Uint8List.fromList(data),
      withoutResponse: false,
    );
  }

  // ファイル転送 (WAVバイナリ分割送信)
  Future<void> transferFile(String filename, Uint8List fileData) async {
    if (connectedDevice == null) {
      transferStatusController.add("Error: Not Connected");
      return;
    }

    final deviceId = connectedDevice!.deviceId;
    transferProgressController.add(0.0);
    transferStatusController.add("Preparing transfer...");

    try {
      // 1. 開始メッセージ送信 (File Control 特性へ)
      final startMsg = 'START:$filename,${fileData.length}';
      print('Sending Start to FILE_CTRL: $startMsg');
      await UniversalBle.write(
        deviceId,
        serviceUuid,
        charFileCtrlUuid,
        Uint8List.fromList(utf8.encode(startMsg)),
        withoutResponse: false,
      );

      // 受信側（ボード）が書き込み準備を整えるためのウエイト
      await Future.delayed(const Duration(milliseconds: 500));

      // 2. バイナリデータをパケット分割して順次送信 (File Data 特性へ)
      // ボードのMTU 517に合わせた最適な送信サイズ（ヘッダー等のオーバーヘッドを引き限界値500とする）
      const int packetSize = 500;
      final int totalBytes = fileData.length;
      int bytesSent = 0;

      transferStatusController.add("Sending data...");

      while (bytesSent < totalBytes) {
        int end = bytesSent + packetSize;
        if (end > totalBytes) end = totalBytes;

        final packet = fileData.sublist(bytesSent, end);
        await UniversalBle.write(
          deviceId,
          serviceUuid,
          charFileDataUuid,
          packet,
          withoutResponse: true, // WriteWithoutResponseによる高速化を有効化
        );

        bytesSent = end;
        final progress = bytesSent / totalBytes;
        transferProgressController.add(progress);

        // ボード側の受信バッファオーバーフロー防止のためのウェイト（高速転送に微調整）
        await Future.delayed(const Duration(milliseconds: 3));
      }

      // 3. 終了メッセージ送信 (File Control 特性へ)
      print('Sending End to FILE_CTRL');
      await UniversalBle.write(
        deviceId,
        serviceUuid,
        charFileCtrlUuid,
        Uint8List.fromList(utf8.encode('END')),
        withoutResponse: false,
      );

      transferStatusController.add("Transfer completed successfully.");
    } catch (e) {
      print('Error during file transfer: $e');
      transferStatusController.add("Transfer failed: $e");
    }
  }

  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _alarmSubscription?.cancel();
    scanResultController.close();
    alarmStateController.close();
    transferProgressController.close();
    transferStatusController.close();
  }
}
