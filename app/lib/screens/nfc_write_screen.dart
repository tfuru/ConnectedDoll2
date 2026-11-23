import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/voice_preset.dart';
import '../services/nfc_audio_transfer_service.dart';
import '../services/nfc_service.dart';
import '../services/nfc_uuid_service.dart';
import '../services/preset_db_service.dart';
import 'preset_list_screen.dart';

class NfcWriteScreen extends StatefulWidget {
  final NfcTagGateway? nfcService;
  final NfcUuidService? uuidService;
  final NfcAudioTransferGateway? transferGateway;
  final Future<List<VoicePreset>> Function()? loadPresets;
  final Future<void> Function(int presetId, String nfcUuid)? savePresetUuid;
  final Duration interFileTransferDelay;

  const NfcWriteScreen({
    super.key,
    this.nfcService,
    this.uuidService,
    this.transferGateway,
    this.loadPresets,
    this.savePresetUuid,
    this.interFileTransferDelay = const Duration(milliseconds: 600),
  });

  @override
  State<NfcWriteScreen> createState() => _NfcWriteScreenState();
}

class _NfcWriteScreenState extends State<NfcWriteScreen> {
  static const Color _bgColor = Color(0xFF0F172A);
  static const Color _cardColor = Color(0xFF1E293B);
  static const Color _accentColor = Color(0xFF10B981);
  static const Color _bleAccentColor = Color(0xFF6366F1);

  late final NfcUuidService _uuidService;
  late final NfcTagGateway _nfcService;
  late final NfcAudioTransferGateway _transferGateway;

  StreamSubscription<double>? _transferProgressSub;
  StreamSubscription<String>? _transferStatusSub;

  List<VoicePreset> _presets = [];
  int? _selectedPresetIndex;
  NfcReaderStatus _nfcStatus = NfcReaderStatus.available;
  bool _isLoading = true;
  bool _isScanning = false;
  bool _isTransferring = false;

  int _transferCurrentIndex = 0;
  int _transferTotalCount = 0;
  String _transferCurrentPresetName = '';
  double _currentFileProgress = 0.0;
  String _transferStatusMessage = '';
  BatchAudioTransferResult? _lastTransferResult;

  NfcWriteResult? _lastWriteResult;
  String? _lastErrorMessage;

  bool get _isBusy => _isScanning || _isTransferring;

  VoicePreset? get _selectedPreset {
    final idx = _selectedPresetIndex;
    if (idx == null || idx < 0 || idx >= _presets.length) return null;
    return _presets[idx];
  }

  @override
  void initState() {
    super.initState();
    _uuidService = widget.uuidService ?? const NfcUuidService();
    _nfcService = widget.nfcService ?? NfcService(uuidService: _uuidService);
    _transferGateway =
        widget.transferGateway ?? BleNfcAudioTransferGateway();

    _transferProgressSub =
        _transferGateway.transferProgressStream.listen((progress) {
      if (!mounted) return;
      setState(() => _currentFileProgress = progress);
    });
    _transferStatusSub =
        _transferGateway.transferStatusStream.listen((status) {
      if (!mounted) return;
      setState(() => _transferStatusMessage = status);
    });

    _initialize();
  }

  @override
  void dispose() {
    _transferProgressSub?.cancel();
    _transferStatusSub?.cancel();
    if (_isScanning) {
      _nfcService.cancelSession();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    final previousSelectedId = _selectedPreset?.id;
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _loadPresetsFromStore(),
      _nfcService.checkAvailability(),
    ]);

    if (!mounted) return;
    final loadedPresets = List<VoicePreset>.from(
      results[0] as List<VoicePreset>,
    );
    final status = results[1] as NfcReaderStatus;

    int? nextSelectedIndex;
    if (loadedPresets.isNotEmpty) {
      if (previousSelectedId != null) {
        final matchIndex =
            loadedPresets.indexWhere((p) => p.id == previousSelectedId);
        nextSelectedIndex = matchIndex >= 0 ? matchIndex : 0;
      } else {
        nextSelectedIndex = 0;
      }
    }

