#include "audio/alarm_manager.h"
#include "audio/audio_player.h"
#include "ble/ble_manager.h"
#include "hal/hal_io.h"
#include "hal/hal_rtc.h"
#include "hal/hal_sd.h"
#include <Arduino.h>

// アラーム設定は AlarmManager 内で Preferences とともに管理されます

// 音量の前回比率
float lastVolumeRatio = -1.0f;

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("=========================================");
  Serial.println("Starting ConnectedDoll2 Audio Stand Board");
  Serial.println("=========================================");

  // 各ハードウェアモジュールの初期化
  HAL_IO::init();
  HAL_SD::init();
  HAL_RTC::init();
  AudioPlayer::init();
  AlarmManager::init();

  // BLEサーバー起動
  BLEManager::init("ConnectedDoll2");
  BLEManager::startAdvertising();

  HAL_IO::setLEDColor(0, 50, 0); // 薄い緑: 起動完了
  Serial.println("System Initialization Complete.");
}

void loop() {
  // 状態更新ポーリング
  HAL_IO::update();
  AudioPlayer::update();

  // --- 状態に合わせたLEDイルミネーション制御 ---
  if (BLEManager::isTransferringFile()) {
    // BLEファイル転送中: 赤の高速点滅 (100ms)
    static unsigned long lastLedFlash = 0;
    static bool ledState = false;
    if (millis() - lastLedFlash > 100) {
      ledState = !ledState;
      if (ledState)
        HAL_IO::setLEDColor(50, 0, 0);
      else
        HAL_IO::setLEDColor(0, 0, 0);
      lastLedFlash = millis();
    }
  } else if (AudioPlayer::isPlaying()) {
    // 音楽再生中: 黄色点灯
    HAL_IO::setLEDColor(50, 50, 0);
  } else if (BLEManager::isConnected()) {
    // BLE接続中: 青色点灯
    HAL_IO::setLEDColor(0, 0, 50);
  } else {
    // 待機状態: ゆっくり緑色でブレス明滅
    static unsigned long lastLedBreath = 0;
    static int breathVal = 5;
    static int breathDir = 1;
    if (millis() - lastLedBreath > 20) {
      breathVal += breathDir;
      if (breathVal >= 45 || breathVal <= 5) {
        breathDir = -breathDir;
      }
      HAL_IO::setLEDColor(0, breathVal, 0);
      lastLedBreath = millis();
    }
  }

  // --- ボリュームダイヤル (アナログ可変抵抗) の処理 ---
  static unsigned long lastVolCheck = 0;
  if (millis() - lastVolCheck > 100) { // 100msごとに間引いてCPUブロックを防止
    lastVolCheck = millis();
    float volRatio = HAL_IO::readVolume();
    // 誤検出を防ぐため 5% 以上の変化があった場合のみ更新
    if (abs(volRatio - lastVolumeRatio) > 0.05f) {
      lastVolumeRatio = volRatio;
      // ESP32-audioI2S の音量範囲は 0 ~ 21
      uint8_t targetVol = (uint8_t)(volRatio * 21.0f);
      AudioPlayer::setVolume(targetVol);
      Serial.printf("Volume updated: %d / 21 (ratio: %.2f)\n", targetVol,
                    volRatio);
    }
  }

  // --- タクトスイッチによる特定ファイル再生 (WAV優先、次点でMP3) ---
  if (HAL_IO::isKeyPressed()) {
    Serial.println("Button Pressed! Triggering playback...");
    if (HAL_SD::fileExists("/trigger.wav")) {
      AudioPlayer::playMP3("/trigger.wav");
    } else if (HAL_SD::fileExists("/trigger.mp3")) {
      AudioPlayer::playMP3("/trigger.mp3");
    } else {
      Serial.println("Error: trigger file (/trigger.wav or /trigger.mp3) not "
                     "found on SD card.");
      // エラー表示としてLEDを一時的に赤く高速点灯
      HAL_IO::setLEDColor(100, 0, 0);
      delay(300);
    }
  }

  // --- RTCによる複数日時スケジュール再生 (WAV優先、次点でMP3) ---
  static unsigned long lastTimeCheck = 0;
  if (millis() - lastTimeCheck > 1000) { // 1秒間隔で時刻監視
    lastTimeCheck = millis();
    DateTime now = HAL_RTC::getCurrentTime();

    // 複数スロットアラームの監視とトリガー
    AlarmManager::update(now);

    // 10秒ごとにシリアルへ時刻と現在のアラーム設定を表示するデバッグログ
    static int debugTick = 0;
    if (++debugTick >= 10) {
      debugTick = 0;
      Serial.printf("[RTC Log] Current Time: %s | Alarms: %s\n",
                    HAL_RTC::getCurrentTimeStr().c_str(),
                    AlarmManager::getSchedulesStr().c_str());
    }
  }
}
