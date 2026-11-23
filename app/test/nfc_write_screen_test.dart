import 'dart:async';

import 'package:controller_app/models/voice_preset.dart';
import 'package:controller_app/screens/nfc_write_screen.dart';
import 'package:controller_app/services/nfc_audio_transfer_service.dart';
import 'package:controller_app/services/nfc_service.dart';
import 'package:controller_app/services/nfc_uuid_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAudioTransferGateway implements NfcAudioTransferGateway {
  bool connected;
  int ensureConnectedCalls = 0;
  final List<({String devicePath, String sourceFilePath})> transfers = [];
  bool Function(String devicePath, String sourceFilePath)? onTransfer;

  final _progressController = StreamController<double>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  _FakeAudioTransferGateway({
    this.connected = false,
    this.onTransfer,
  });

  @override
  bool get isConnected => connected;

  @override
  String? get connectedDeviceName => connected ? 'ConnectedDoll2' : null;

  @override
  Stream<double> get transferProgressStream => _progressController.stream;

  @override
  Stream<String> get transferStatusStream => _statusController.stream;

  @override
  Future<bool> ensureConnected(BuildContext context) async {
    ensureConnectedCalls++;
    connected = true;
    return true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<bool> transferTriggerAudio({
    required String devicePath,
    required String sourceFilePath,
  }) async {
    transfers.add((devicePath: devicePath, sourceFilePath: sourceFilePath));
    _progressController.add(1.0);
    final ok = onTransfer != null ? onTransfer!(devicePath, sourceFilePath) : true;
    _statusController
        .add(ok ? 'Transfer completed successfully.' : 'Transfer failed');
    return ok;
  }
}

class _FakeNfcGateway implements NfcTagGateway {
  NfcReaderStatus status;
  Future<NfcWriteResult> Function(String uuid, String presetName)? onWrite;
  int cancelCalls = 0;
  String? lastWrittenUuid;
  String? lastWrittenName;

