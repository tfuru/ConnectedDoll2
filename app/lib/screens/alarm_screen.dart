import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ble_service.dart';
import '../services/audio_service.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final BleService _bleService = BleService();
  final List<AlarmSlot> _slots = List.generate(5, (index) => AlarmSlot(index: index));

  // 各スロット（および trigger = -1）のアップロード状態管理
  final Map<int, bool> _isUploading = {};
  final Map<int, double> _uploadProgress = {};
  String _uploadStatusMessage = '';
  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<String>? _alarmSubscription;
  StreamSubscription<double>? _progressSubscription;
  String _deviceTime = 'Loading...';
  double _ledBrightness = 128.0;

  Future<void> _fetchDeviceTime() async {
    if (!mounted) return;
    setState(() {
      _deviceTime = 'Loading...';
    });
    final time = await _bleService.readDeviceTime();
    if (mounted) {
      setState(() {
        _deviceTime = time ?? 'Unknown';
      });
    }
  }

  Future<void> _syncDeviceTime() async {
    if (!mounted) return;
    setState(() {
      _deviceTime = 'Syncing...';
    });
    await _bleService.syncTime();
    await _fetchDeviceTime();
  }

  Future<void> _fetchLedBrightness() async {
    final bright = await _bleService.readLedBrightness();
    if (bright != null && mounted) {
      setState(() {
        _ledBrightness = bright.toDouble();
      });
    }
  }

  Future<void> _updateLedBrightness(double value) async {
    setState(() {
      _ledBrightness = value;
    });
    await _bleService.writeLedBrightness(value.round());
  }

  @override
  void initState() {
    super.initState();
    _alarmSubscription = _bleService.alarmStateController.stream.listen((stateStr) {
      _parseAlarmState(stateStr);
    });
    
    // BLEの転送進捗監視を紐づけ
    _progressSubscription = _bleService.transferProgressController.stream.listen((progress) {
      int? activeSlot = _getActiveUploadingSlot();
      if (activeSlot != null) {
        setState(() {
          _uploadProgress[activeSlot] = progress;
        });
      }
    });

    _statusSubscription = _bleService.transferStatusController.stream.listen((status) {
      setState(() {
        _uploadStatusMessage = status;
      });
      if (status.contains("completed") || status.contains("failed") || status.contains("Error")) {
        setState(() {
          _isUploading.clear();
        });
      }
      if (status == "Disconnected") {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    });

    // 初期状態を読み出す
    _bleService.readAlarmState();
    _fetchDeviceTime();
    _fetchLedBrightness();
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    _progressSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }

  int? _getActiveUploadingSlot() {
    for (var entry in _isUploading.entries) {
      if (entry.value) return entry.key;
    }
    return null;
  }

  // デバイスから受信したステータス文字列をパースする
  void _parseAlarmState(String stateStr) {
    if (stateStr.isEmpty) return;
    try {
      final parts = stateStr.split(';');
      for (var part in parts) {
        if (part.isEmpty) continue;
        
        final subParts = part.split(',');
        final header = subParts[0].split(':');
        if (header.length < 2) continue;
        
        final index = int.parse(header[0]);
        final enabled = header[1] == '1';
        
        final datetimeStr = (enabled && subParts.length >= 2) ? subParts[1] : "Not Set";

        if (index >= 0 && index < 5) {
          setState(() {
            _slots[index].isEnabled = enabled;
            _slots[index].dateTimeStr = datetimeStr;
          });
        }
      }
    } catch (e) {
      print('Error parsing alarm state: $e');
    }
  }

  // アラーム設定ダイアログの表示
  Future<void> _selectDateTime(int index) async {
    // 1. アラームタイプ（毎日 vs 1回限り）の選択ダイアログ
    final String? alarmType = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Select Alarm Type', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text('このアラームの繰り返し設定を選んでください。', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'DAILY'),
              child: const Text('毎日 (Daily)', style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'ONCE'),
              child: const Text('1回のみ (One-time)', style: TextStyle(color: Colors.white60)),
            ),
          ],
        );
      },
    );

    if (alarmType == null) return;

    DateTime? pickedDate;
    if (alarmType == 'ONCE') {
      // 1回のみの場合は日付ピッカーを出す
      if (!mounted) return;
      pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2100),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF4F46E5),
                onPrimary: Colors.white,
                surface: Color(0xFF1E293B),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );
      if (pickedDate == null) return;
    }

    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      if (!mounted) return;
      String cmd = '';
      if (alarmType == 'DAILY') {
        final formattedTime = "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
        cmd = 'SET:$index,DAILY $formattedTime';
      } else if (pickedDate != null) {
        final formattedDate = "${pickedDate.year.toString().padLeft(4, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
        final formattedTime = "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
        cmd = 'SET:$index,$formattedDate $formattedTime';
      }

      if (cmd.isNotEmpty) {
        await _bleService.sendAlarmCommand(cmd);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setting Alarm $index...')),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        await _bleService.readAlarmState();
      }
    }
  }

  // アラーム削除
  Future<void> _deleteAlarm(int index) async {
    final cmd = 'DEL:$index';
    await _bleService.sendAlarmCommand(cmd);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleting Alarm $index...')),
    );
    await Future.delayed(const Duration(milliseconds: 500));
    await _bleService.readAlarmState();
  }

  // 特定スロット（または -1 = trigger）への音声の選択、自動変換とアップロード
  Future<void> _uploadAudioForSlot(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a', 'aac', 'ogg'],
    );

    if (result != null && result.files.single.path != null) {
      final inputPath = result.files.single.path!;
      
      setState(() {
        _isUploading[index] = true;
        _uploadProgress[index] = 0.0;
        _uploadStatusMessage = 'Converting to 16kHz WAV...';
      });

      // 推奨WAVフォーマットへの自動トランスコードを実行
      final convertedFile = await AudioService.convertToRecommendedWav(inputPath);

      if (convertedFile != null) {
        setState(() {
          _uploadStatusMessage = 'Uploading...';
        });

        try {
          final bytes = await convertedFile.readAsBytes();
          // 対象のファイル名を設定（indexが-1なら trigger.wav、それ以外は alarm$index.wav）
          final targetFilename = index == -1 ? 'trigger.wav' : 'alarm$index.wav';
          await _bleService.transferFile(targetFilename, bytes);
          
          // 一時ファイルを削除
          try {
            await convertedFile.delete();
          } catch (_) {}
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
          );
          setState(() {
            _isUploading[index] = false;
          });
        }
      } else {
        setState(() {
          _isUploading[index] = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to convert audio file to recommended format.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTriggerUploading = _isUploading[-1] ?? false;
    final triggerProgress = _uploadProgress[-1] ?? 0.0;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _bleService.disconnect();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text('Alarm & Sound Manager', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _bleService.disconnect();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.indigoAccent),
              onPressed: () {
                _bleService.readAlarmState();
                _fetchDeviceTime();
                _fetchLedBrightness();
              },
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
        child: _bleService.connectedDevice == null
            ? const Center(
                child: Text(
                  'Please connect to ConnectedDoll2 board\nin the Scan Screen first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    // --- デバイス現在時刻表示カード ---
                    Card(
                      color: Colors.white.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1.0,
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Device Current Time',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _deviceTime,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: _syncDeviceTime,
                              icon: const Icon(Icons.sync, size: 16, color: Colors.white),
                              label: const Text('Sync', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                side: const BorderSide(color: Colors.indigoAccent, width: 0.8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- LED明るさ調整カード ---
                    Card(
                      color: Colors.white.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1.0,
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.lightbulb, color: Colors.yellowAccent, size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'LED Brightness',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${((_ledBrightness / 255.0) * 100).round()}%',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Slider(
                              value: _ledBrightness,
                              min: 0.0,
                              max: 255.0,
                              activeColor: Colors.indigoAccent,
                              inactiveColor: Colors.white10,
                              onChanged: (value) {
                                setState(() {
                                  _ledBrightness = value;
                                });
                              },
                              onChangeEnd: (value) {
                                _updateLedBrightness(value);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- タクトスイッチ再生音 (trigger.wav) 設定カード ---
                    Card(
                      color: Colors.indigo.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: Colors.indigoAccent, width: 1.2),
                      ),
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.touch_app, color: Colors.orangeAccent, size: 24),
                                const SizedBox(width: 10),
                                const Text(
                                  'Tact Switch Sound Settings',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '本体のタクトスイッチを押した際に再生される音声を変更できます。',
                              style: TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 8),
                            if (isTriggerUploading)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _uploadStatusMessage,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                      Text(
                                        '${(triggerProgress * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: triggerProgress,
                                    color: Colors.orangeAccent,
                                    backgroundColor: Colors.white10,
                                  ),
                                ],
                              )
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Linked Audio: trigger.wav',
                                      style: TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _isUploading.values.any((u) => u) ? null : () => _uploadAudioForSlot(-1),
                                    icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
                                    label: const Text('Upload Sound', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E293B),
                                      side: const BorderSide(color: Colors.orangeAccent, width: 0.8),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    const Text(
                      'Alarm Schedule Settings',
                      style: TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // --- アラームスケジュール一覧 (0〜4) ---
                    ...List.generate(_slots.length, (index) {
                      final slot = _slots[index];
                      final isSlotUploading = _isUploading[index] ?? false;
                      final slotProgress = _uploadProgress[index] ?? 0.0;

                      return Card(
                        color: Colors.white.withValues(alpha: 0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.alarm, color: Colors.indigoAccent, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Alarm Slot $index',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        slot.dateTimeStr.startsWith("DAILY")
                                            ? slot.dateTimeStr.replaceAll("DAILY", "毎日")
                                            : slot.dateTimeStr,
                                        style: TextStyle(
                                          color: slot.isEnabled ? Colors.white : Colors.white38,
                                          fontSize: 22,
                                          fontWeight: slot.isEnabled ? FontWeight.bold : FontWeight.normal,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.indigoAccent),
                                        onPressed: () => _selectDateTime(index),
                                      ),
                                      if (slot.isEnabled)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                          onPressed: () => _deleteAlarm(index),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 12),
                              const Divider(color: Colors.white10),
                              const SizedBox(height: 8),

                              // アラーム音声アップロード機能
                              if (isSlotUploading)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _uploadStatusMessage,
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                        Text(
                                          '${(slotProgress * 100).toStringAsFixed(1)}%',
                                          style: const TextStyle(color: Colors.indigoAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: slotProgress,
                                      color: Colors.indigoAccent,
                                      backgroundColor: Colors.white10,
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Linked Audio: alarm$index.wav',
                                        style: const TextStyle(color: Colors.indigoAccent, fontSize: 13),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: _isUploading.values.any((u) => u) ? null : () => _uploadAudioForSlot(index),
                                      icon: const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
                                      label: const Text('Upload Sound', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E293B),
                                        side: const BorderSide(color: Colors.indigoAccent, width: 0.8),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
      ),
    ),
    );
  }
}

class AlarmSlot {
  final int index;
  bool isEnabled;
  String dateTimeStr;

  AlarmSlot({
    required this.index,
    this.isEnabled = false,
    this.dateTimeStr = "Not Set",
  });
}
