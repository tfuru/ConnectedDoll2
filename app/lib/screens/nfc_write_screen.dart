import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/voice_preset.dart';
import '../services/nfc_service.dart';
import '../services/nfc_uuid_service.dart';
import '../services/preset_db_service.dart';
import 'preset_list_screen.dart';

class NfcWriteScreen extends StatefulWidget {
  final NfcTagGateway? nfcService;
  final NfcUuidService? uuidService;
  final Future<List<VoicePreset>> Function()? loadPresets;
  final Future<void> Function(int presetId, String nfcUuid)? savePresetUuid;
  final Future<VoicePreset?> Function(String nfcUuid)? findPresetByUuid;

  const NfcWriteScreen({
    super.key,
    this.nfcService,
    this.uuidService,
    this.loadPresets,
    this.savePresetUuid,
    this.findPresetByUuid,
  });

  @override
  State<NfcWriteScreen> createState() => _NfcWriteScreenState();
}

class _NfcWriteScreenState extends State<NfcWriteScreen> {
  static const Color _bgColor = Color(0xFF0F172A);
  static const Color _cardColor = Color(0xFF1E293B);
  static const Color _accentColor = Color(0xFF10B981);

  late final NfcUuidService _uuidService;
  late final NfcTagGateway _nfcService;

  List<VoicePreset> _presets = [];
  VoicePreset? _selectedPreset;
  NfcReaderStatus _nfcStatus = NfcReaderStatus.available;
  bool _isLoading = true;
  bool _isScanning = false;

  NfcWriteResult? _lastWriteResult;
  NfcReadResult? _lastReadResult;
  VoicePreset? _matchedReadPreset;
  String? _lastErrorMessage;

  @override
  void initState() {
    super.initState();
    _uuidService = widget.uuidService ?? const NfcUuidService();
    _nfcService = widget.nfcService ?? NfcService(uuidService: _uuidService);
    _initialize();
  }

  @override
  void dispose() {
    if (_isScanning) {
      _nfcService.cancelSession();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _loadPresetsFromStore(),
      _nfcService.checkAvailability(),
    ]);

    if (!mounted) return;
    final loadedPresets = results[0] as List<VoicePreset>;
    final status = results[1] as NfcReaderStatus;

    VoicePreset? preservedSelection;
    if (_selectedPreset?.id != null) {
      for (final p in loadedPresets) {
        if (p.id == _selectedPreset!.id) {
          preservedSelection = p;
          break;
        }
      }
    }

    setState(() {
      _presets = loadedPresets;
      _selectedPreset = preservedSelection;
      _nfcStatus = status;
      _isLoading = false;
    });
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

  Future<VoicePreset?> _lookupPresetByUuid(String nfcUuid) async {
    if (widget.findPresetByUuid != null) {
      return widget.findPresetByUuid!(nfcUuid);
    }
    return PresetDbService.instance.getPresetByNfcUuid(nfcUuid);
  }

  Future<void> _refreshNfcStatus() async {
    final status = await _nfcService.checkAvailability();
    if (!mounted) return;
    setState(() => _nfcStatus = status);
  }

  Future<void> _selectPreset(VoicePreset preset) async {
    var target = preset;
    if (target.nfcUuid == null || target.nfcUuid!.isEmpty) {
      final newUuid = _uuidService.generateUuid();
      if (target.id != null) {
        await _persistPresetUuid(target.id!, newUuid);
      }
      target = target.copyWith(nfcUuid: newUuid);
    }

    if (!mounted) return;
    setState(() {
      _presets = _presets.map((p) {
        if (target.id != null && p.id == target.id) {
          return target;
        }
        return identical(p, preset) ? target : p;
      }).toList();
      _selectedPreset = target;
      _lastErrorMessage = null;
    });
  }

