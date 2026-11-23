import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'nfc_uuid_service.dart';

enum NfcReaderStatus {
  available,
  disabled,
  notSupported,
}

enum NfcErrorKind {
  notSupported,
  disabled,
  notNdef,
  notWritable,
  insufficientCapacity,
  tagRemoved,
  timeout,
  cancelled,
  invalidTagData,
  unknown,
}

class NfcOperationException implements Exception {
  final NfcErrorKind kind;
  final String message;
  final Object? cause;

  const NfcOperationException({
    required this.kind,
    required this.message,
    this.cause,
  });

  @override
  String toString() => message;
}

class NfcTagMetadata {
  final String id;
  final String standard;
  final String typeLabel;
  final int? capacityBytes;

  const NfcTagMetadata({
    required this.id,
    required this.standard,
    required this.typeLabel,
    this.capacityBytes,
  });
}

class NfcWriteResult {
  final NfcPresetPayload payload;
  final int writtenBytes;
  final NfcTagMetadata tag;

  const NfcWriteResult({
    required this.payload,
    required this.writtenBytes,
    required this.tag,
  });
}

class NfcReadResult {
  final NfcPresetPayload payload;
  final NfcTagMetadata tag;

  const NfcReadResult({
    required this.payload,
    required this.tag,
  });
}

abstract class NfcTagGateway {
  Future<NfcReaderStatus> checkAvailability();

  Future<NfcWriteResult> writePresetTag({
    required String uuid,
    required String presetName,
    Duration timeout = const Duration(seconds: 30),
  });

  Future<NfcReadResult> readPresetTag({
    Duration timeout = const Duration(seconds: 30),
  });

  Future<void> cancelSession();
}

class NfcService implements NfcTagGateway {
  final NfcUuidService uuidService;
  bool _cancelled = false;

  NfcService({this.uuidService = const NfcUuidService()});

  @override
  Future<NfcReaderStatus> checkAvailability() async {
    try {
      final availability = await FlutterNfcKit.nfcAvailability;
      switch (availability) {
        case NFCAvailability.available:
          return NfcReaderStatus.available;
        case NFCAvailability.disabled:
          return NfcReaderStatus.disabled;
        case NFCAvailability.not_supported:
          return NfcReaderStatus.notSupported;
      }
    } on MissingPluginException {
      return NfcReaderStatus.notSupported;
    } catch (_) {
      return NfcReaderStatus.notSupported;
    }
  }

