import 'package:controller_app/models/voice_preset.dart';
import 'package:controller_app/screens/nfc_write_screen.dart';
import 'package:controller_app/services/nfc_service.dart';
import 'package:controller_app/services/nfc_uuid_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNfcGateway implements NfcTagGateway {
  NfcReaderStatus status;
  Future<NfcWriteResult> Function(String uuid, String presetName)? onWrite;
  Future<NfcReadResult> Function()? onRead;
  int cancelCalls = 0;
  String? lastWrittenUuid;
  String? lastWrittenName;

  _FakeNfcGateway({
    this.status = NfcReaderStatus.available,
    this.onWrite,
    this.onRead,
  });

  @override
  Future<NfcReaderStatus> checkAvailability() async => status;

  @override
  Future<NfcWriteResult> writePresetTag({
    required String uuid,
    required String presetName,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    lastWrittenUuid = uuid;
    lastWrittenName = presetName;
    if (onWrite != null) {
      return onWrite!(uuid, presetName);
    }
    return NfcWriteResult(
      payload: NfcPresetPayload(uuid: uuid, name: presetName),
      writtenBytes: 108,
      tag: const NfcTagMetadata(
        id: '04AABBCCDD1122',
        standard: 'ISO 14443-3 (Type A)',
        typeLabel: 'NFC Forum Type 2',
        capacityBytes: 504,
      ),
    );
  }

  @override
  Future<NfcReadResult> readPresetTag({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (onRead != null) {
      return onRead!();
    }
    throw const NfcOperationException(
      kind: NfcErrorKind.invalidTagData,
      message: 'データなし',
    );
  }

  @override
  Future<void> cancelSession() async {
    cancelCalls++;
  }
}

void main() {
  testWidgets('登録プリセットが0件の場合は空状態と案内ボタンを表示する', (tester) async {
    final gateway = _FakeNfcGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: NfcWriteScreen(
          nfcService: gateway,
          loadPresets: () async => [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('登録済みの音声プリセットがありません'), findsOneWidget);
    expect(find.text('音声プリセット一覧へ'), findsOneWidget);

    final writeButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'NFCタグに書き込む'),
    );
    expect(writeButton.onPressed, isNull);
  });

  testWidgets('プリセット選択でUUIDを発行・保存し、NFCタグ書き込みが完了する', (tester) async {
    final gateway = _FakeNfcGateway();
    final savedUuids = <int, String>{};
    final presets = [
      VoicePreset(
        id: 10,
        name: 'キャラA',
        color: 0xFFEC4899,
        audioFiles: const {},
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: NfcWriteScreen(
          nfcService: gateway,
          loadPresets: () async => presets,
          savePresetUuid: (id, uuid) async {
            savedUuids[id] = uuid;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('タップしてUUIDを発行'), findsOneWidget);

    // プリセット名を選択
    await tester.tap(find.text('キャラA'));
    await tester.pumpAndSettle();

    expect(savedUuids.containsKey(10), isTrue);
    final issuedUuid = savedUuids[10]!;
    expect(const NfcUuidService().isValidUuid(issuedUuid), isTrue);
    expect(find.textContaining(NfcUuidService.presetMimeType), findsOneWidget);

    // 再度タップしても同じUUIDが維持される（再発行されない）
    await tester.tap(find.text('キャラA'));
    await tester.pumpAndSettle();
    expect(savedUuids[10], equals(issuedUuid));

    // NFCタグ書き込みを実行
    final writeBtn = find.text('NFCタグに書き込む');
    await tester.ensureVisible(writeBtn);
    await tester.tap(writeBtn);
    await tester.pumpAndSettle();

    expect(gateway.lastWrittenUuid, equals(issuedUuid));
    expect(gateway.lastWrittenName, equals('キャラA'));
    expect(find.text('書き込み完了'), findsOneWidget);
    expect(find.text('04AABBCCDD1122'), findsOneWidget);
  });

  testWidgets('UUID再発行で確認ダイアログ経由で新しいUUIDが保存される', (tester) async {
    const initialUuid = '550e8400-e29b-41d4-a716-446655440000';
    final gateway = _FakeNfcGateway();
    String? updatedUuid;

    await tester.pumpWidget(
      MaterialApp(
        home: NfcWriteScreen(
          nfcService: gateway,
          loadPresets: () async => [
            VoicePreset(
              id: 2,
              name: 'キャラB',
              color: 0xFF6366F1,
              audioFiles: const {},
              nfcUuid: initialUuid,
            ),
          ],
          savePresetUuid: (id, uuid) async {
            updatedUuid = uuid;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('キャラB'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('再発行'));
    await tester.pumpAndSettle();

    expect(find.text('UUIDを再発行しますか？'), findsOneWidget);
    await tester.tap(find.text('再発行する'));
    await tester.pumpAndSettle();

    expect(updatedUuid, isNotNull);
    expect(updatedUuid, isNot(equals(initialUuid)));
    expect(const NfcUuidService().isValidUuid(updatedUuid!), isTrue);
  });

  testWidgets('NFC読み込み確認で登録済みプリセットとの照合結果が表示される', (tester) async {
    const uuid = '11111111-2222-4333-8444-555555555555';
    final preset = VoicePreset(
      id: 3,
      name: 'キャラC',
      color: 0xFF10B981,
      audioFiles: const {},
      nfcUuid: uuid,
    );
    final gateway = _FakeNfcGateway(
      onRead: () async => const NfcReadResult(
        payload: NfcPresetPayload(uuid: uuid, name: 'キャラC'),
        tag: NfcTagMetadata(
          id: '0411223344',
          standard: 'ISO 14443-3 (Type A)',
          typeLabel: 'NFC Forum Type 2',
          capacityBytes: 144,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NfcWriteScreen(
          nfcService: gateway,
          loadPresets: () async => [preset],
          findPresetByUuid: (lookup) async => lookup == uuid ? preset : null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final readBtn = find.text('NFCタグを読み込んで確認');
    await tester.ensureVisible(readBtn);
    await tester.tap(readBtn);
    await tester.pumpAndSettle();

    expect(find.text('NFCタグ読み込み結果'), findsOneWidget);
    expect(find.text('一致: キャラC'), findsOneWidget);
  });

  testWidgets('NFC書き込みエラー時は日本語エラーメッセージを表示する', (tester) async {
    final gateway = _FakeNfcGateway(
      onWrite: (_, _) async {
        throw const NfcOperationException(
          kind: NfcErrorKind.notWritable,
          message: 'このNFCタグは読み取り専用のため書き込めません。',
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NfcWriteScreen(
          nfcService: gateway,
          loadPresets: () async => [
            VoicePreset(
              id: 5,
              name: 'キャラD',
              color: 0xFFEC4899,
              audioFiles: const {},
              nfcUuid: '22222222-3333-4444-8555-666666666666',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('キャラD'));
    await tester.pumpAndSettle();

    final writeBtn = find.text('NFCタグに書き込む');
    await tester.ensureVisible(writeBtn);
    await tester.tap(writeBtn);
    await tester.pumpAndSettle();

    expect(find.text('このNFCタグは読み取り専用のため書き込めません。'), findsOneWidget);
  });

  testWidgets('NFC非対応端末では案内バナーを表示し操作ボタンを無効化する', (tester) async {
    final gateway = _FakeNfcGateway(status: NfcReaderStatus.notSupported);

    await tester.pumpWidget(
      MaterialApp(
        home: NfcWriteScreen(
          nfcService: gateway,
          loadPresets: () async => [
            VoicePreset(
              id: 6,
              name: 'キャラE',
              color: 0xFFEC4899,
              audioFiles: const {},
              nfcUuid: '33333333-4444-4555-8666-777777777777',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('この端末は NFC に対応していません'), findsOneWidget);

    await tester.tap(find.text('キャラE'));
    await tester.pumpAndSettle();

    final writeButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'NFCタグに書き込む'),
    );
    final readButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'NFCタグを読み込んで確認'),
    );
    expect(writeButton.onPressed, isNull);
    expect(readButton.onPressed, isNull);
  });
}
