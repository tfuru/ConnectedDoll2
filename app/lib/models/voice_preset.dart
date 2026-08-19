import 'dart:convert';

class VoicePreset {
  final int? id;
  final String name;
  final int color; // ARGB Color int
  final String? iconPath;
  // Map of slot index (e.g. -1 for trigger, 0..4 for alarms) to local audio file path
  final Map<int, String> audioFiles;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  VoicePreset({
    this.id,
    required this.name,
    required this.color,
    this.iconPath,
    required this.audioFiles,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  VoicePreset copyWith({
    int? id,
    String? name,
    int? color,
    String? iconPath,
    Map<int, String>? audioFiles,
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

    return VoicePreset(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      color: map['color'] as int? ?? 0xFF4F46E5,
      iconPath: map['icon_path'] as String?,
      audioFiles: audios,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
    );
  }
}