  @override
  Future<NfcWriteResult> writePresetTag({
    required String uuid,
    required String presetName,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _cancelled = false;
    await _ensureAvailable();

    final record = uuidService.buildPresetMimeRecord(
      uuid: uuid,
      name: presetName,
    );
    final requiredBytes = record.encode().length;

    try {
      final tag = await FlutterNfcKit.poll(
        timeout: timeout,
        androidPlatformSound: true,
        androidCheckNDEF: true,
      );

      if (_cancelled) {
        throw const NfcOperationException(
          kind: NfcErrorKind.cancelled,
          message: 'NFC書き込みをキャンセルしました。',
        );
      }

      if (tag.ndefAvailable != true) {
        throw const NfcOperationException(
          kind: NfcErrorKind.notNdef,
          message: 'このNFCタグはNDEFフォーマットに未対応、または未初期化です。NDEF対応の書き込み可能タグを使用してください。',
        );
      }

      if (tag.ndefWritable != true) {
        throw const NfcOperationException(
          kind: NfcErrorKind.notWritable,
          message: 'このNFCタグは読み取り専用のため書き込めません。',
        );
      }

      final capacity = tag.ndefCapacity;
      if (capacity != null && capacity > 0 && requiredBytes > capacity) {
        throw NfcOperationException(
          kind: NfcErrorKind.insufficientCapacity,
          message:
              'タグの容量が不足しています（必要: ${requiredBytes}B / タグ容量: ${capacity}B）。プリセット名を短くするか、NTAG215/216 などの大容量タグをご使用ください。',
        );
      }

      await FlutterNfcKit.writeNDEFRecords([record]);

      return NfcWriteResult(
        payload: NfcPresetPayload(uuid: uuid.trim(), name: presetName),
        writtenBytes: requiredBytes,
        tag: _toMetadata(tag),
      );
    } on NfcOperationException {
      rethrow;
    } on PlatformException catch (e) {
      throw _mapPlatformException(e, isWrite: true);
    } catch (e) {
      if (_cancelled) {
        throw const NfcOperationException(
          kind: NfcErrorKind.cancelled,
          message: 'NFC書き込みをキャンセルしました。',
        );
      }
      throw NfcOperationException(
        kind: NfcErrorKind.unknown,
        message: 'NFCタグへの書き込みに失敗しました: $e',
        cause: e,
      );
    } finally {
      await _safeFinish();
    }
  }

  @override
  Future<NfcReadResult> readPresetTag({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _cancelled = false;
    await _ensureAvailable();

    try {
      final tag = await FlutterNfcKit.poll(
        timeout: timeout,
        androidPlatformSound: true,
        androidCheckNDEF: true,
      );

      if (_cancelled) {
        throw const NfcOperationException(
          kind: NfcErrorKind.cancelled,
          message: 'NFC読み込みをキャンセルしました。',
        );
      }

      if (tag.ndefAvailable != true) {
        throw const NfcOperationException(
          kind: NfcErrorKind.notNdef,
          message: 'このNFCタグはNDEFデータを含んでいません。',
        );
      }

      final records = await FlutterNfcKit.readNDEFRecords(cached: false);
      final payload = uuidService.parsePresetPayloadFromRecords(records);
      if (payload == null) {
        throw const NfcOperationException(
          kind: NfcErrorKind.invalidTagData,
          message:
              'このNFCタグには本アプリ形式（${NfcUuidService.presetMimeType}）のプリセットデータが記録されていません。',
        );
      }

      return NfcReadResult(
        payload: payload,
        tag: _toMetadata(tag),
      );
    } on NfcOperationException {
      rethrow;
    } on PlatformException catch (e) {
      throw _mapPlatformException(e, isWrite: false);
    } catch (e) {
      if (_cancelled) {
        throw const NfcOperationException(
          kind: NfcErrorKind.cancelled,
          message: 'NFC読み込みをキャンセルしました。',
        );
      }
      throw NfcOperationException(
        kind: NfcErrorKind.unknown,
        message: 'NFCタグの読み込みに失敗しました: $e',
        cause: e,
      );
    } finally {
      await _safeFinish();
    }
  }

  @override
  Future<void> cancelSession() async {
    _cancelled = true;
    await _safeFinish();
  }

  Future<void> _ensureAvailable() async {
    final status = await checkAvailability();
    if (status == NfcReaderStatus.notSupported) {
      throw const NfcOperationException(
        kind: NfcErrorKind.notSupported,
        message: 'この端末はNFCに対応していません。',
      );
    }
    if (status == NfcReaderStatus.disabled) {
      throw const NfcOperationException(
        kind: NfcErrorKind.disabled,
        message: '端末のNFC機能が無効です。設定からNFCをオンにしてください。',
      );
    }
  }

  NfcTagMetadata _toMetadata(NFCTag tag) {
    return NfcTagMetadata(
      id: tag.id,
      standard: tag.standard,
      typeLabel: tag.ndefType?.isNotEmpty == true ? tag.ndefType! : tag.type.name,
      capacityBytes:
          tag.ndefCapacity != null && tag.ndefCapacity! > 0 ? tag.ndefCapacity : null,
    );
  }

  NfcOperationException _mapPlatformException(
    PlatformException e, {
    required bool isWrite,
  }) {
    if (_cancelled) {
      return NfcOperationException(
        kind: NfcErrorKind.cancelled,
        message: isWrite ? 'NFC書き込みをキャンセルしました。' : 'NFC読み込みをキャンセルしました。',
        cause: e,
      );
    }
    switch (e.code) {
      case '404':
        return NfcOperationException(
          kind: NfcErrorKind.disabled,
          message: '端末のNFC機能が無効です。設定からNFCをオンにしてください。',
          cause: e,
        );
      case '405':
        return NfcOperationException(
          kind: NfcErrorKind.notWritable,
          message: isWrite
              ? 'このNFCタグはNDEF書き込みに対応していないか、読み取り専用です。'
              : 'このNFCタグはNDEF読み込みに対応していません。',
          cause: e,
        );
      case '408':
        return NfcOperationException(
          kind: NfcErrorKind.timeout,
          message: 'NFCタグが検出されませんでした（タイムアウト）。もう一度お試しください。',
          cause: e,
        );
      case '503':
        return NfcOperationException(
          kind: NfcErrorKind.tagRemoved,
          message: '処理中にNFCタグが離れました。完了するまで端末背面にかざしたままにしてください。',
          cause: e,
        );
      case '500':
        return NfcOperationException(
          kind: NfcErrorKind.tagRemoved,
          message: 'NFCタグとの通信に失敗しました。タグをかざし直して再試行してください。',
          cause: e,
        );
      default:
        return NfcOperationException(
          kind: NfcErrorKind.unknown,
          message:
              '${isWrite ? "NFC書き込み" : "NFC読み込み"}エラー (${e.code}): ${e.message ?? "詳細不明"}',
          cause: e,
        );
    }
  }

  Future<void> _safeFinish() async {
    try {
      await FlutterNfcKit.finish();
    } catch (_) {}
  }
}
