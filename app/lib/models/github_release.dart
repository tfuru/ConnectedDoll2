class GitHubReleaseAsset {
  final int id;
  final String name;
  final int size;
  final String downloadUrl;
  final String? createdAt;

  GitHubReleaseAsset({
    required this.id,
    required this.name,
    required this.size,
    required this.downloadUrl,
    this.createdAt,
  });

  factory GitHubReleaseAsset.fromJson(Map<String, dynamic> json) {
    return GitHubReleaseAsset(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      downloadUrl: json['browser_download_url'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class GitHubRelease {
  final int id;
  final String tagName;
  final String name;
  final String body;
  final DateTime? publishedAt;
  final bool isPrerelease;
  final List<GitHubReleaseAsset> assets;

  GitHubRelease({
    required this.id,
    required this.tagName,
    required this.name,
    required this.body,
    this.publishedAt,
    required this.isPrerelease,
    required this.assets,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    final rawAssets = json['assets'] as List<dynamic>? ?? [];
    final parsedAssets = rawAssets
        .whereType<Map<String, dynamic>>()
        .map((a) => GitHubReleaseAsset.fromJson(a))
        .toList();

    DateTime? publishedDate;
    if (json['published_at'] != null) {
      publishedDate = DateTime.tryParse(json['published_at'] as String);
    }

    return GitHubRelease(
      id: json['id'] as int? ?? 0,
      tagName: json['tag_name'] as String? ?? '',
      name: (json['name'] as String?)?.isNotEmpty == true
          ? json['name'] as String
          : (json['tag_name'] as String? ?? 'Release'),
      body: json['body'] as String? ?? '',
      publishedAt: publishedDate,
      isPrerelease: json['prerelease'] as bool? ?? false,
      assets: parsedAssets,
    );
  }

  /// ファームウェアバイナリアセット (firmware.bin を優先、なければ拡張子が .bin のもの)
  GitHubReleaseAsset? get firmwareAsset {
    try {
      return assets.firstWhere((a) => a.name == 'firmware.bin');
    } catch (_) {
      try {
        return assets.firstWhere((a) => a.name.toLowerCase().endsWith('.bin'));
      } catch (_) {
        return null;
      }
    }
  }

  bool get hasFirmware => firmwareAsset != null;
}
