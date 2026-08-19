import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/ble_service.dart';
import '../services/audio_service.dart';
import '../services/preset_db_service.dart';
import '../services/audio_player_service.dart';
import '../models/voice_preset.dart';
import '../widgets/device_selection_bottom_sheet.dart';

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
  String _deviceTime = 'Not Synced';
  double _ledBrightness = 128.0;
  Color _ledColor = const Color(0xFF4F46E5);

  List<VoicePreset> _presets = [];
  VoicePreset? _selectedPreset;


  // デバイス未接続時に下部トースト（ボトムシート）を表示して接続を促す共通処理
  Future<bool> _ensureConnected() async {
    if (_bleService.connectedDevice != null) {
      return true;
    }

    final connected = await DeviceSelectionBottomSheet.show(context);
    if (connected && mounted) {
      setState(() {});
      // 接続成功後に本体状態を同期
      await _fetchDeviceTime();
      await _fetchLedBrightness();
      await _fetchLedColor();
      await _bleService.readAlarmState();
      return true;
    }
    return false;
  }

  Future<void> _fetchDeviceTime() async {
    if (_bleService.connectedDevice == null) return;
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
    if (!await _ensureConnected()) return;
    if (!mounted) return;
    setState(() {
      _deviceTime = 'Syncing...';
    });
    await _bleService.syncTime();
    await _fetchDeviceTime();
  }

  Future<void> _fetchLedBrightness() async {
    if (_bleService.connectedDevice == null) return;
    final bright = await _bleService.readLedBrightness();
    if (bright != null && mounted) {
      setState(() {
        _ledBrightness = bright.toDouble();
      });
    }
  }

  Future<void> _fetchLedColor() async {
    if (_bleService.connectedDevice == null) return;
    final color = await _bleService.readLedColor();
    if (color != null && mounted) {
      setState(() {
        _ledColor = color;
      });
    }
  }

  Future<void> _updateLedBrightness(double value) async {
    setState(() {
      _ledBrightness = value;
    });
    if (!await _ensureConnected()) return;
    await _bleService.writeLedBrightness(value.round());
  }

  Future<void> _updateLedColor(Color color) async {
    setState(() {
      _ledColor = color;
    });
    if (!await _ensureConnected()) return;
    await _bleService.writeLedColor(color);
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
    _fetchLedColor();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final list = await PresetDbService.instance.getAllPresets();
    if (mounted) {
      setState(() {
        _presets = list;
        if (_presets.isNotEmpty && _selectedPreset == null) {
          _selectedPreset = _presets.first;
        } else if (_selectedPreset != null) {
          // 更新後のオブジェクトに同期
          final match = _presets.where((p) => p.id == _selectedPreset!.id);
          _selectedPreset = match.isNotEmpty ? match.first : (_presets.isNotEmpty ? _presets.first : null);
        }
      });
    }
  }

  @override
  void dispose() {
    AudioPlayerService.instance.stop();
    _alarmSubscription?.cancel();
    _progressSubscription?.cancel();
    _statusSubscription?.cancel();
    // 画面破棄時にBLE切断を実行
    if (_bleService.connectedDevice != null) {
      _bleService.disconnect();
    }
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
    if (!await _ensureConnected()) return;

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
    if (!await _ensureConnected()) return;

    final cmd = 'DEL:$index';
    await _bleService.sendAlarmCommand(cmd);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleting Alarm $index...')),
    );
    await Future.delayed(const Duration(milliseconds: 500));
    await _bleService.readAlarmState();
  }

  // 指定パスの音声ファイルをトランスコードしてBLE転送する共通処理
  Future<bool> _uploadAudioFromPath(int slotIndex, String inputPath) async {
    if (!await _ensureConnected()) return false;

    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登録された音声ファイルが見つかりません。')),
        );
      }
      return false;
    }


    setState(() {
      _isUploading[slotIndex] = true;
      _uploadProgress[slotIndex] = 0.0;
      _uploadStatusMessage = 'Converting to 16kHz WAV...';
    });

    final convertedFile = await AudioService.convertToRecommendedWav(inputPath);
    if (convertedFile != null) {
      setState(() {
        _uploadStatusMessage = 'Uploading...';
      });

      try {
        final bytes = await convertedFile.readAsBytes();
        final targetFilename = slotIndex == -1 ? 'trigger.wav' : 'alarm$slotIndex.wav';
        await _bleService.transferFile(targetFilename, bytes);

        try {
          await convertedFile.delete();
        } catch (_) {}
        return true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
          );
        }
        setState(() {
          _isUploading[slotIndex] = false;
        });
        return false;
      }
    } else {
      setState(() {
        _isUploading[slotIndex] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to convert audio file.')),
        );
      }
      return false;
    }
  }

  // 選択中プリセットの特定スロット音声を転送
  Future<void> _uploadPresetAudioForSlot(int slotIndex) async {
    if (_selectedPreset == null) return;
    final filePath = _selectedPreset!.audioFiles[slotIndex];
    if (filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('このスロットにはプリセット音声が設定されていません。')),
      );
      return;
    }

    await _uploadAudioFromPath(slotIndex, filePath);
  }

  // 特定スロット（または -1 = trigger）への音声の選択、自動変換とアップロード
  Future<void> _uploadAudioForSlot(int index) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a', 'aac', 'ogg'],
    );

    if (result != null && result.files.single.path != null) {
      await _uploadAudioFromPath(index, result.files.single.path!);
    }
  }


  @override
  Widget build(BuildContext context) {
    final isTriggerUploading = _isUploading[-1] ?? false;
    final triggerProgress = _uploadProgress[-1] ?? 0.0;
    final connectedDevice = _bleService.connectedDevice;
    final isConnected = connectedDevice != null;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (_bleService.connectedDevice != null) {
          await _bleService.disconnect();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          title: const Text('デバイス設定・転送', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (_bleService.connectedDevice != null) {
                await _bleService.disconnect();
              }
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.indigoAccent),
              tooltip: '本体状態を再読み込み',
              onPressed: isConnected
                  ? () {
                      _bleService.readAlarmState();
                      _fetchDeviceTime();
                      _fetchLedBrightness();
                    }
                  : () => _ensureConnected(),
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
          child: ListView(
            children: [
              // --- 接続状態カード ---
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isConnected
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isConnected
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected ? const Color(0xFF10B981) : Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isConnected ? '接続済み: ${connectedDevice.name ?? "CD2"}' : '未接続 (操作時に自動接続)',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                          ),
                          if (isConnected)
                            Text(
                              connectedDevice.deviceId,
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                    if (isConnected)
                      TextButton(
                        onPressed: () async {
                          await _bleService.disconnect();
                          setState(() {
                            _deviceTime = 'Not Synced';
                          });
                        },
                        child: const Text('切断', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _ensureConnected(),
                        child: const Text('接続する', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                  ],
                ),
              ),

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

                    // --- LED 設定カード (明るさ & 推しカラー) ---
                    Card(
                      color: _ledColor.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: _ledColor.withValues(alpha: 0.35),
                          width: 1.2,
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
                                    Icon(Icons.lightbulb_rounded, color: _ledColor, size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'LED Settings',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
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
                              activeColor: _ledColor,
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
                            const SizedBox(height: 8),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: _ledColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _ledColor.withValues(alpha: 0.6),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '推しカラー (LED色)',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                if (_selectedPreset != null)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _updateLedColor(Color(_selectedPreset!.color));
                                    },
                                    icon: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Color(_selectedPreset!.color),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    label: const Text('プリセット色を適用', style: TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E293B),
                                      side: BorderSide(color: Color(_selectedPreset!.color), width: 0.8),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // クイックカラー選択パレット
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: const [
                                Color(0xFF4F46E5), // Indigo
                                Color(0xFFEC4899), // Pink
                                Color(0xFFEF4444), // Red
                                Color(0xFFF97316), // Orange
                                Color(0xFFEAB308), // Yellow
                                Color(0xFF10B981), // Emerald
                                Color(0xFF06B6D4), // Cyan
                                Color(0xFF3B82F6), // Blue
                                Color(0xFF8B5CF6), // Purple
                              ].map((c) {
                                final isSelected = (_ledColor.r * 255).round() == (c.r * 255).round() &&
                                    (_ledColor.g * 255).round() == (c.g * 255).round() &&
                                    (_ledColor.b * 255).round() == (c.b * 255).round();
                                return GestureDetector(
                                  onTap: () => _updateLedColor(c),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? Colors.white : Colors.transparent,
                                        width: isSelected ? 2.5 : 0,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: c.withValues(alpha: 0.8),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- ボイスプリセット選択 & 一括転送カード ---
                    Card(
                      color: _selectedPreset != null
                          ? Color(_selectedPreset!.color).withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: _selectedPreset != null
                              ? Color(_selectedPreset!.color).withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.1),
                          width: 1.2,
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.library_music_rounded,
                                      color: _selectedPreset != null
                                          ? Color(_selectedPreset!.color)
                                          : Colors.indigoAccent,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'ボイスプリセット',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_presets.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<VoicePreset>(
                                        value: _selectedPreset,
                                        isDense: true,
                                        dropdownColor: const Color(0xFF1E293B),
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        items: _presets.map((preset) {
                                          return DropdownMenuItem<VoicePreset>(
                                            value: preset,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: Color(preset.color),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(preset.name),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: _isUploading.values.any((u) => u)
                                            ? null
                                            : (val) {
                                                setState(() {
                                                  _selectedPreset = val;
                                                });
                                              },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_presets.isEmpty)
                              const Text(
                                '登録されたプリセットがありません。「音声プリセット一覧」画面から作成してください。',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              )
                            else
                              Text(
                                '選択中: ${_selectedPreset?.name ?? ""} (${_selectedPreset?.audioFiles.length ?? 0}件の音声が登録済み)\n各スロットの「プリセットから転送」ボタンで個別に転送できます。',
                                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.audiotrack, size: 16, color: Colors.orangeAccent),
                                      SizedBox(width: 6),
                                      Text(
                                        'Linked Audio: trigger.wav',
                                        style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (_selectedPreset != null && _selectedPreset!.audioFiles.containsKey(-1)) ...[
                                        ValueListenableBuilder<String?>(
                                          valueListenable: AudioPlayerService.instance.playingTagNotifier,
                                          builder: (context, playingTag, _) {
                                            final tag = "alarm_screen_slot_-1";
                                            final isPlaying = playingTag == tag;
                                            return ElevatedButton.icon(
                                              onPressed: () {
                                                final path = _selectedPreset!.audioFiles[-1]!;
                                                AudioPlayerService.instance.togglePlay(path, tag: tag);
                                              },
                                              icon: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 15, color: Colors.orangeAccent),
                                              label: Text(isPlaying ? "停止" : "試聴", style: const TextStyle(fontSize: 11, color: Colors.orangeAccent)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF1E293B),
                                                side: const BorderSide(color: Colors.orangeAccent, width: 0.8),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            );
                                          },
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: _isUploading.values.any((u) => u)
                                              ? null
                                              : () => _uploadPresetAudioForSlot(-1),
                                          icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                                          label: const Text('プリセットから転送', style: TextStyle(fontSize: 11)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(_selectedPreset!.color),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                      ElevatedButton.icon(
                                        onPressed: _isUploading.values.any((u) => u) ? null : () => _uploadAudioForSlot(-1),
                                        icon: const Icon(Icons.folder_open, size: 14, color: Colors.white70),
                                        label: const Text('ファイル選択', style: TextStyle(fontSize: 11)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1E293B),
                                          side: const BorderSide(color: Colors.orangeAccent, width: 0.8),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ],
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.audiotrack, size: 16, color: Colors.indigoAccent),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Linked Audio: alarm$index.wav',
                                        style: const TextStyle(color: Colors.indigoAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (_selectedPreset != null && _selectedPreset!.audioFiles.containsKey(index)) ...[
                                        ValueListenableBuilder<String?>(
                                          valueListenable: AudioPlayerService.instance.playingTagNotifier,
                                          builder: (context, playingTag, _) {
                                            final tag = "alarm_screen_slot_$index";
                                            final isPlaying = playingTag == tag;
                                            return ElevatedButton.icon(
                                              onPressed: () {
                                                final path = _selectedPreset!.audioFiles[index]!;
                                                AudioPlayerService.instance.togglePlay(path, tag: tag);
                                              },
                                              icon: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 15, color: Colors.indigoAccent),
                                              label: Text(isPlaying ? "停止" : "試聴", style: const TextStyle(fontSize: 11, color: Colors.indigoAccent)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF1E293B),
                                                side: const BorderSide(color: Colors.indigoAccent, width: 0.8),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            );
                                          },
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: _isUploading.values.any((u) => u)
                                              ? null
                                              : () => _uploadPresetAudioForSlot(index),
                                          icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                                          label: const Text('プリセットから転送', style: TextStyle(fontSize: 11)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(_selectedPreset!.color),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                      ElevatedButton.icon(
                                        onPressed: _isUploading.values.any((u) => u) ? null : () => _uploadAudioForSlot(index),
                                        icon: const Icon(Icons.folder_open, size: 14, color: Colors.white70),
                                        label: const Text('ファイル選択', style: TextStyle(fontSize: 11)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1E293B),
                                          side: const BorderSide(color: Colors.indigoAccent, width: 0.8),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ],
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