    setState(() {
      _presets = loadedPresets;
      _selectedPresetIndex = nextSelectedIndex;
      _nfcStatus = status;
      _isLoading = false;
    });

    if (nextSelectedIndex != null) {
      await _ensurePresetUuidAtIndex(nextSelectedIndex);
    }
  }

  Future<List<VoicePreset>> _loadPresetsFromStore() {
    if (widget.loadPresets != null) {
      return widget.loadPresets!();
    }
    return PresetDbService.instance.getAllPresets();
  }

  Future<void> _persistPresetUuid(int presetId, String nfcUuid) async {
    if (widget.savePresetUuid != null) {
      await widget.savePresetUuid!(presetId, nfcUuid);
      return;
    }
    await PresetDbService.instance.updateNfcUuid(presetId, nfcUuid);
  }

  Future<void> _refreshNfcStatus() async {
    final status = await _nfcService.checkAvailability();
    if (!mounted) return;
    setState(() => _nfcStatus = status);
  }

  String? _triggerAudioPath(VoicePreset preset) {
    final path = preset.audioFiles[-1];
    if (path == null || path.isEmpty) return null;
    return path;
  }

  List<int> get _transferablePresetIndices {
    final indices = <int>[];
    for (int i = 0; i < _presets.length; i++) {
      if (_triggerAudioPath(_presets[i]) != null) {
        indices.add(i);
      }
    }
    return indices;
  }

  Future<VoicePreset> _ensurePresetUuidAtIndex(int index) async {
    final preset = _presets[index];
    final currentUuid = preset.nfcUuid;
    if (currentUuid != null && _uuidService.isValidUuid(currentUuid)) {
      return preset;
    }

    final newUuid = _uuidService.generateUuid();
    if (preset.id != null) {
      await _persistPresetUuid(preset.id!, newUuid);
    }
    final updated = preset.copyWith(nfcUuid: newUuid);
    if (mounted && index >= 0 && index < _presets.length) {
      setState(() {
        final next = List<VoicePreset>.from(_presets);
        next[index] = updated;
        _presets = next;
      });
    }
    return updated;
  }

  Future<void> _selectPresetAtIndex(int index) async {
    if (index < 0 || index >= _presets.length) return;
    setState(() {
      _selectedPresetIndex = index;
      _lastErrorMessage = null;
    });
    await _ensurePresetUuidAtIndex(index);
  }

  Future<void> _regenerateUuid() async {
    final idx = _selectedPresetIndex;
    final current = _selectedPreset;
    if (idx == null || current == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text(
          'UUIDを再発行しますか？',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '「${current.name}」に新しいUUIDを割り当てます。\n'
          '以前書き込んだNFCタグのUUIDとは一致しなくなるため、タグの再書き込みとトリガー音声の再転送が必要になります。',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accentColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('再発行する'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final newUuid = _uuidService.generateUuid();
    if (current.id != null) {
      await _persistPresetUuid(current.id!, newUuid);
    }
    final updated = current.copyWith(nfcUuid: newUuid);

    if (!mounted || idx >= _presets.length) return;
    setState(() {
      final next = List<VoicePreset>.from(_presets);
      next[idx] = updated;
      _presets = next;
      _lastErrorMessage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('新しいUUIDを発行して保存しました')),
    );
  }

  Future<void> _copyUuid(String uuid) async {
    await Clipboard.setData(ClipboardData(text: uuid));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('UUIDをクリップボードにコピーしました')),
    );
  }

  Future<void> _connectBleDevice() async {
    if (_isBusy) return;
    await _transferGateway.ensureConnected(context);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _disconnectBleDevice() async {
    if (_isBusy) return;
    await _transferGateway.disconnect();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _transferPresetIndices(
    List<int> targetIndices, {
    int skippedNoAudioCount = 0,
  }) async {
    if (_isBusy) return;
    if (targetIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('転送可能なトリガー音声が登録されていません')),
      );
      return;
    }

    final connected = await _transferGateway.ensureConnected(context);
    if (!mounted || !connected) return;

    setState(() {
      _isTransferring = true;
      _transferTotalCount = targetIndices.length;
      _transferCurrentIndex = 0;
      _transferCurrentPresetName = '';
      _currentFileProgress = 0.0;
      _transferStatusMessage = '転送準備中...';
      _lastTransferResult = null;
      _lastErrorMessage = null;
    });

    final results = <PresetAudioTransferItemResult>[];
    try {
      for (int i = 0; i < targetIndices.length; i++) {
        if (!mounted) break;
        final presetIndex = targetIndices[i];
        if (presetIndex < 0 || presetIndex >= _presets.length) continue;

        final ensured = await _ensurePresetUuidAtIndex(presetIndex);
        final uuid = ensured.nfcUuid!;
        final sourcePath = _triggerAudioPath(ensured)!;
        final devicePath = _uuidService.buildDeviceTriggerAudioPath(uuid);

        if (!mounted) break;
        setState(() {
          _transferCurrentIndex = i + 1;
          _transferCurrentPresetName = ensured.name;
          _currentFileProgress = 0.0;
          _transferStatusMessage = '変換・転送中...';
        });

        bool ok = false;
        String? err;
        try {
          ok = await _transferGateway.transferTriggerAudio(
            devicePath: devicePath,
            sourceFilePath: sourcePath,
          );
          if (!ok) {
            err = _transferStatusMessage.isNotEmpty
                ? _transferStatusMessage
                : '転送に失敗しました';
          }
        } catch (e) {
          ok = false;
          err = e.toString();
        }

        results.add(
          PresetAudioTransferItemResult(
            presetName: ensured.name,
            uuid: uuid,
            devicePath: devicePath,
            success: ok,
            errorMessage: err,
          ),
        );

        if (i < targetIndices.length - 1 &&
            widget.interFileTransferDelay > Duration.zero) {
          await Future.delayed(widget.interFileTransferDelay);
        }
      }
    } finally {
      if (mounted) {
        final summary = BatchAudioTransferResult(
          items: results,
          skippedNoAudioCount: skippedNoAudioCount,
        );
        setState(() {
          _isTransferring = false;
          _transferCurrentIndex = 0;
          _transferTotalCount = 0;
          _transferCurrentPresetName = '';
          _currentFileProgress = 0.0;
          _lastTransferResult = summary;
        });

        if (results.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: summary.allSucceeded
                  ? const Color(0xFF065F46)
                  : Colors.orange.shade800,
              content: Text(
                summary.allSucceeded
                    ? 'トリガー音声を ${summary.successCount} 件デバイスへ転送しました'
                    : '転送完了: 成功 ${summary.successCount} 件 / 失敗 ${summary.failureCount} 件',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _transferSelectedPresetAudio() async {
    final idx = _selectedPresetIndex;
    final preset = _selectedPreset;
    if (idx == null || preset == null) return;
    if (_triggerAudioPath(preset) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${preset.name}」にはトリガー音声が登録されていません')),
      );
      return;
    }
    await _transferPresetIndices([idx]);
  }

  Future<void> _transferAllPresetAudios() async {
    final targetIndices = _transferablePresetIndices;
    final skipped = _presets.length - targetIndices.length;
    await _transferPresetIndices(targetIndices, skippedNoAudioCount: skipped);
  }

  Future<void> _startWriteTag() async {
    final idx = _selectedPresetIndex;
    if (idx == null || _isBusy) return;

    final target = await _ensurePresetUuidAtIndex(idx);
    final uuid = target.nfcUuid;
    if (uuid == null || uuid.isEmpty) return;

    await _runNfcSession<NfcWriteResult>(
      title: 'NFCタグへ書き込み中',
      subtitle: '「${target.name}」のUUIDを書き込むNFCタグを端末背面にかざしてください',
      operation: () => _nfcService.writePresetTag(
        uuid: uuid,
        presetName: target.name,
      ),
      onSuccess: (result) async {
        if (!mounted) return;
        setState(() {
          _lastWriteResult = result;
          _lastErrorMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF065F46),
            content: Text('「${result.payload.name}」のUUIDをNFCタグに書き込みました'),
          ),
        );
      },
    );
  }

  Future<void> _runNfcSession<T>({
    required String title,
    required String subtitle,
    required Future<T> Function() operation,
    required Future<void> Function(T result) onSuccess,
  }) async {
    setState(() {
      _isScanning = true;
      _lastErrorMessage = null;
    });

    var sheetOpen = true;
    final sheetFuture = showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _nfcService.cancelSession();
            }
          },
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(color: _accentColor, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.nfc_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(
                    color: _accentColor,
                    backgroundColor: Colors.white12,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        _nfcService.cancelSession();
                      },
                      child: const Text('キャンセル'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      sheetOpen = false;
    });

    try {
      final result = await operation();
      if (mounted && sheetOpen) {
        Navigator.of(context).pop();
      }
      await sheetFuture;
      await onSuccess(result);
    } on NfcOperationException catch (e) {
      if (mounted && sheetOpen) {
        Navigator.of(context).pop();
      }
      await sheetFuture;
      if (!mounted) return;
      if (e.kind == NfcErrorKind.disabled ||
          e.kind == NfcErrorKind.notSupported) {
        await _refreshNfcStatus();
      }
      if (!mounted) return;
      if (e.kind != NfcErrorKind.cancelled) {
        setState(() => _lastErrorMessage = e.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted && sheetOpen) {
        Navigator.of(context).pop();
      }
      await sheetFuture;
      if (!mounted) return;
      setState(() => _lastErrorMessage = 'NFC処理中にエラーが発生しました: $e');
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canUseNfc = _nfcStatus == NfcReaderStatus.available && !_isBusy;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'NFC書き込み',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '状態を更新',
            onPressed: _isBusy ? null : _initialize,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _accentColor),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildNfcStatusBanner(),
                    const SizedBox(height: 16),
                    _buildWriteCard(canUseNfc),
                    const SizedBox(height: 16),
                    _buildAudioTransferCard(),
                    if (_lastErrorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBanner(_lastErrorMessage!),
                    ],
                    if (_lastWriteResult != null) ...[
                      const SizedBox(height: 16),
                      _buildWriteResultCard(_lastWriteResult!),
                    ],
                    if (_lastTransferResult != null) ...[
                      const SizedBox(height: 16),
                      _buildTransferResultCard(_lastTransferResult!),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNfcStatusBanner() {
    late final Color borderColor;
    late final Color bgColor;
    late final IconData icon;
    late final String title;
    late final String message;

    switch (_nfcStatus) {
      case NfcReaderStatus.available:
        borderColor = _accentColor.withValues(alpha: 0.45);
        bgColor = _accentColor.withValues(alpha: 0.10);
        icon = Icons.nfc_rounded;
        title = 'NFC 利用可能';
        message = 'プルダウンで音声プリセットを選択して「NFCタグに書き込む」を押してください。';
        break;
      case NfcReaderStatus.disabled:
        borderColor = Colors.amber.withValues(alpha: 0.55);
        bgColor = Colors.amber.withValues(alpha: 0.12);
        icon = Icons.warning_amber_rounded;
        title = 'NFC がオフになっています';
        message = '端末の設定から NFC を有効にしたあと、右上の更新ボタンを押してください。';
        break;
      case NfcReaderStatus.notSupported:
        borderColor = Colors.redAccent.withValues(alpha: 0.55);
        bgColor = Colors.redAccent.withValues(alpha: 0.12);
        icon = Icons.block_rounded;
        title = 'この端末は NFC に対応していません';
        message = 'NFC 搭載の Android 端末でお試しください（UUID の発行・音声転送のみ可能です）。';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWriteCard(bool canUseNfc) {
    final selected = _selectedPreset;
    final canWrite = canUseNfc && selected != null;
    final accentTint = selected != null ? Color(selected.color) : _accentColor;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: selected != null
            ? accentTint.withValues(alpha: 0.10)
            : _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected != null
              ? accentTint.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.library_music_rounded, color: accentTint, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '1. NFCタグに書き込む',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'プルダウンから音声プリセットを選び、紐づくUUIDをNFCタグへ書き込みます。',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (_presets.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  const Text(
                    '登録済みの音声プリセットがありません',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEC4899),
                      side: const BorderSide(color: Color(0xFFEC4899)),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PresetListScreen(),
                        ),
                      );
                      if (mounted) {
                        await _initialize();
                      }
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('音声プリセット一覧へ'),
                  ),
                ],
              ),
            )
          else ...[
            const Text(
              '音声プリセット',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentTint.withValues(alpha: 0.45),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedPresetIndex,
                  isExpanded: true,
                  dropdownColor: _cardColor,
                  iconEnabledColor: Colors.white70,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  items: List<DropdownMenuItem<int>>.generate(
                    _presets.length,
                    (index) {
                      final preset = _presets[index];
                      final hasAudio = _triggerAudioPath(preset) != null;
                      return DropdownMenuItem<int>(
                        value: index,
                        child: Row(
                          children: [
                            Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: Color(preset.color),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                preset.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              hasAudio
                                  ? Icons.graphic_eq_rounded
                                  : Icons.volume_off_rounded,
                              size: 15,
                              color: hasAudio
                                  ? const Color(0xFF818CF8)
                                  : Colors.white24,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  onChanged: _isBusy
                      ? null
                      : (idx) {
                          if (idx != null) {
                            _selectPresetAtIndex(idx);
                          }
                        },
                ),
              ),
            ),
            if (selected != null) ...[
              const SizedBox(height: 14),
              _buildSelectedPresetDetails(selected),
            ],
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white12,
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: canWrite ? _startWriteTag : null,
            icon: const Icon(Icons.nfc_rounded),
            label: const Text(
              'NFCタグに書き込む',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPresetDetails(VoicePreset preset) {
    final uuid = preset.nfcUuid ?? '';
    final hasValidUuid = _uuidService.isValidUuid(uuid);
    final jsonPreview = hasValidUuid
        ? _uuidService.encodePayloadJson(uuid: uuid, name: preset.name)
        : '';
    final byteSize = hasValidUuid
        ? _uuidService.estimateNdefRecordBytes(uuid: uuid, name: preset.name)
        : 0;
    final exceedsNtag213 = byteSize > NfcUuidService.ntag213RecommendedMaxBytes;
    final deviceAudioPath = hasValidUuid
        ? '/${_uuidService.buildDeviceTriggerAudioPath(uuid)}'
        : '';
    final hasTriggerAudio = _triggerAudioPath(preset) != null;
    final triggerAudioName =
        hasTriggerAudio ? preset.getAudioFileName(-1) : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint_rounded,
                  color: _accentColor, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '書き込むUUID・保存先',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 30),
                ),
                onPressed: _isBusy ? null : _regenerateUuid,
                icon: const Icon(Icons.autorenew_rounded, size: 15),
                label: const Text('再発行', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    uuid,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded,
                      color: Colors.white70, size: 17),
                  tooltip: 'UUIDをコピー',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: hasValidUuid ? () => _copyUuid(uuid) : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'MIME Type: ${NfcUuidService.presetMimeType}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Payload: $jsonPreview',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          if (deviceAudioPath.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'デバイス保存先: $deviceAudioPath',
              style: const TextStyle(
                color: Color(0xFF818CF8),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            hasTriggerAudio
                ? '紐づけトリガー音声: ${triggerAudioName ?? '登録済み'}'
                : '紐づけトリガー音声: 未登録（音声プリセット編集画面で登録してください）',
            style: TextStyle(
              color: hasTriggerAudio ? Colors.white70 : Colors.amber.shade300,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                exceedsNtag213
                    ? Icons.info_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 14,
                color: exceedsNtag213 ? Colors.amber : _accentColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  exceedsNtag213
                      ? 'NDEFサイズ: ${byteSize}B（NTAG213容量上限目安137B超過のためNTAG215/216等を推奨）'
                      : 'NDEFサイズ: ${byteSize}B（NTAG213 / 215 / 216 対応）',
                  style: TextStyle(
                    color: exceedsNtag213 ? Colors.amber : Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioTransferCard() {
    final transferableIndices = _transferablePresetIndices;
    final transferableCount = transferableIndices.length;
    final selectedHasTriggerAudio =
        _selectedPreset != null && _triggerAudioPath(_selectedPreset!) != null;
    final isConnected = _transferGateway.isConnected;
    final deviceName = _transferGateway.connectedDeviceName ?? 'ConnectedDoll2';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _bleAccentColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.bluetooth_audio_rounded,
                  color: Color(0xFF818CF8), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '2. トリガー音声をデバイスへ転送',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '各プリセットのトリガー音声を UUID に紐づけて /nfc/<UUID>.wav としてデバイスへ保存します（対象: $transferableCount / ${_presets.length} プリセット）。',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isConnected
                    ? _accentColor.withValues(alpha: 0.45)
                    : Colors.orange.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isConnected
                      ? Icons.bluetooth_connected_rounded
                      : Icons.bluetooth_disabled_rounded,
                  color: isConnected ? _accentColor : Colors.orangeAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isConnected ? '接続中: $deviceName' : 'デバイス未接続（転送時に接続選択できます）',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isConnected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor:
                        isConnected ? Colors.white70 : const Color(0xFF818CF8),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: _isBusy
                      ? null
                      : (isConnected
                          ? _disconnectBleDevice
                          : _connectBleDevice),
                  child: Text(
                    isConnected ? '切断' : '接続する',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (_isTransferring) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bleAccentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _bleAccentColor.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '転送中 ($_transferCurrentIndex/$_transferTotalCount): $_transferCurrentPresetName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _currentFileProgress > 0
                        ? _currentFileProgress.clamp(0.0, 1.0)
                        : null,
                    color: _bleAccentColor,
                    backgroundColor: Colors.white12,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _transferStatusMessage,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _bleAccentColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white12,
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: (!_isBusy && transferableCount > 0)
                ? _transferAllPresetAudios
                : null,
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(
              '全プリセットのトリガー音声を一括転送 ($transferableCount件)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white38,
              side: BorderSide(
                color: (!_isBusy && selectedHasTriggerAudio)
                    ? _bleAccentColor.withValues(alpha: 0.7)
                    : Colors.white12,
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: (!_isBusy && selectedHasTriggerAudio)
                ? _transferSelectedPresetAudio
                : null,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text(
              '選択中プリセットのトリガー音声を転送',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferResultCard(BatchAudioTransferResult result) {
    final borderColor = result.allSucceeded
        ? _accentColor.withValues(alpha: 0.5)
        : Colors.orangeAccent.withValues(alpha: 0.55);
    final bgColor = result.allSucceeded
        ? const Color(0xFF064E3B).withValues(alpha: 0.45)
        : Colors.orange.withValues(alpha: 0.14);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.allSucceeded
                    ? Icons.cloud_done_rounded
                    : Icons.warning_amber_rounded,
                color: result.allSucceeded ? _accentColor : Colors.orangeAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                result.allSucceeded ? 'トリガー音声転送完了' : '一部転送に失敗しました',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '成功 ${result.successCount}件 / 失敗 ${result.failureCount}件'
            '${result.skippedNoAudioCount > 0 ? '（音声未登録スキップ: ${result.skippedNoAudioCount}件）' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ...result.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.success
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    size: 16,
                    color: item.success ? _accentColor : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.presetName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '/${item.devicePath}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (!item.success && item.errorMessage != null)
                          Text(
                            item.errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWriteResultCard(NfcWriteResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: _accentColor, size: 20),
              SizedBox(width: 8),
              Text(
                '書き込み完了',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow('プリセット名', result.payload.name),
          _buildInfoRow('UUID', result.payload.uuid, monospace: true),
          _buildInfoRow('書き込みサイズ', '${result.writtenBytes} bytes'),
          if (result.tag.id.isNotEmpty)
            _buildInfoRow('タグID', result.tag.id, monospace: true),
          if (result.tag.capacityBytes != null)
            _buildInfoRow('タグ容量', '${result.tag.capacityBytes} bytes'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool monospace = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
