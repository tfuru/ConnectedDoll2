import 'dart:convert';
import 'dart:typed_data';

import 'package:ndef/ndef.dart' as ndef;
import 'package:uuid/uuid.dart';

class NfcPresetPayload {
  final String uuid;
  final String name;

  const NfcPresetPayload({
    required this.uuid,
    required this.name,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NfcPresetPayload &&
        other.uuid == uuid &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(uuid, name);
}

class NfcUuidService {
  static const String presetMimeType = 'application/vnd.connecteddoll.preset';
  static const int ntag213RecommendedMaxBytes = 137;

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final Uuid uuid;

  const NfcUuidService({this.uuid = const Uuid()});

  /// RFC 4122 準拠の UUID v4 を発行する
  String generateUuid() => uuid.v4();

  /// UUID 文字列の形式を検証する
  bool isValidUuid(String value) => _uuidPattern.hasMatch(value.trim());

  /// NDEF MIME レコードのペイロード JSON 文字列を構築する
  String encodePayloadJson({
    required String uuid,
    required String name,
  }) {
    final normalizedUuid = uuid.trim();
    if (!isValidUuid(normalizedUuid)) {
      throw ArgumentError.value(uuid, 'uuid', 'UUID形式が不正です');
    }
    return jsonEncode({
      'uuid': normalizedUuid,
      'name': name,
    });
  }

  /// プリセット用 NDEF MIME レコード（application/vnd.connecteddoll.preset）を生成する
  ndef.MimeRecord buildPresetMimeRecord({
    required String uuid,
    required String name,
  }) {
    final jsonString = encodePayloadJson(uuid: uuid, name: name);
    final payloadBytes = Uint8List.fromList(utf8.encode(jsonString));
    return ndef.MimeRecord(
      decodedType: presetMimeType,
      payload: payloadBytes,
    );
  }

  /// エンコード後の NDEF レコード総バイト数を算出する
  int estimateNdefRecordBytes({
    required String uuid,
    required String name,
  }) {
    return buildPresetMimeRecord(uuid: uuid, name: name).encode().length;
  }

  /// NDEF レコード一覧からプリセット MIME ペイロードを抽出・パースする
  NfcPresetPayload? parsePresetPayloadFromRecords(
    List<ndef.NDEFRecord> records,
  ) {
    for (final record in records) {
      if (record.tnf != ndef.TypeNameFormat.media) continue;
      final mimeType = record.decodedType?.toLowerCase();
      if (mimeType != presetMimeType) continue;
      final payloadBytes = record.payload;
      if (payloadBytes == null || payloadBytes.isEmpty) continue;

      try {
        final decoded = jsonDecode(utf8.decode(payloadBytes));
        if (decoded is! Map<String, dynamic>) continue;
        final uuid = decoded['uuid'];
        final name = decoded['name'];
        if (uuid is! String || !isValidUuid(uuid)) continue;
        return NfcPresetPayload(
          uuid: uuid.trim(),
          name: name is String ? name : '',
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