  _FakeNfcGateway({
    this.status = NfcReaderStatus.available,
    this.onWrite,
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
    throw UnimplementedError('読み込み確認UIは削除済み');
  }

  @override
  Future<void> cancelSession() async {
    cancelCalls++;
  }
}

void main() {
  testWidgets('登録プリセットが0件の場合は空状態と案内ボタンを表示し読み込み確認ボタンは存在しない',
      (tester) async {
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
    expect(find.text('NFCタグを読み込んで確認'), findsNothing);

    final writeButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'NFCタグに書き込む'),
    );
    expect(writeButton.onPressed, isNull);
  });

  testWidgets('初期選択とプルダウン切替でUUIDを発行・保存し、選択中プリセットをNFCタグへ書き込める',
      (tester) async {
    final gateway = _FakeNfcGateway();
    final savedUuids = <int, String>{};
    final presets = [
      VoicePreset(
        id: 10,
        name: 'キャラA',
        color: 0xFFEC4899,
        audioFiles: const {},
      ),
      VoicePreset(
        id: 20,
        name: 'キャラB',
        color: 0xFF6366F1,
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

    // 初期表示で先頭プリセットが自動選択され UUID が発行・保存される
    expect(savedUuids.containsKey(10), isTrue);
    final issuedUuidA = savedUuids[10]!;
    expect(const NfcUuidService().isValidUuid(issuedUuidA), isTrue);
    expect(find.textContaining(NfcUuidService.presetMimeType), findsOneWidget);
    expect(find.text('NFCタグを読み込んで確認'), findsNothing);

    // プルダウンを開いて キャラB に切り替え
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャラB').last);
    await tester.pumpAndSettle();

    expect(savedUuids.containsKey(20), isTrue);
    final issuedUuidB = savedUuids[20]!;
    expect(const NfcUuidService().isValidUuid(issuedUuidB), isTrue);
    expect(issuedUuidB, isNot(equals(issuedUuidA)));

    // 再度 キャラA に戻しても UUID は再発行されず維持される
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャラA').last);
    await tester.pumpAndSettle();
    expect(savedUuids[10], equals(issuedUuidA));

    // キャラB に切り替えて NFCタグ書き込みを実行
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャラB').last);
    await tester.pumpAndSettle();

    final writeBtn = find.text('NFCタグに書き込む');
    await tester.ensureVisible(writeBtn);
    await tester.tap(writeBtn);
    await tester.pumpAndSettle();

    expect(gateway.lastWrittenUuid, equals(issuedUuidB));
    expect(gateway.lastWrittenName, equals('キャラB'));
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

    await tester.tap(find.text('再発行'));
    await tester.pumpAndSettle();

    expect(find.text('UUIDを再発行しますか？'), findsOneWidget);
    await tester.tap(find.text('再発行する'));
    await tester.pumpAndSettle();

    expect(updatedUuid, isNotNull);
    expect(updatedUuid, isNot(equals(initialUuid)));
    expect(const NfcUuidService().isValidUuid(updatedUuid!), isTrue);
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

    final writeBtn = find.text('NFCタグに書き込む');
    await tester.ensureVisible(writeBtn);
    await tester.tap(writeBtn);
    await tester.pumpAndSettle();

    expect(find.text('このNFCタグは読み取り専用のため書き込めません。'), findsOneWidget);
  });

  testWidgets('NFC非対応端末では案内バナーを表示し書き込みボタンを無効化する', (tester) async {
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
    expect(find.text('NFCタグを読み込んで確認'), findsNothing);

    final writeButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'NFCタグに書き込む'),
    );
    expect(writeButton.onPressed, isNull);
  });

  testWidgets('一括転送で全プリセットのトリガー音声がUUID自動発行＋/nfc/<UUID>.wavで転送される',
      (tester) async {
    const existingUuid = '550e8400-e29b-41d4-a716-446655440000';
    final nfcGateway = _FakeNfcGateway();
    final transferGateway = _FakeAudioTransferGateway();
    final savedUuids = <int, String>{};

    final presets = [
      VoicePreset(
        id: 1,
        name: 'キャラ1',
        color: 0xFFEC4899,
        audioFiles: const {-1: '/tmp/voice1.wav'},
        audioFileNames: const {-1: 'voice1.wav'},
        nfcUuid: existingUuid,
      ),
      VoicePreset(
        id: 2,
        name: 'キャラ2',
        color: 0xFF6366F1,
        audioFiles: const {-1: '/tmp/voice2.mp3'},
        audioFileNames: const {-1: 'voice2.mp3'},
      ),
      VoicePreset(
        id: 3,
        name: '音声なしキャラ',
        color: 0xFF10B981,
        audioFiles: const {},
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: NfcWriteScreen(
          nfcService: nfcGateway,
          transferGateway: transferGateway,
          interFileTransferDelay: Duration.zero,
          loadPresets: () async => presets,
          savePresetUuid: (id, uuid) async {
            savedUuids[id] = uuid;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final batchBtn = find.text('全プリセットのトリガー音声を一括転送 (2件)');
    expect(batchBtn, findsOneWidget);
    await tester.ensureVisible(batchBtn);
    await tester.tap(batchBtn);
    await tester.pumpAndSettle();

    expect(transferGateway.ensureConnectedCalls, equals(1));
    expect(savedUuids.containsKey(1), isFalse); // 既存UUIDは維持
    expect(savedUuids.containsKey(2), isTrue);  // 未発行UUIDは自動発行・保存
    final issuedUuid2 = savedUuids[2]!;
    expect(const NfcUuidService().isValidUuid(issuedUuid2), isTrue);

    expect(transferGateway.transfers.length, equals(2));
    expect(
      transferGateway.transfers[0].devicePath,
      equals('nfc/$existingUuid.wav'),
    );
    expect(
      transferGateway.transfers[0].sourceFilePath,
      equals('/tmp/voice1.wav'),
    );
    expect(
      transferGateway.transfers[1].devicePath,
      equals('nfc/${issuedUuid2.toLowerCase()}.wav'),
    );
    expect(
      transferGateway.transfers[1].sourceFilePath,
      equals('/tmp/voice2.mp3'),
    );

    expect(find.text('トリガー音声転送完了'), findsOneWidget);
    expect(find.textContaining('成功 2件 / 失敗 0件'), findsOneWidget);
    expect(find.textContaining('音声未登録スキップ: 1件'), findsOneWidget);
  });

  testWidgets('プルダウン選択中プリセットの単体トリガー音声転送と失敗件数表示が機能する',
      (tester) async {
    const uuid = '11111111-2222-4333-8444-555555555555';
    final nfcGateway = _FakeNfcGateway();
    final transferGateway = _FakeAudioTransferGateway(
      connected: true,
      onTransfer: (_, _) => false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NfcWriteScreen(
          nfcService: nfcGateway,
          transferGateway: transferGateway,
          interFileTransferDelay: Duration.zero,
          loadPresets: () async => [
            VoicePreset(
              id: 7,
              name: '単体テストキャラ',
              color: 0xFFEC4899,
              audioFiles: const {-1: '/tmp/solo.wav'},
              audioFileNames: const {-1: 'solo.wav'},
              nfcUuid: uuid,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('デバイス保存先: /nfc/$uuid.wav'), findsOneWidget);

    final singleBtn = find.text('選択中プリセットのトリガー音声を転送');
    await tester.ensureVisible(singleBtn);
    await tester.tap(singleBtn);
    await tester.pumpAndSettle();

    expect(transferGateway.transfers.length, equals(1));
    expect(transferGateway.transfers.first.devicePath, equals('nfc/$uuid.wav'));
    expect(find.text('一部転送に失敗しました'), findsOneWidget);
    expect(find.textContaining('成功 0件 / 失敗 1件'), findsOneWidget);
  });
}