  Future<void> _regenerateUuid() async {
    final current = _selectedPreset;
    if (current == null) return;

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
          '以前書き込んだNFCタグのUUIDとは一致しなくなります。',
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

    if (!mounted) return;
    setState(() {
      _presets = _presets
          .map((p) => (updated.id != null && p.id == updated.id) ? updated : p)
          .toList();
      _selectedPreset = updated;
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

  Future<void> _startWriteTag() async {
    final preset = _selectedPreset;
    if (preset == null || _isScanning) return;

    // 念のためUUID未設定なら発行してから書き込む
    if (preset.nfcUuid == null || preset.nfcUuid!.isEmpty) {
      await _selectPreset(preset);
    }
    final target = _selectedPreset;
    final uuid = target?.nfcUuid;
    if (target == null || uuid == null || uuid.isEmpty) return;

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

  Future<void> _startReadTag() async {
    if (_isScanning) return;

    await _runNfcSession<NfcReadResult>(
      title: 'NFCタグを読み込み中',
      subtitle: '確認したいNFCタグを端末背面にかざしてください',
      operation: () => _nfcService.readPresetTag(),
      onSuccess: (result) async {
        final matched = await _lookupPresetByUuid(result.payload.uuid);
        if (!mounted) return;
        setState(() {
          _lastReadResult = result;
          _matchedReadPreset = matched;
          _lastErrorMessage = null;
        });
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
    final canUseNfc = _nfcStatus == NfcReaderStatus.available && !_isScanning;

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
            onPressed: _isScanning ? null : _initialize,
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
                    _buildPresetSelectorCard(),
                    if (_selectedPreset != null) ...[
                      const SizedBox(height: 16),
                      _buildUuidPreviewCard(_selectedPreset!),
                    ],
                    const SizedBox(height: 20),
                    _buildActionButtons(canUseNfc),
                    if (_lastErrorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBanner(_lastErrorMessage!),
                    ],
                    if (_lastWriteResult != null) ...[
                      const SizedBox(height: 16),
                      _buildWriteResultCard(_lastWriteResult!),
                    ],
                    if (_lastReadResult != null) ...[
                      const SizedBox(height: 16),
                      _buildReadResultCard(_lastReadResult!),
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
        message = 'プリセット名を選択して「NFCタグに書き込む」を押してください。';
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
        message = 'NFC 搭載の Android 端末でお試しください（UUID の発行・確認のみ可能です）。';
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

  Widget _buildPresetSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.library_music_rounded,
                  color: Color(0xFFEC4899), size: 20),
              SizedBox(width: 8),
              Text(
                '1. 音声プリセットを選択',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '選択した名前に紐づくUUIDを発行し、NFCタグへ書き込みます。',
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
          else
            Column(
              children: _presets.map((preset) {
                final isSelected = _selectedPreset != null &&
                    ((preset.id != null && preset.id == _selectedPreset!.id) ||
                        identical(preset, _selectedPreset));
                final presetColor = Color(preset.color);
                final hasUuid =
                    preset.nfcUuid != null && preset.nfcUuid!.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: isSelected
                        ? presetColor.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _isScanning ? null : () => _selectPreset(preset),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? presetColor
                                : Colors.white.withValues(alpha: 0.1),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildPresetAvatar(preset),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    preset.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasUuid
                                        ? 'UUID: ${preset.nfcUuid}'
                                        : 'タップしてUUIDを発行',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: hasUuid
                                          ? Colors.white60
                                          : _accentColor,
                                      fontSize: 11,
                                      fontFamily: hasUuid ? 'monospace' : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? presetColor : Colors.white30,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPresetAvatar(VoicePreset preset) {
    final presetColor = Color(preset.color);
    final iconPath = preset.iconPath;
    final hasValidFile =
        iconPath != null && iconPath.isNotEmpty && File(iconPath).existsSync();

    if (hasValidFile) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: presetColor.withValues(alpha: 0.25),
        backgroundImage: FileImage(File(iconPath)),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: presetColor.withValues(alpha: 0.25),
      child: Icon(Icons.music_note_rounded, color: presetColor, size: 20),
    );
  }

  Widget _buildUuidPreviewCard(VoicePreset preset) {
    final uuid = preset.nfcUuid ?? '';
    final hasValidUuid = _uuidService.isValidUuid(uuid);
    final jsonPreview = hasValidUuid
        ? _uuidService.encodePayloadJson(uuid: uuid, name: preset.name)
        : '';
    final byteSize = hasValidUuid
        ? _uuidService.estimateNdefRecordBytes(uuid: uuid, name: preset.name)
        : 0;
    final exceedsNtag213 = byteSize > NfcUuidService.ntag213RecommendedMaxBytes;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fingerprint_rounded,
                  color: _accentColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '2. 書き込むデータ（UUID & MIME JSON）',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: _isScanning ? null : _regenerateUuid,
                icon: const Icon(Icons.autorenew_rounded, size: 16),
                label: const Text('再発行', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded,
                      color: Colors.white70, size: 18),
                  tooltip: 'UUIDをコピー',
                  onPressed: hasValidUuid ? () => _copyUuid(uuid) : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'MIME Type: ${NfcUuidService.presetMimeType}',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Payload: $jsonPreview',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                exceedsNtag213
                    ? Icons.info_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 15,
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

  Widget _buildActionButtons(bool canUseNfc) {
    final canWrite = canUseNfc && _selectedPreset != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white38,
            side: BorderSide(
              color: canUseNfc ? Colors.white30 : Colors.white12,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: canUseNfc ? _startReadTag : null,
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
          label: const Text(
            'NFCタグを読み込んで確認',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
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

  Widget _buildReadResultCard(NfcReadResult result) {
    final matched = _matchedReadPreset;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF818CF8), size: 20),
              SizedBox(width: 8),
              Text(
                'NFCタグ読み込み結果',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow('タグ内プリセット名', result.payload.name),
          _buildInfoRow('タグ内UUID', result.payload.uuid, monospace: true),
          _buildInfoRow(
            '登録プリセット照合',
            matched != null ? '一致: ${matched.name}' : '該当する登録プリセットなし',
          ),
          if (result.tag.id.isNotEmpty)
            _buildInfoRow('タグID', result.tag.id, monospace: true),
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
