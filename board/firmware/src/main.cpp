#include "audio/alarm_manager.h"
#include "audio/audio_player.h"
#include "ble/ble_manager.h"
#include "hal/hal_io.h"
#include "hal/hal_power.h"
#include "hal/hal_rtc.h"
#include "hal/hal_sd.h"
#include "hal/hal_ota.h"
#include <Arduino.h>

// アイドルタイムアウト設定（無操作時にDeep Sleepへ移行するまでの時間: 60秒）
const unsigned long IDLE_SLEEP_TIMEOUT_MS = 60000;

// 音量の前回比率
float lastVolumeRatio = -1.0f;

void triggerButtonPlayback() {
  Serial.println("Triggering button playback (/trigger.wav or /trigger.mp3)...");
  if (HAL_SD::fileExists("/trigger.wav")) {
    AudioPlayer::playMP3("/trigger.wav");
  } else if (HAL_SD::fileExists("/trigger.mp3")) {
    AudioPlayer::playMP3("/trigger.mp3");
  } else {
    Serial.println("Error: trigger file (/trigger.wav or /trigger.mp3) not found on SD card.");
    // エラー表示としてLEDを一時的に赤く点灯
    HAL_IO::setLEDColor(100, 0, 0);
    delay(300);
  }
}

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("=========================================");
  Serial.println("Starting ConnectedDoll2 Audio Stand Board");
  Serial.println("=========================================");

  // 各ハードウェアモジュールの初期化
  HAL_Power::init();
  HAL_IO::init();
  HAL_SD::init();

  // 起動時の保留中ファームウェア更新チェック
  if (HAL_OTA::hasPendingUpdate("/update.bin")) {
    Serial.println("[Boot] Detected /update.bin on SD card. Processing OTA update...");
    HAL_OTA::performUpdateFromSD("/update.bin");
  } else if (HAL_OTA::hasPendingUpdate("/firmware.bin")) {
    Serial.println("[Boot] Detected /firmware.bin on SD card. Processing OTA update...");
    HAL_OTA::performUpdateFromSD("/firmware.bin");
  }

  HAL_RTC::init();
  AudioPlayer::init();
  AlarmManager::init();

  // スリープ復帰理由の確認
  esp_sleep_wakeup_cause_t wakeup_reason = HAL_Power::getWakeupCause();
  Serial.printf("[Power] Wakeup reason: %d\n", wakeup_reason);

  if (wakeup_reason == ESP_SLEEP_WAKEUP_GPIO) {
    Serial.println("[Power] Woken up by Tact Switch (GPIO2) - Audio playback skipped on wakeup.");
  } else if (wakeup_reason == ESP_SLEEP_WAKEUP_TIMER) {
    Serial.println("[Power] Woken up by RTC Timer Alarm!");
    DateTime now = HAL_RTC::getCurrentTime();
    AlarmManager::update(now);
  } else {
    Serial.println("[Power] Normal boot / Power-on reset.");
  }

  // BLEサーバー起動
  BLEManager::init("ConnectedDoll2");
  BLEManager::startAdvertising();

  uint8_t tr, tg, tb;
  HAL_IO::getThemeColor(tr, tg, tb);
  HAL_IO::setLEDColor(tr, tg, tb); // 起動完了: 推しカラー点灯
  HAL_Power::resetIdleTimer();
  Serial.println("System Initialization Complete.");
}

void loop() {
  // 状態更新ポーリング
  HAL_IO::update();
  AudioPlayer::update();
  BLEManager::processTransferBuffer();

  // 音声再生中・BLE接続中・ファイル転送中はアイドルタイマーを常時リセット（スリープ抑止）
  if (AudioPlayer::isPlaying() || BLEManager::isConnected() || BLEManager::isTransferringFile()) {
    HAL_Power::resetIdleTimer();
  }

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
    // 音声再生中: 推しカラーで点灯
    uint8_t tr, tg, tb;
    HAL_IO::getThemeColor(tr, tg, tb);
    HAL_IO::setLEDColor(tr, tg, tb);
  } else if (BLEManager::isConnected()) {
    // BLE接続中: 青色点灯
    HAL_IO::setLEDColor(0, 0, 50);
  } else {
    // 待機状態: 推しカラーでゆっくりブレス明滅
    static unsigned long lastLedBreath = 0;
    static int breathVal = 5;
    static int breathDir = 1;
    if (millis() - lastLedBreath > 20) {
      breathVal += breathDir;
      if (breathVal >= 50 || breathVal <= 5) {
        breathDir = -breathDir;
      }
      uint8_t tr, tg, tb;
      HAL_IO::getThemeColor(tr, tg, tb);
      uint8_t r = (uint16_t)tr * breathVal / 50;
      uint8_t g = (uint16_t)tg * breathVal / 50;
      uint8_t b = (uint16_t)tb * breathVal / 50;
      HAL_IO::setLEDColor(r, g, b);
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
      HAL_Power::resetIdleTimer();
      // ESP32-audioI2S の音量範囲は 0 ~ 21
      uint8_t targetVol = (uint8_t)(volRatio * 21.0f);
      AudioPlayer::setVolume(targetVol);
      Serial.printf("Volume updated: %d / 21 (ratio: %.2f)\n", targetVol,
                    volRatio);
    }
  }

  // --- タクトスイッチによる特定ファイル再生 (WAV優先、次点でMP3) / 再生中停止 ---
  if (HAL_IO::isKeyPressed()) {
    HAL_Power::resetIdleTimer();
    if (AudioPlayer::isPlaying()) {
      Serial.println("Button Pressed while playing! Stopping playback...");
      AudioPlayer::stop();
    } else {
      Serial.println("Button Pressed! Triggering playback...");
      triggerButtonPlayback();
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

  // --- アイドル状態監視とDeep Sleep移行判定 ---
  // BLE接続中・ファイル転送中・音声再生中は絶対にスリープに入らない
  if (!BLEManager::isConnected() && !BLEManager::isTransferringFile() && !AudioPlayer::isPlaying()) {
    if (HAL_Power::isIdleTimeout(IDLE_SLEEP_TIMEOUT_MS)) {
      Serial.println("[Power] Idle timeout reached without active connection or playback.");
      DateTime now = HAL_RTC::getCurrentTime();
      int64_t secondsToNext = AlarmManager::getSecondsToNextAlarm(now);
      
      uint64_t sleepDurationUs = 0;
      if (secondsToNext > 0) {
        Serial.printf("[Power] Next alarm in %lld seconds (%s)\n",
                      secondsToNext, HAL_RTC::getCurrentTimeStr().c_str());
        sleepDurationUs = (uint64_t)secondsToNext * 1000000ULL;
      } else {
        Serial.println("[Power] No active alarms scheduled.");
      }
      
      HAL_Power::enterDeepSleep(sleepDurationUs);
    }
  } else {
    // 接続・アクティビティ中は常にアイドルタイマーを最新化
    HAL_Power::resetIdleTimer();
  }
}
