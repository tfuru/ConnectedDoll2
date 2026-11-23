import 'dart:convert';
import 'dart:typed_data';

import 'package:controller_app/models/voice_preset.dart';
import 'package:controller_app/services/nfc_uuid_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndef/ndef.dart' as ndef;

void main() {
  const service = NfcUuidService();

  group('NfcUuidService', () {
    test('generateUuid generates valid unique UUID v4 values', () {
      final first = service.generateUuid();
      final second = service.generateUuid();

      expect(service.isValidUuid(first), isTrue);
      expect(service.isValidUuid(second), isTrue);
      expect(first, isNot(equals(second)));
      // UUID v4 has '4' at index 14
      expect(first[14], equals('4'));
    });

    test('isValidUuid validates UUID strings accurately', () {
      expect(
        service.isValidUuid('550e8400-e29b-41d4-a716-446655440000'),
        isTrue,
      );
      expect(
        service.isValidUuid('  550E8400-E29B-41D4-A716-446655440000  '),
        isTrue,
      );
      expect(service.isValidUuid(''), isFalse);
      expect(service.isValidUuid('not-a-uuid'), isFalse);
      expect(
        service.isValidUuid('550e8400-e29b-41d4-a716-44665544000g'),
        isFalse,
      );
    });

    test('encodePayloadJson rejects invalid UUIDs', () {
      expect(
        () => service.encodePayloadJson(uuid: 'invalid', name: 'テスト'),
        throwsArgumentError,
      );
    });

    test('buildPresetMimeRecord and parsePresetPayloadFromRecords round-trip Japanese names', () {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      const name = '推しキャラA';

      final record = service.buildPresetMimeRecord(uuid: uuid, name: name);
      expect(record.tnf, equals(ndef.TypeNameFormat.media));
      expect(record.decodedType, equals(NfcUuidService.presetMimeType));

      final decodedJson =
          jsonDecode(utf8.decode(record.payload!)) as Map<String, dynamic>;
      expect(decodedJson['uuid'], equals(uuid));
      expect(decodedJson['name'], equals(name));

      final parsed = service.parsePresetPayloadFromRecords([record]);
      expect(parsed, equals(const NfcPresetPayload(uuid: uuid, name: name)));

      final estimatedBytes = service.estimateNdefRecordBytes(
        uuid: uuid,
        name: name,
      );
      expect(estimatedBytes, equals(record.encode().length));
      expect(estimatedBytes, greaterThan(90));
    });

    test('parsePresetPayloadFromRecords ignores non-matching or malformed records', () {
      final textRecord = ndef.TextRecord(text: 'hello', language: 'en');
      final otherMime = ndef.MimeRecord(
        decodedType: 'application/json',
        payload: Uint8List.fromList(
          utf8.encode('{"uuid":"550e8400-e29b-41d4-a716-446655440000","name":"x"}'),
        ),
      );
      final malformedJson = ndef.MimeRecord(
        decodedType: NfcUuidService.presetMimeType,
        payload: Uint8List.fromList(utf8.encode('{invalid')),
      );
      final invalidUuid = ndef.MimeRecord(
        decodedType: NfcUuidService.presetMimeType,
        payload: Uint8List.fromList(
          utf8.encode('{"uuid":"bad-uuid","name":"x"}'),
        ),
      );

      expect(
        service.parsePresetPayloadFromRecords([
          textRecord,
          otherMime,
          malformedJson,
          invalidUuid,
        ]),
        isNull,
      );
    });
  });

  group('VoicePreset nfcUuid serialization', () {
    test('toMap, fromMap, and copyWith preserve nfcUuid', () {
      const uuid = '550e8400-e29b-41d4-a716-446655440000';
      final preset = VoicePreset(
        id: 1,
        name: 'ボイス1',
        color: 0xFFEC4899,
        audioFiles: const {},
        nfcUuid: uuid,
      );

      final map = preset.toMap();
      expect(map['nfc_uuid'], equals(uuid));

      final restored = VoicePreset.fromMap(map);
      expect(restored.nfcUuid, equals(uuid));

      final updated = restored.copyWith(name: 'ボイス1改');
      expect(updated.name, equals('ボイス1改'));
      expect(updated.nfcUuid, equals(uuid));
    });
  });
}
