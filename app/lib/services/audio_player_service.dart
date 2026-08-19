import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// アプリ内で音声ファイルを試聴・再生するための管理サービス
class AudioPlayerService {
  AudioPlayerService._internal() {
    _initPlayer();
  }

  static final AudioPlayerService instance = AudioPlayerService._internal();

  late AudioPlayer _player;

  /// 現在再生中の識別子（例: 'preset_slot_-1', 'alarm_slot_0' 等）
  final ValueNotifier<String?> playingTagNotifier = ValueNotifier<String?>(null);

  /// プレイヤーの状態（playing, paused, stopped, completed 等）
  final ValueNotifier<PlayerState> playerStateNotifier = ValueNotifier<PlayerState>(PlayerState.stopped);

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _playerCompleteSubscription;

  void _initPlayer() {
    _player = AudioPlayer();

    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      playerStateNotifier.value = state;
      if (state == PlayerState.stopped || state == PlayerState.completed) {
        playingTagNotifier.value = null;
      }
    });

    _playerCompleteSubscription = _player.onPlayerComplete.listen((_) {
      playerStateNotifier.value = PlayerState.completed;
      playingTagNotifier.value = null;
    });
  }

  /// 指定したローカル音声ファイルを再生
  /// 同一の tag が再生中の場合は停止する（トグル動作）
  Future<void> togglePlay(String filePath, {required String tag}) async {
    try {
      if (playingTagNotifier.value == tag && playerStateNotifier.value == PlayerState.playing) {
        await stop();
        return;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[AudioPlayerService] File does not exist: $filePath');
        await stop();
        return;
      }

      // 既存の再生を停止
      await _player.stop();

      playingTagNotifier.value = tag;
      playerStateNotifier.value = PlayerState.playing;

      await _player.play(DeviceFileSource(filePath));
    } catch (e) {
      debugPrint('[AudioPlayerService] Error playing audio: $e');
      await stop();
    }
  }

  /// 再生停止
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('[AudioPlayerService] Error stopping audio: $e');
    } finally {
      playingTagNotifier.value = null;
      playerStateNotifier.value = PlayerState.stopped;
    }
  }

  /// 特定のタグが現在再生中かどうか
  bool isPlaying(String tag) {
    return playingTagNotifier.value == tag && playerStateNotifier.value == PlayerState.playing;
  }

  void dispose() {
    _playerStateSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _player.dispose();
  }
}
