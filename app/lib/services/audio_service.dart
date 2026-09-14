import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  /// 入力された音声（MP3, M4A, WAV等）を、ファームウェア推奨フォーマット（16kHz / 16-bit / モノラル WAV）に変換する
  static Future<File?> convertToRecommendedWav(String inputPath) async {
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        debugPrint('[AudioService] Input file does not exist: $inputPath');
        return null;
      }

      // すでに 16kHz / 16-bit / モノラル の WAV である場合はそのまま使用
      if (await _isAlreadyRecommendedWav(inputFile)) {
        debugPrint('[AudioService] File is already in recommended format (16kHz, 16-bit, Mono WAV)');
        return inputFile;
      }

      final tempDir = await getTemporaryDirectory();
      final outputWavPath = '${tempDir.path}/converted_recommended_${DateTime.now().millisecondsSinceEpoch}.wav';
      final outputFile = File(outputWavPath);
      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      debugPrint('[AudioService] Converting audio to 16kHz Mono 16-bit WAV using native AudioDecoder...');

      // 1. OSネイティブの高品質デコーダー・リサンプラーを直接使用（CoreAudio / MediaCodec）
      try {
        await AudioDecoder.convertToWav(
          inputPath,
          outputWavPath,
          sampleRate: 16000,
          channels: 1,
          bitDepth: 16,
        );

        if (await outputFile.exists() && await outputFile.length() > 44) {
          debugPrint('[AudioService] Native conversion successful! Output size: ${await outputFile.length()} bytes');
          return outputFile;
        }
      } catch (nativeErr) {
        debugPrint('[AudioService] Native parameterized convertToWav failed ($nativeErr). Trying fallback resampler...');
      }

      // 2. フォールバック: パラメータなしで一度WAVにデコードし、Dart側でリサンプリング
      return await _fallbackDartResample(inputPath, tempDir);
    } catch (e, stack) {
      debugPrint('[AudioService] Error during transcoding: $e\n$stack');
      return null;
    }
  }

  /// すでに 16kHz, 16-bit, Mono PCM の WAV ファイルかどうかを判定
  static Future<bool> _isAlreadyRecommendedWav(File file) async {
    try {
      if (!file.path.toLowerCase().endsWith('.wav')) return false;
      final bytes = await file.openRead(0, 44).first;
      if (bytes.length < 44) return false;

      // RIFFヘッダー確認
      if (bytes[0] != 0x52 || bytes[1] != 0x49 || bytes[2] != 0x46 || bytes[3] != 0x46) return false;
      // WAVE確認
      if (bytes[8] != 0x57 || bytes[9] != 0x41 || bytes[10] != 0x56 || bytes[11] != 0x45) return false;

      final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
      final audioFormat = byteData.getUint16(20, Endian.little);
      final numChannels = byteData.getUint16(22, Endian.little);
      final sampleRate = byteData.getUint32(24, Endian.little);
      final bitsPerSample = byteData.getUint16(34, Endian.little);

      return audioFormat == 1 && numChannels == 1 && sampleRate == 16000 && bitsPerSample == 16;
    } catch (_) {
      return false;
    }
  }

  /// Dart側でのフォールバックリサンプリング処理
  static Future<File?> _fallbackDartResample(String inputPath, Directory tempDir) async {
    final decodedWavPath = '${tempDir.path}/decoded_temp_${DateTime.now().millisecondsSinceEpoch}.wav';
    final decodedFile = File(decodedWavPath);
    try {
      final decodeResult = await AudioDecoder.convertToWav(inputPath, decodedWavPath);
      if (decodeResult.isEmpty || !await decodedFile.exists()) {
        debugPrint('[AudioService] Fallback: Decoding to intermediate WAV failed.');
        return null;
      }

      final wavBytes = await decodedFile.readAsBytes();
      if (wavBytes.length < 44) return null;

      final byteData = ByteData.sublistView(wavBytes);
      final numChannels = byteData.getUint16(22, Endian.little);
      final sampleRate = byteData.getUint32(24, Endian.little);
      final bitsPerSample = byteData.getUint16(34, Endian.little);

      if (bitsPerSample != 16) {
        debugPrint('[AudioService] Fallback: Only 16-bit PCM is supported by Dart resampler (got $bitsPerSample bit).');
        return null;
      }

      // 'data' チャンクの開始位置を探索
      int dataOffset = 44;
      for (int i = 12; i < wavBytes.length - 8; i++) {
        if (wavBytes[i] == 0x64 && // 'd'
            wavBytes[i + 1] == 0x61 && // 'a'
            wavBytes[i + 2] == 0x74 && // 't'
            wavBytes[i + 3] == 0x61) { // 'a'
          dataOffset = i + 8;
          break;
        }
      }

      final pcmByteData = ByteData.sublistView(wavBytes, dataOffset);
      final totalSamples = (wavBytes.length - dataOffset) ~/ 2;

      // モノラル化
      List<int> monoSamples = [];
      if (numChannels == 1) {
        for (int i = 0; i < totalSamples; i++) {
          monoSamples.add(pcmByteData.getInt16(i * 2, Endian.little));
        }
      } else if (numChannels == 2) {
        for (int i = 0; i < totalSamples - 1; i += 2) {
          int left = pcmByteData.getInt16(i * 2, Endian.little);
          int right = pcmByteData.getInt16((i + 1) * 2, Endian.little);
          monoSamples.add((left + right) ~/ 2);
        }
      } else {
        debugPrint('[AudioService] Fallback: Unsupported channel count ($numChannels).');
        return null;
      }

      // 16000 Hz へのダウンサンプリング (線形補間)
      final double ratio = sampleRate / 16000.0;
      final int outLength = (monoSamples.length / ratio).floor();
      final List<int> resampledSamples = [];

      for (int i = 0; i < outLength; i++) {
        double pos = i * ratio;
        int idx = pos.floor();
        double frac = pos - idx;

        if (idx >= monoSamples.length) break;

        int s0 = monoSamples[idx];
        int s1 = (idx + 1 < monoSamples.length) ? monoSamples[idx + 1] : s0;

        int interpolated = (s0 * (1.0 - frac) + s1 * frac).round();
        interpolated = interpolated.clamp(-32768, 32767);
        resampledSamples.add(interpolated);
      }

      final outputWavPath = '${tempDir.path}/converted_recommended_${DateTime.now().millisecondsSinceEpoch}.wav';
      final outputFile = File(outputWavPath);
      final outDataSize = resampledSamples.length * 2;
      final outWavBytes = Uint8List(44 + outDataSize);
      final outByteData = ByteData.view(outWavBytes.buffer);

      outWavBytes.setRange(0, 4, ascii.encode('RIFF'));
      outByteData.setUint32(4, 36 + outDataSize, Endian.little);
      outWavBytes.setRange(8, 12, ascii.encode('WAVE'));
      outWavBytes.setRange(12, 16, ascii.encode('fmt '));
      outByteData.setUint32(16, 16, Endian.little);
      outByteData.setUint16(20, 1, Endian.little);
      outByteData.setUint16(22, 1, Endian.little);
      outByteData.setUint32(24, 16000, Endian.little);
      outByteData.setUint32(28, 16000 * 1 * 2, Endian.little);
      outByteData.setUint16(32, 1 * 2, Endian.little);
      outByteData.setUint16(34, 16, Endian.little);
      outWavBytes.setRange(36, 40, ascii.encode('data'));
      outByteData.setUint32(40, outDataSize, Endian.little);

      final outPcmView = Int16List.view(outWavBytes.buffer, 44, resampledSamples.length);
      for (int i = 0; i < resampledSamples.length; i++) {
        outPcmView[i] = resampledSamples[i];
      }

      await outputFile.writeAsBytes(outWavBytes);
      debugPrint('[AudioService] Fallback conversion complete! Size: ${outWavBytes.length} bytes');
      return outputFile;
    } finally {
      try {
        if (await decodedFile.exists()) {
          await decodedFile.delete();
        }
      } catch (_) {}
    }
  }

  // ファイル存在確認
  static Future<File?> verifyAndGetWav(String inputPath) async {
    try {
      final file = File(inputPath);
      if (!await file.exists()) return null;
      return file;
    } catch (e) {
      debugPrint('[AudioService] Error in verifyAndGetWav: $e');
      return null;
    }
  }
}
