import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/voice_preset.dart';
import '../services/preset_db_service.dart';

class PresetDetailScreen extends StatefulWidget {
  final VoicePreset? preset;

  const PresetDetailScreen({super.key, this.preset});

  @override
  State<PresetDetailScreen> createState() => _PresetDetailScreenState();
}

class _PresetDetailScreenState extends State<PresetDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _hexColorController;
  late int _selectedColor;
  String? _iconPath;
  late Map<int, String> _audioFiles;
  bool _isSaving = false;

  // 定義済みカラーパレット（推しカラー用）
  final List<Color> _presetColors = const [
    Color(0xFF4F46E5), // Indigo
    Color(0xFFEC4899), // Pink
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFFEAB308), // Yellow
    Color(0xFF10B981), // Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
    Color(0xFF8B5CF6), // Purple
    Color(0xFF6B7280), // Gray
  ];

  String _toHexCode(int colorInt) {
    return '#${(colorInt & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  int? _parseHexColor(String hex) {
    String cleanHex = hex.trim().replaceAll('#', '');
    if (cleanHex.length == 6) {
      final val = int.tryParse(cleanHex, radix: 16);
      if (val != null) {
        return 0xFF000000 | val;
      }
    } else if (cleanHex.length == 8) {
      final val = int.tryParse(cleanHex, radix: 16);
      if (val != null) {
        return val;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    _nameController = TextEditingController(text: p?.name ?? '');
    _selectedColor = p?.color ?? _presetColors.first.value;
    _hexColorController = TextEditingController(text: _toHexCode(_selectedColor));
    _iconPath = p?.iconPath;
    _audioFiles = p != null ? Map<int, String>.from(p.audioFiles) : {};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hexColorController.dispose();
    super.dispose();
  }


  // アイコン画像の選択
  Future<void> _pickIconImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _iconPath = result.files.single.path;
      });
    }
  }

  // 音声ファイルの選択
  Future<void> _pickAudioForSlot(int slotIndex) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a', 'aac', 'ogg'],
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _audioFiles[slotIndex] = result.files.single.path!;
      });
    }
  }



  // プリセットの保存
  Future<void> _savePreset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final dbService = PresetDbService.instance;
      String? savedIconPath = _iconPath;

      // アイコンが一時パス等の新規指定である場合はストレージに永続保存
      if (_iconPath != null && (widget.preset == null || widget.preset!.iconPath != _iconPath)) {
        savedIconPath = await dbService.savePresetIcon(_iconPath!, _nameController.text.trim());
      }

      // 音声ファイル群のストレージ保存
      final Map<int, String> savedAudioFiles = {};
      for (final entry in _audioFiles.entries) {
        final slot = entry.key;
        final srcPath = entry.value;
        if (widget.preset != null && widget.preset!.audioFiles[slot] == srcPath) {
          savedAudioFiles[slot] = srcPath;
        } else {
          savedAudioFiles[slot] = await dbService.savePresetAudio(srcPath, slot);
        }
      }

      if (widget.preset == null) {
        // 新規作成
        final newPreset = VoicePreset(
          name: _nameController.text.trim(),
          color: _selectedColor,
          iconPath: savedIconPath,
          audioFiles: savedAudioFiles,
        );
        await dbService.createPreset(newPreset);
      } else {
        // 更新
        final updated = widget.preset!.copyWith(
          name: _nameController.text.trim(),
          color: _selectedColor,
          iconPath: savedIconPath,
          audioFiles: savedAudioFiles,
          updatedAt: DateTime.now(),
        );
        await dbService.updatePreset(updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プリセットを保存しました')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // プリセットの削除
  Future<void> _confirmDelete() async {
    if (widget.preset == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('プリセットの削除', style: TextStyle(color: Colors.white)),
        content: Text('「${widget.preset!.name}」をDBから削除しますか？\n登録された音声や画像も削除されます。',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PresetDbService.instance.deletePreset(widget.preset!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プリセットを削除しました')),
        );
        Navigator.pop(context, true);
      }
    }
  }

  String _getSlotLabel(int slot) {
    if (slot == -1) return 'トリガー音声 (trigger.wav)';
    return 'アラーム $slot (alarm$slot.wav)';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.preset != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(isEditing ? 'プリセット編集' : '新規プリセット登録'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'プリセット削除',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // アイコン画像 & プリセット名入力
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          GestureDetector(
                            onTap: _pickIconImage,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Color(_selectedColor),
                                  width: 3,
                                ),
                                image: _iconPath != null
                                    ? DecorationImage(
                                        image: FileImage(File(_iconPath!)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _iconPath == null
                                  ? const Icon(Icons.person, size: 50, color: Colors.white38)
                                  : null,
                            ),
                          ),
                          InkWell(
                            onTap: _pickIconImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Color(_selectedColor),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // プリセット名
                    const Text('プリセット名', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '例: ミク、お気に入りボイス',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '名前を入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // 推しカラー選択
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('推しカラー', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                        Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: Color(_selectedColor),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _toHexCode(_selectedColor),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _presetColors.map((col) {
                        final isSelected = (_selectedColor & 0xFFFFFF) == (col.value & 0xFFFFFF);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = col.value;
                              _hexColorController.text = _toHexCode(col.value);
                            });
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: col,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [BoxShadow(color: col.withOpacity(0.6), blurRadius: 8, spreadRadius: 2)]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 20, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // カラーコード手動入力
                    TextFormField(
                      controller: _hexColorController,
                      style: const TextStyle(color: Colors.white, letterSpacing: 1.2),
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'カラーコード (#RRGGBB)',
                        labelStyle: const TextStyle(color: Colors.white60),
                        hintText: '#FFFFFF',
                        hintStyle: const TextStyle(color: Colors.white30),
                        prefixIcon: const Icon(Icons.colorize, color: Colors.white60, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (value) {
                        final parsed = _parseHexColor(value);
                        if (parsed != null) {
                          setState(() {
                            _selectedColor = parsed;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'カラーコードを入力してください';
                        }
                        if (_parseHexColor(value) == null) {
                          return '有効なカラーコード (例: #FF007F) を入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // 音声ファイルリスト (トリガー音声 & アラーム0〜4)
                    const Text('登録音声ファイル', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    const Text('タップして音声ファイルを選択してください', style: TextStyle(fontSize: 12, color: Colors.white38)),
                    const SizedBox(height: 12),

                    ...[-1, 0, 1, 2, 3, 4].map((slot) {
                      final hasFile = _audioFiles.containsKey(slot);
                      final filePath = _audioFiles[slot];
                      final fileName = filePath != null ? filePath.split(Platform.pathSeparator).last : '未登録';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasFile ? Color(_selectedColor).withOpacity(0.6) : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              slot == -1 ? Icons.touch_app : Icons.alarm,
                              color: hasFile ? Color(_selectedColor) : Colors.white38,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getSlotLabel(slot),
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    fileName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: hasFile ? Colors.white70 : Colors.white30,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (hasFile)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.white38),
                                onPressed: () {
                                  setState(() {
                                    _audioFiles.remove(slot);
                                  });
                                },
                              ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF334155),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _pickAudioForSlot(slot),
                              child: Text(hasFile ? '変更' : '選択', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(_selectedColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _savePreset,
                        child: const Text('保存する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
