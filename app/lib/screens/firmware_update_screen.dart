import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/github_release.dart';
import '../services/ble_service.dart';
import '../services/github_release_service.dart';
import 'scan_screen.dart';

enum UpdateStep {
  idle,
  downloading,
  downloaded,
  transferring,
  applying,
  completed,
  failed,
}

class FirmwareUpdateScreen extends StatefulWidget {
  const FirmwareUpdateScreen({super.key});

  @override
  State<FirmwareUpdateScreen> createState() => _FirmwareUpdateScreenState();
}

class _FirmwareUpdateScreenState extends State<FirmwareUpdateScreen> {
  final BleService _bleService = BleService();
  String _repository = GitHubReleaseService.defaultRepository;
  
  List<GitHubRelease> _releases = [];
  GitHubRelease? _selectedRelease;
  bool _isLoadingReleases = false;
  String? _errorMessage;

  UpdateStep _currentStep = UpdateStep.idle;
  double _downloadProgress = 0.0;
  double _transferProgress = 0.0;
  String _statusMessage = '';
  Uint8List? _downloadedFirmwareBytes;

  StreamSubscription<double>? _transferProgressSub;
  StreamSubscription<String>? _transferStatusSub;

  @override
  void initState() {
    super.initState();
    _fetchReleases();

    _transferProgressSub = _bleService.transferProgressController.stream.listen((progress) {
      if (mounted) {
        setState(() {
          _transferProgress = progress;
        });
      }
    });

    _transferStatusSub = _bleService.transferStatusController.stream.listen((status) {
      if (mounted) {
        setState(() {
          _statusMessage = status;
          if (status.contains("completed")) {
            _currentStep = UpdateStep.applying;
            _statusMessage = "デバイス側でファームウェアを適用中... (自動再起動します)";
            Timer(const Duration(seconds: 4), () {
              if (mounted) {
                setState(() {
                  _currentStep = UpdateStep.completed;
                  _statusMessage = "ファームウェアの更新が完了しました！";
                });
              }
            });
          } else if (status.contains("failed") || status.contains("Error")) {
            _currentStep = UpdateStep.failed;
            _statusMessage = status;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _transferProgressSub?.cancel();
    _transferStatusSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchReleases() async {
    setState(() {
      _isLoadingReleases = true;
      _errorMessage = null;
    });

    try {
      final releases = await GitHubReleaseService.fetchReleases(repository: _repository);
      if (mounted) {
        setState(() {
          _releases = releases;
          _isLoadingReleases = false;
          if (_releases.isNotEmpty) {
            // firmware.bin を含む最新リリースをデフォルト選択
            _selectedRelease = _releases.firstWhere(
              (r) => r.hasFirmware,
              orElse: () => _releases.first,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoadingReleases = false;
        });
      }
    }
  }

  void _showRepoEditDialog() {
    final controller = TextEditingController(text: _repository);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('リポジトリ設定', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GitHubのリポジトリ名 (owner/repo):',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                hintText: 'owner/repository',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _repository = controller.text.trim();
              });
              _fetchReleases();
            },
            child: const Text('更新'),
          ),
        ],
      ),
    );
  }

  Future<void> _startUpdateFlow() async {
    if (_selectedRelease == null || !_selectedRelease!.hasFirmware) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('選択されたリリースには有効なファームウェア (firmware.bin) がありません')),
      );
      return;
    }

    final asset = _selectedRelease!.firmwareAsset!;

    // 1. ダウンロード処理
    setState(() {
      _currentStep = UpdateStep.downloading;
      _downloadProgress = 0.0;
      _statusMessage = 'GitHubからファームウェアをダウンロード中...';
    });

    try {
      final bytes = await GitHubReleaseService.downloadFirmware(
        asset,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _downloadProgress = p;
            });
          }
        },
      );

      _downloadedFirmwareBytes = bytes;

      setState(() {
        _currentStep = UpdateStep.downloaded;
        _statusMessage = 'ダウンロード完了 (${asset.formattedSize})';
      });

      // 2. BLE接続の確認
      if (!_bleService.isConnected) {
        setState(() {
          _statusMessage = 'デバイスが未接続です。先にBLE接続を行ってください。';
        });
        if (mounted) {
          final connectNow = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('デバイス未接続', style: TextStyle(color: Colors.white)),
              content: const Text(
                'ファームウェアを転送するにはConnectedDoll2デバイスとのBLE接続が必要です。\n今すぐ接続画面を開きますか？',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('キャンセル', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('接続画面へ', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );

          if (connectNow == true && mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScanScreen()),
            );
            if (!_bleService.isConnected) {
              setState(() {
                _currentStep = UpdateStep.failed;
                _statusMessage = 'BLE接続がキャンセルされました。';
              });
              return;
            }
          } else {
            setState(() {
              _currentStep = UpdateStep.failed;
              _statusMessage = 'BLE接続が必要です。';
            });
            return;
          }
        }
      }

      // 3. SDカードへ転送 (/update.bin)
      setState(() {
        _currentStep = UpdateStep.transferring;
        _transferProgress = 0.0;
        _statusMessage = 'SDカードへファームウェアを転送中 (/update.bin)...';
      });

      await _bleService.transferFile('update.bin', _downloadedFirmwareBytes!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentStep = UpdateStep.failed;
          _statusMessage = 'エラーが発生しました: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('ファームウェア更新', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'リポジトリ設定',
            onPressed: _showRepoEditDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '再読み込み',
            onPressed: _isLoadingReleases ? null : _fetchReleases,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // デバイス接続状態バナー
            _buildConnectionBanner(),

            Expanded(
              child: _isLoadingReleases
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _releases.isEmpty
                          ? _buildEmptyView()
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 安全・注意事項アラート
                                  _buildCautionCard(),
                                  const SizedBox(height: 16),

                                  // 更新進捗カード (更新実行中のみ強調)
                                  if (_currentStep != UpdateStep.idle) ...[
                                    _buildProgressCard(),
                                    const SizedBox(height: 16),
                                  ],

                                  // リリース選択エリア
                                  _buildReleaseSelectionSection(),
                                  const SizedBox(height: 24),

                                  // 更新実行ボタン
                                  _buildUpdateButton(),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBanner() {
    final isConnected = _bleService.isConnected;
    final deviceName = _bleService.connectedDevice?.name ?? 'ConnectedDoll2';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isConnected
            ? const Color(0xFF064E3B).withValues(alpha: 0.8)
            : const Color(0xFF7F1D1D).withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
            color: isConnected ? const Color(0xFF34D399) : const Color(0xFFF87171),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isConnected ? '接続中: $deviceName' : 'デバイス未接続 (BLE)',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          if (!isConnected)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScanScreen()),
                );
                setState(() {});
              },
              child: const Text('接続する', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildCautionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF854D0E).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFACC15).withValues(alpha: 0.5)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFFACC15), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '【注意事項】\nファームウェア転送・更新中はデバイスの電源を切ったり、BLE通信範囲外に移動しないでください。更新完了後、デバイスは自動的に再起動します。',
              style: TextStyle(color: Color(0xFFFEF08A), fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '利用可能なファームウェア',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              _repository,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _releases.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
          itemBuilder: (ctx, index) {
            final release = _releases[index];
            final isSelected = _selectedRelease?.id == release.id;
            final hasBin = release.hasFirmware;

            return Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF312E81).withValues(alpha: 0.7)
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF8B5CF6)
                      : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _selectedRelease = release;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: release.isPrerelease
                                    ? const Color(0xFFF97316).withValues(alpha: 0.2)
                                    : const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: release.isPrerelease
                                      ? const Color(0xFFF97316)
                                      : const Color(0xFF10B981),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                release.tagName,
                                style: TextStyle(
                                  color: release.isPrerelease
                                      ? const Color(0xFFFB923C)
                                      : const Color(0xFF34D399),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                release.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF8B5CF6), size: 20),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (release.body.isNotEmpty) ...[
                          Text(
                            release.body.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (release.publishedAt != null)
                              Text(
                                '公開日: ${release.publishedAt!.year}/${release.publishedAt!.month}/${release.publishedAt!.day}',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            if (hasBin)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'firmware.bin (${release.firmwareAsset!.formattedSize})',
                                  style: const TextStyle(color: Color(0xFFA5B4FC), fontSize: 11),
                                ),
                              )
                            else
                              const Text(
                                'ファームウェアなし',
                                style: TextStyle(color: Colors.redAccent, fontSize: 11),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    final isBusy = _currentStep == UpdateStep.downloading ||
        _currentStep == UpdateStep.transferring ||
        _currentStep == UpdateStep.applying;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _currentStep == UpdateStep.completed
              ? const Color(0xFF10B981)
              : _currentStep == UpdateStep.failed
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF8B5CF6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF8B5CF6)),
                )
              else if (_currentStep == UpdateStep.completed)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20)
              else if (_currentStep == UpdateStep.failed)
                const Icon(Icons.error_rounded, color: Color(0xFFEF4444), size: 20)
              else
                const Icon(Icons.cloud_download_rounded, color: Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _currentStep == UpdateStep.completed
                        ? const Color(0xFF34D399)
                        : _currentStep == UpdateStep.failed
                            ? const Color(0xFFF87171)
                            : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ダウンロード進捗
          if (_currentStep == UpdateStep.downloading || _downloadProgress > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('GitHub ダウンロード:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('${(_downloadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // SDカード転送進捗
          if (_currentStep == UpdateStep.transferring || _transferProgress > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SDカード転送 (BLE):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('${(_transferProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _transferProgress,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    final isBusy = _currentStep == UpdateStep.downloading ||
        _currentStep == UpdateStep.transferring ||
        _currentStep == UpdateStep.applying;
    final canUpdate = _selectedRelease != null && _selectedRelease!.hasFirmware && !isBusy;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: canUpdate
            ? const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        boxShadow: canUpdate
            ? [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: canUpdate ? Colors.transparent : Colors.white12,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: canUpdate ? _startUpdateFlow : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isBusy ? Icons.hourglass_top_rounded : Icons.system_update_alt_rounded,
              color: canUpdate ? Colors.white : Colors.white38,
            ),
            const SizedBox(width: 10),
            Text(
              isBusy
                  ? 'アップデート処理中...'
                  : _selectedRelease != null
                      ? '${_selectedRelease!.tagName} にアップデート'
                      : 'ファームウェアを選択してください',
              style: TextStyle(
                color: canUpdate ? Colors.white : Colors.white38,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFFF87171), size: 54),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'エラーが発生しました',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _fetchReleases,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, color: Colors.white38, size: 54),
            const SizedBox(height: 16),
            Text(
              'リポジトリ "$_repository" に公開リリースが見つかりませんでした。',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              onPressed: _showRepoEditDialog,
              child: const Text('リポジトリ設定を変更'),
            ),
          ],
        ),
      ),
    );
  }
}
