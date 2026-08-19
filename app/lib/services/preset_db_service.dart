import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/voice_preset.dart';

class PresetDbService {
  static final PresetDbService instance = PresetDbService._internal();
  PresetDbService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'voice_presets.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE voice_presets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            color INTEGER NOT NULL,
            icon_path TEXT,
            audio_files_json TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // プリセット用ストレージディレクトリの取得
  Future<Directory> getPresetsStorageDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final presetsDir = Directory(p.join(docsDir.path, 'presets_data'));
    if (!await presetsDir.exists()) {
      await presetsDir.create(recursive: true);
    }
    return presetsDir;
  }

  // アイコン画像の保存
  Future<String> savePresetIcon(String sourcePath, String baseName) async {
    final storageDir = await getPresetsStorageDir();
    final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.png';
    final targetPath = p.join(storageDir.path, 'icon_${DateTime.now().millisecondsSinceEpoch}_$baseName$ext');
    final sourceFile = File(sourcePath);
    await sourceFile.copy(targetPath);
    return targetPath;
  }

  // 音声ファイルの保存
  Future<String> savePresetAudio(String sourcePath, int slotIndex) async {
    final storageDir = await getPresetsStorageDir();
    final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.wav';
    final targetPath = p.join(storageDir.path, 'audio_${DateTime.now().millisecondsSinceEpoch}_slot$slotIndex$ext');
    final sourceFile = File(sourcePath);
    await sourceFile.copy(targetPath);
    return targetPath;
  }

  // 全プリセットの取得
  Future<List<VoicePreset>> getAllPresets() async {
    final db = await database;
    final maps = await db.query('voice_presets', orderBy: 'created_at DESC');
    return maps.map((m) => VoicePreset.fromMap(m)).toList();
  }

  // プリセットの作成
  Future<VoicePreset> createPreset(VoicePreset preset) async {
    final db = await database;
    final id = await db.insert('voice_presets', preset.toMap());
    return preset.copyWith(id: id);
  }

  // プリセットの更新
  Future<int> updatePreset(VoicePreset preset) async {
    final db = await database;
    return await db.update(
      'voice_presets',
      preset.toMap(),
      where: 'id = ?',
      whereArgs: [preset.id],
    );
  }

  // プリセットの削除（DBおよび関連ファイル）
  Future<int> deletePreset(VoicePreset preset) async {
    final db = await database;
    
    // アイコン削除
    if (preset.iconPath != null) {
      try {
        final iconFile = File(preset.iconPath!);
        if (await iconFile.exists()) {
          await iconFile.delete();
        }
      } catch (_) {}
    }

    // 音声ファイル削除
    for (final path in preset.audioFiles.values) {
      try {
        final audioFile = File(path);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      } catch (_) {}
    }

    return await db.delete(
      'voice_presets',
      where: 'id = ?',
      whereArgs: [preset.id],
    );
  }
}
