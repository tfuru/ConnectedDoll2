import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../widgets/device_selection_bottom_sheet.dart';
import 'audio_service.dart';
import 'ble_service.dart';

class PresetAudioTransferItemResult {
  final String presetName;
  final String uuid;
  final String devicePath;
  final bool success;
  final String? errorMessage;

  const PresetAudioTransferItemResult({
    required this.presetName,
    required this.uuid,
    required this.devicePath,
    required this.success,
    this.errorMessage,
  });
}

class BatchAudioTransferResult {
  final List<PresetAudioTransferItemResult> items;
  final int skippedNoAudioCount;

  const BatchAudioTransferResult({
    required this.items,
    this.skippedNoAudioCount = 0,
  });

  int get successCount => items.where((item) => item.success).length;
  int get failureCount => items.where((item) => !item.success).length;
  bool get allSucceeded => items.isNotEmpty && failureCount == 0;
}

abstract class NfcAudioTransferGateway {
  bool get isConnected;
  String? get connectedDeviceName;
  Stream<double> get transferProgressStream;
  Stream<String> get transferStatusStream;

  Future<bool> ensureConnected(BuildContext context);
  Future<void> disconnect();

  /// トリガー音声を推奨WAVへ変換し、デバイス上の指定パス（例: `nfc/<uuid>.wav`）へ転送する
  Future<bool> transferTriggerAudio({
    required String devicePath,
    required String sourceFilePath,
  });
}

class BleNfcAudioTransferGateway implements NfcAudioTransferGateway {
  final BleService _bleService;

  BleNfcAudioTransferGateway({BleService? bleService})
      : _bleService = bleService ?? BleService();

  @override
  bool get isConnected => _bleService.connectedDevice != null;

  @override
  String? get connectedDeviceName =>
      _bleService.connectedDevice?.name ??
      _bleService.connectedDevice?.deviceId;

  @override
  Stream<double> get transferProgressStream =>
      _bleService.transferProgressController.stream;

  @override
  Stream<String> get transferStatusStream =>
      _bleService.transferStatusController.stream;

  @override
  Future<bool> ensureConnected(BuildContext context) async {
    if (_bleService.connectedDevice != null) {
      return true;
    }
    return DeviceSelectionBottomSheet.show(context);
  }

  @override
  Future<void> disconnect() async {
    if (_bleService.connectedDevice != null) {
      await _bleService.disconnect();
    }
  }

  @override
  Future<bool> transferTriggerAudio({
    required String devicePath,
    required String sourceFilePath,
  }) async {
    final sourceFile = File(sourceFilePath);
    if (!await sourceFile.exists()) {
      _bleService.transferStatusController.add('Error: Audio file not found');
      return false;
    }

    _bleService.transferProgressController.add(0.0);
    _bleService.transferStatusController.add('推奨WAV形式へ変換中...');

    final convertedFile =
        await AudioService.convertToRecommendedWav(sourceFilePath);
    if (convertedFile == null) {
      _bleService.transferStatusController.add('Error: Audio conversion failed');
      return false;
    }

    try {
      final bytes = await convertedFile.readAsBytes();
      return await _bleService.transferFile(devicePath, bytes);
    } finally {
      // 元ファイルが既に推奨WAVだった場合、convertToRecommendedWavは元Fileをそのまま返すため削除しない
      if (convertedFile.path != sourceFilePath) {
        try {
          if (await convertedFile.exists()) {
            await convertedFile.delete();
          }
        } catch (_) {}
      }
    }
  }
}
