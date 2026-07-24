#include "audio_player.h"
#include <SD.h>

Audio AudioPlayer::audio;
uint8_t AudioPlayer::currentVolume = 10; // デフォルト初期音量 (0-21)

void AudioPlayer::init() {
    // I2Sピンのセットアップ
    audio.setPinout(PIN_I2S_BCLK, PIN_I2S_LRC, PIN_I2S_DOUT);
    audio.setVolume(currentVolume);
}

void AudioPlayer::playMP3(const char* filepath) {
    // すでに再生中の場合は、ミュートして安全に停止してから新規ファイルを接続する (上書きノイズ防止)
    if (audio.isRunning()) {
        stop();
        delay(50); // アンプの消音移行時間を確保
    }
    
    // 1. まず音量を0（ミュート）にする
    audio.setVolume(0);
    Serial.printf("Connecting audio under mute: %s\n", filepath);
    
    // 2. 音量0の状態でファイル接続 (I2Sデータが流れ始め、アンプが静かに起動する)
    audio.connecttoFS(SD, filepath);
    
    // 3. アンプ起動時の電圧遷移が安定するのを待つ (120msウェイト)
    delay(120);
    
    // 4. アンプ起動完了後に本来の設定音量を適用
    audio.setVolume(currentVolume);
    Serial.printf("Audio output active (Vol: %d)\n", currentVolume);
}

void AudioPlayer::stop() {
    if (audio.isRunning()) {
        audio.setVolume(0); // 一時的にミュートにしてポップノイズを防ぐ
        delay(50);          // DMAバッファ充填済みの音声がミュートされるのを待つウェイト
        audio.stopSong();
        audio.setVolume(currentVolume); // 次回用に設定音量を復元
        Serial.println("Audio stopped with temporary mute and delay.");
    } else {
        // 非再生中でも、不意のポップノイズを防ぐため一時的に音量0でクリアをかける
        audio.setVolume(0);
        audio.stopSong();
        audio.setVolume(currentVolume);
    }
}

void AudioPlayer::update() {
    // デコーダーのデコード処理を継続するために loop を毎フレーム呼ぶ必要があります
    audio.loop();
    
    // 再生終了の直前（残りデータが 8000 バイト以下）を検知して先んじてミュート
    if (audio.isRunning()) {
        uint32_t total = audio.getFileSize();
        uint32_t pos = audio.getFilePos();
        if (total > 0 && pos > 0 && (total > pos)) {
            uint32_t remaining = total - pos;
            if (remaining < 8000) {
                audio.setVolume(0); // I2S送信切断前の時点でボリュームを0にする
            }
        }
    }
}

void AudioPlayer::setVolume(uint8_t vol) {
    if (vol > 21) vol = 21;
    currentVolume = vol;
    // 再生中の場合のみ即時音量を反映 (再生停止中のI2Sノイズ発生を防止)
    if (audio.isRunning()) {
        audio.setVolume(currentVolume);
    }
}

uint8_t AudioPlayer::getVolume() {
    return currentVolume;
}

bool AudioPlayer::isPlaying() {
    return audio.isRunning();
}

// === ESP32-audioI2S 再生終了 (EOF) コールバック関数の実装 ===
// コールバック関数内で直接音量を 0 にしてアンプの切断ポップノイズを防ぎます

void audio_eof_mp3(const char *info) {
    Serial.printf("EOF of mp3: %s. Muting output.\n", info);
    // 状態にかかわらず完全にミュートで閉じるために stop() を明示実行
    AudioPlayer::stop(); 
}

void audio_eof_wav(const char *info) {
    Serial.printf("EOF of wav: %s. Muting output.\n", info);
    AudioPlayer::stop();
}
