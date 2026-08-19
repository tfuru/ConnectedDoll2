import 'dart:io';
import 'package:flutter/material.dart';
import '../models/voice_preset.dart';
import '../services/preset_db_service.dart';
import 'preset_detail_screen.dart';

class PresetListScreen extends StatefulWidget {
  const PresetListScreen({super.key});

  @override
  State<PresetListScreen> createState() => _PresetListScreenState();
}

class _PresetListScreenState extends State<PresetListScreen> {
  List<VoicePreset> _presets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    setState(() {
      _isLoading = true;
    });
    final list = await PresetDbService.instance.getAllPresets();
    if (mounted) {
      setState(() {
        _presets = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _openDetail([VoicePreset? preset]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PresetDetailScreen(preset: preset),
      ),
    );
    if (result == true) {
      _loadPresets();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('音声プリセット一覧'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新規プリセット作成',
            onPressed: () => _openDetail(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _presets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_music_outlined, size: 72, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text(
                        '登録されたプリセットがありません',
                        style: TextStyle(fontSize: 16, color: Colors.white60),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '右上の「+」ボタンから推しのボイスセットを作成しましょう',
                        style: TextStyle(fontSize: 12, color: Colors.white38),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _openDetail(),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('新規作成', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.all(16),
                  itemCount: _presets.length,
                  onReorder: (int oldIndex, int newIndex) async {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final item = _presets.removeAt(oldIndex);
                      _presets.insert(newIndex, item);
                    });
                    await PresetDbService.instance.updatePresetOrders(_presets);
                  },
                  itemBuilder: (context, index) {
                    final preset = _presets[index];
                    final color = Color(preset.color);
                    final voiceCount = preset.audioFiles.length;

                    return Card(
                      key: ValueKey(preset.id ?? index),
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openDetail(preset),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            children: [
                              // アイコン
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color.withValues(alpha: 0.15),
                                  border: Border.all(color: color, width: 2),
                                  image: preset.iconPath != null
                                      ? DecorationImage(
                                          image: FileImage(File(preset.iconPath!)),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: preset.iconPath == null
                                    ? Icon(Icons.person, color: color, size: 30)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              // 名前 & 登録情報
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      preset.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '登録音声: $voiceCount 件',
                                          style: const TextStyle(fontSize: 13, color: Colors.white60),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // ドラッグ並べ替えハンドル
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 10.0),
                                  child: Icon(Icons.drag_handle_rounded, color: Colors.white38, size: 24),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _presets.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF4F46E5),
              onPressed: () => _openDetail(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
