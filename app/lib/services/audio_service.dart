import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audio_decoder/audio_decoder.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  // 入力された音声（MP3, M4A, WAV等）を、16kHz / 16-bit / モノラル のWAVにトランスコードする
  static Future<File?> convertToRecommendedWav(String inputPath) async {
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) return null;

      final tempDir = await getTemporaryDirectory();
      // audio_decoder が一時出力するWAVのパス
      final decodedWavPath = '${tempDir.path}/decoded_temp.wav';
      final decodedFile = File(decodedWavPath);
      if (await decodedFile.exists()) {
        await decodedFile.delete();
      }

      print('Decoding input audio to temporary WAV using native APIs...');
      // 1. OS標準のデコーダーを使用して一時WAV（リニアPCM）にデコード
      final decodeResult = await AudioDecoder.convertToWav(inputPath, decodedWavPath);
      if (decodeResult.isEmpty || !await decodedFile.exists()) {
        print('Decoding failed.');
        return null;
      }

      print('Decoding success. Starting Dart resampler (16kHz, Mono, 16bit)...');
      // 2. デコードされたWAVのバイトデータを読み込み
      final wavBytes = await decodedFile.readAsBytes();
      
      // WAVヘッダーの簡易解析 (先頭44バイト)
      if (wavBytes.length < 44) return null;
      
      final byteData = ByteData.sublistView(wavBytes);
      
      // チャンネル数 (Offset 22, 16bit)
      final numChannels = byteData.getUint16(22, Endian.little);
      // サンプリングレート (Offset 24, 32bit)
      final sampleRate = byteData.getUint32(24, Endian.little);
      // ビット深度 (Offset 34, 16bit)
      final bitsPerSample = byteData.getUint16(34, Endian.little);
      
      print('Input Audio format: $sampleRate Hz, $numChannels Ch, $bitsPerSample bit');

      if (bitsPerSample != 16) {
        print('Error: Only 16-bit PCM is currently supported by the resampler.');
        return null;
      }

      // 44バイト以降がPCMデータ
      final pcmBytes = Uint8List.sublistView(wavBytes, 44);
      final int16List = Int16List.view(pcmBytes.buffer, pcmBytes.offsetInBytes, pcmBytes.length ~/ 2);

      // A. モノラル化
      List<int> monoSamples = [];
      if (numChannels == 1) {
        monoSamples = int16List.toList();
      } else if (numChannels == 2) {
        // ステレオ（L/R）を平均してモノラルにする
        for (int i = 0; i < int16List.length; i += 2) {
          int left = int16List[i];
          int right = (i + 1 < int16List.length) ? int16List[i + 1] : left;
          monoSamples.add((left + right) ~/ 2);
        }
      } else {
        print('Error: Unsupported channel count ($numChannels).');
        return null;
      }

      // B. 16000 Hz へのダウンサンプリング (線形補間)
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

        // 線形補間
        int interpolated = (s0 * (1.0 - frac) + s1 * frac).round();
        // 16-bit 符号付き整数の範囲にクランプ
        interpolated = interpolated.clamp(-32768, 32767);
        resampledSamples.add(interpolated);
      }

      // C. 推奨WAVヘッダーの生成とファイルの書き出し
      final outputWavPath = '${tempDir.path}/converted_recommended.wav';
      final outputFile = File(outputWavPath);
      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      final outDataSize = resampledSamples.length * 2; // 16bit = 2bytes/sample
      final outWavBytes = Uint8List(44 + outDataSize);
      final outByteData = ByteData.view(outWavBytes.buffer);

      // "RIFF" header
      outWavBytes.setRange(0, 4, ascii.encode('RIFF'));
      outByteData.setUint32(4, 36 + outDataSize, Endian.little); // File size - 8
      outWavBytes.setRange(8, 12, ascii.encode('WAVE'));

      // "fmt " sub-chunk
      outWavBytes.setRange(12, 16, ascii.encode('fmt '));
      outByteData.setUint32(16, 16, Endian.little); // Subchunk1Size
      outByteData.setUint16(20, 1, Endian.little); // AudioFormat: 1 = PCM (Linear)
      outByteData.setUint16(22, 1, Endian.little); // NumChannels: 1 (Mono)
      outByteData.setUint32(24, 16000, Endian.little); // SampleRate: 16000 Hz
      outByteData.setUint32(28, 16000 * 1 * 2, Endian.little); // ByteRate = SampleRate * NumChannels * BitsPerSample/8
      outByteData.setUint16(32, 1 * 2, Endian.little); // BlockAlign = NumChannels * BitsPerSample/8
      outByteData.setUint16(34, 16, Endian.little); // BitsPerSample: 16 bit

      // "data" sub-chunk
      outWavBytes.setRange(36, 40, ascii.encode('data'));
      outByteData.setUint32(40, outDataSize, Endian.little); // DataSize

      // PCMデータをコピー
      final outPcmView = Int16List.view(outWavBytes.buffer, 44, resampledSamples.length);
      for (int i = 0; i < resampledSamples.length; i++) {
        outPcmView[i] = resampledSamples[i];
      }

      await outputFile.writeAsBytes(outWavBytes);
      print('Conversion complete! Saved to: $outputWavPath (Size: ${outWavBytes.length} bytes)');

      // 一時ファイルのクリーンアップ
      try {
        await decodedFile.delete();
      } catch (_) {}

      return outputFile;
    } catch (e) {
      print('Error during transcoding: $e');
      return null;
    }
  }

  // ファイル存在確認
  static Future<File?> verifyAndGetWav(String inputPath) async {
    try {
      final file = File(inputPath);
      if (!await file.exists()) return null;
      return file;
    } catch (e) {
      print('Error in verifyAndGetWav: $e');
      return null;
    }
  }
}
