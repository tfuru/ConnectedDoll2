import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/github_release.dart';

class GitHubReleaseService {
  static const String defaultRepository = 'tfuru/ConnectedDoll2';

  /// GitHubリポジトリのリリース一覧を取得
  static Future<List<GitHubRelease>> fetchReleases({String repository = defaultRepository}) async {
    final cleanRepo = repository.trim().replaceAll('https://github.com/', '');
    final uri = Uri.parse('https://api.github.com/repos/$cleanRepo/releases');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'ConnectedDoll2-App',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body) as List<dynamic>;
      return jsonList
          .whereType<Map<String, dynamic>>()
          .map((item) => GitHubRelease.fromJson(item))
          .toList();
    } else if (response.statusCode == 404) {
      throw Exception('リポジトリ "$cleanRepo" が見つかりませんでした (404)。リポジトリ名を確認してください。');
    } else if (response.statusCode == 403) {
      throw Exception('GitHub APIの利用制限 (Rate Limit) に達しました。しばらく待ってから再試行してください。');
    } else {
      throw Exception('リリース情報の取得に失敗しました (ステータスコード: ${response.statusCode})');
    }
  }

  /// ファームウェアバイナリアセットをダウンロード
  static Future<Uint8List> downloadFirmware(
    GitHubReleaseAsset asset, {
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.parse(asset.downloadUrl);
    final request = http.Request('GET', uri);
    request.headers.addAll({
      'Accept': 'application/octet-stream',
      'User-Agent': 'ConnectedDoll2-App',
    });

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception('ファームウェアのダウンロードに失敗しました (ステータス: ${streamedResponse.statusCode})');
      }

      final contentLength = streamedResponse.contentLength ?? asset.size;
      final bytes = <int>[];
      int downloaded = 0;

      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        downloaded += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          final progress = (downloaded / contentLength).clamp(0.0, 1.0);
          onProgress(progress);
        }
      }

      return Uint8List.fromList(bytes);
    } finally {
      client.close();
    }
  }
}
