import 'dart:convert';

class VoicePreset {
  final int? id;
  final String name;
  final int color; // ARGB Color int
  final String? iconPath;
  // Map of slot index (e.g. -1 for trigger, 0..4 for alarms) to local audio file path
  final Map<int, String> audioFiles;
  // Map of slot index to original audio file name (e.g. "01_Voice.mp3")
  final Map<int, String> audioFileNames;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  VoicePreset({
    this.id,
    required this.name,
    required this.color,
    this.iconPath,
    required this.audioFiles,
    Map<int, String>? audioFileNames,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : audioFileNames = audioFileNames ?? {},
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String getAudioFileName(int slotIndex) {
    if (audioFileNames.containsKey(slotIndex) && audioFileNames[slotIndex]!.isNotEmpty) {
      return audioFileNames[slotIndex]!;
    }
    if (audioFiles.containsKey(slotIndex)) {
      final path = audioFiles[slotIndex]!;
      final base = path.split(RegExp(r'[\\/]')).last;
      final match = RegExp(r'^audio_\d+_slot-?\d+_(.+)$').firstMatch(base);
      if (match != null) {
        return match.group(1)!;
      }
      return base;
    }
    return '';
  }

  VoicePreset copyWith({
    int? id,
    String? name,
    int? color,
    String? iconPath,
    Map<int, String>? audioFiles,
    Map<int, String>? audioFileNames,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VoicePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      iconPath: iconPath ?? this.iconPath,
      audioFiles: audioFiles ?? Map.from(this.audioFiles),
      audioFileNames: audioFileNames ?? Map.from(this.audioFileNames),
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'color': color,
      'icon_path': iconPath,
      'audio_files_json': jsonEncode(
        audioFiles.map((k, v) => MapEntry(k.toString(), v)),
      ),
      'audio_file_names_json': jsonEncode(
        audioFileNames.map((k, v) => MapEntry(k.toString(), v)),
      ),
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory VoicePreset.fromMap(Map<String, dynamic> map) {
    Map<int, String> audios = {};
    if (map['audio_files_json'] != null) {
      try {
        final decoded = jsonDecode(map['audio_files_json'] as String) as Map<String, dynamic>;
        audios = decoded.map((k, v) => MapEntry(int.parse(k), v as String));
      } catch (_) {}
    }

    Map<int, String> fileNames = {};
    if (map['audio_file_names_json'] != null) {
      try {
        final decoded = jsonDecode(map['audio_file_names_json'] as String) as Map<String, dynamic>;
        fileNames = decoded.map((k, v) => MapEntry(int.parse(k), v as String));
      } catch (_) {}
    }

    // 既存データ等の補完
    for (final entry in audios.entries) {
      if (!fileNames.containsKey(entry.key) || fileNames[entry.key]!.isEmpty) {
        final base = entry.value.split(RegExp(r'[\\/]')).last;
        final match = RegExp(r'^audio_\d+_slot-?\d+_(.+)$').firstMatch(base);
        fileNames[entry.key] = match != null ? match.group(1)! : base;
      }
    }

    return VoicePreset(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      color: map['color'] as int? ?? 0xFF4F46E5,
      iconPath: map['icon_path'] as String?,
      audioFiles: audios,
      audioFileNames: fileNames,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
    );
  }
}
