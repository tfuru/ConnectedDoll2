#include "audio/alarm_manager.h"
#include "audio/audio_player.h"
#include "ble/ble_manager.h"
#include "hal/hal_io.h"
#include "hal/hal_nfc.h"
#include "hal/hal_power.h"
#include "hal/hal_rtc.h"
#include "hal/hal_sd.h"
#include "hal/hal_ota.h"
#include <Arduino.h>

// アイドルタイムアウト設定（無操作時にDeep Sleepへ移行するまでの時間: 60秒）
const unsigned long IDLE_SLEEP_TIMEOUT_MS = 60000;
// NFC タグのポーリング間隔 (ms)
const unsigned long NFC_POLL_INTERVAL_MS = 250;
// NFC 検出時の LED フィードバック表示時間 (ms)
const unsigned long NFC_LED_FEEDBACK_MS = 300;

// 音量の前回比率
float lastVolumeRatio = -1.0f;

// NFC 検出フィードバック状態
unsigned long nfcLedFeedbackUntil = 0;
uint8_t nfcLedFeedbackR = 0;
uint8_t nfcLedFeedbackG = 0;
uint8_t nfcLedFeedbackB = 0;

void startNfcLedFeedback(uint8_t r, uint8_t g, uint8_t b) {
  nfcLedFeedbackR = r;
  nfcLedFeedbackG = g;
  nfcLedFeedbackB = b;
  nfcLedFeedbackUntil = millis() + NFC_LED_FEEDBACK_MS;
}

// Deep Sleep モード切替 LED フィードバック状態（非ブロッキング点滅）
unsigned long modeFeedbackStartMs = 0;
uint8_t modeFeedbackBlinks = 0;
uint8_t modeFeedbackR = 0;
uint8_t modeFeedbackG = 0;
uint8_t modeFeedbackB = 0;

void startModeLedFeedback(uint8_t r, uint8_t g, uint8_t b, uint8_t blinks) {
  modeFeedbackStartMs = millis();
  modeFeedbackR = r;
  modeFeedbackG = g;
  modeFeedbackB = b;
  modeFeedbackBlinks = blinks;
}

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

bool triggerNfcPresetPlayback(const std::string& presetUuid) {
  String lowerUuid(presetUuid.c_str());
  lowerUuid.trim();
  lowerUuid.toLowerCase();

  String wavPath = "/nfc/" + lowerUuid + ".wav";
  String mp3Path = "/nfc/" + lowerUuid + ".mp3";

  if (HAL_SD::fileExists(wavPath.c_str())) {
    Serial.printf("[NFC] Playing UUID audio: %s\n", wavPath.c_str());
    AudioPlayer::playMP3(wavPath.c_str());
    return true;
  }
  if (HAL_SD::fileExists(mp3Path.c_str())) {
    Serial.printf("[NFC] Playing UUID audio: %s\n", mp3Path.c_str());
    AudioPlayer::playMP3(mp3Path.c_str());
    return true;
  }

  Serial.printf("[NFC] Audio file not found for UUID %s (expected %s or %s)\n",
                lowerUuid.c_str(), wavPath.c_str(), mp3Path.c_str());
  return false;
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
  HAL_NFC::init();
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

  // 音声再生中・BLE接続中・ファイル転送中・ボタン長押し中・スリープ抑止中（USBホスト接続/常時起動モード）はアイドルタイマーを常時リセット
  const bool usbConnected = HAL_Power::isUsbHostConnected();
  static bool lastUsbConnected = false;
  static bool usbStatusInitialized = false;
  if (!usbStatusInitialized || usbConnected != lastUsbConnected) {
    usbStatusInitialized = true;
    lastUsbConnected = usbConnected;
    Serial.printf("[Power] USB Host %s (Deep Sleep %s)\n",
                  usbConnected ? "CONNECTED" : "DISCONNECTED",
                  HAL_Power::isSleepInhibited() ? "inhibited" : "enabled");
  }

  if (AudioPlayer::isPlaying() || BLEManager::isConnected() ||
      BLEManager::isTransferringFile() || HAL_IO::isButtonHeld() ||
      HAL_Power::isSleepInhibited()) {
    HAL_Power::resetIdleTimer();
  }

  // --- 状態に合わせたLEDイルミネーション制御 ---
  static bool wasAudioPlaying = false;
  static unsigned long lastPlayFlash = 0;
  static bool playLedState = true;

  const unsigned long modeFeedbackDurationMs = (unsigned long)modeFeedbackBlinks * 200UL;
  const bool modeFeedbackActive =
      (modeFeedbackBlinks > 0) && ((millis() - modeFeedbackStartMs) < modeFeedbackDurationMs);
  if (modeFeedbackBlinks > 0 && !modeFeedbackActive) {
    modeFeedbackBlinks = 0;
  }

  if (BLEManager::isTransferringFile()) {
    wasAudioPlaying = false;
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
  } else if (modeFeedbackActive) {
    wasAudioPlaying = false;
    // スリープモード切替フィードバック: 100ms点灯 / 100ms消灯
    const unsigned long elapsed = millis() - modeFeedbackStartMs;
    if (((elapsed / 100UL) % 2UL) == 0UL) {
      HAL_IO::setLEDColor(modeFeedbackR, modeFeedbackG, modeFeedbackB);
    } else {
      HAL_IO::setLEDColor(0, 0, 0);
    }
  } else if (AudioPlayer::isPlaying()) {
    // 音声再生中: 設定カラー基準で中速点滅 (250ms点灯 / 250ms消灯)
    if (!wasAudioPlaying) {
      wasAudioPlaying = true;
      playLedState = true;
      lastPlayFlash = millis();
    }
    if (millis() - lastPlayFlash > 250) {
      playLedState = !playLedState;
      lastPlayFlash = millis();
    }
    if (playLedState) {
      uint8_t tr, tg, tb;
      HAL_IO::getThemeColor(tr, tg, tb);
      HAL_IO::setLEDColor(tr, tg, tb);
    } else {
      HAL_IO::setLEDColor(0, 0, 0);
    }
  } else if (millis() < nfcLedFeedbackUntil) {
    wasAudioPlaying = false;
    // NFC 読取フィードバック: プリセット再生成功=緑、音声未登録=赤、非プリセット=黄橙
    HAL_IO::setLEDColor(nfcLedFeedbackR, nfcLedFeedbackG, nfcLedFeedbackB);
  } else if (BLEManager::isConnected()) {
    wasAudioPlaying = false;
    // BLE接続中: 青色点灯
    HAL_IO::setLEDColor(0, 0, 50);
  } else if (HAL_Power::isDeepSleepDisabled()) {
    wasAudioPlaying = false;
    // Deep Sleep 無効（常時起動モード）待機: 推しカラー常時点灯（通常ブレスと視覚区別）
    uint8_t tr, tg, tb;
    HAL_IO::getThemeColor(tr, tg, tb);
    HAL_IO::setLEDColor(tr, tg, tb);
  } else {
    wasAudioPlaying = false;
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

  // --- タクトスイッチ 3秒長押しによる Deep Sleep 無効（常時起動モード）ON/OFF トグル ---
  if (HAL_IO::isLongPressed()) {
    HAL_Power::resetIdleTimer();
    const bool sleepDisabled = HAL_Power::toggleDeepSleepDisabled();
    if (sleepDisabled) {
      Serial.println("[Power] 3s Long Press: Deep Sleep DISABLED (Keep-Awake Mode ON).");
      startModeLedFeedback(0, 90, 90, 3); // シアン3回点滅
    } else {
      Serial.println("[Power] 3s Long Press: Deep Sleep ENABLED (Normal Mode).");
      startModeLedFeedback(90, 40, 0, 2); // オレンジ2回点滅
    }
  }

  // --- タクトスイッチ短押しによる特定ファイル再生 (WAV優先、次点でMP3) / 再生中停止 ---
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

  // --- NFC タグ読み取り（UUID に紐づく /nfc/<uuid>.wav(.mp3) を再生） ---
  // シングルコアでの音飛び・BLE 転送欠落を防ぐため、再生中・転送中はポーリングを休止する
  static unsigned long lastNfcPoll = 0;
  if (HAL_NFC::isInitialized() &&
      !BLEManager::isTransferringFile() &&
      !AudioPlayer::isPlaying() &&
      (millis() - lastNfcPoll >= NFC_POLL_INTERVAL_MS)) {
    lastNfcPoll = millis();
    NfcReadResult tag;
    if (HAL_NFC::pollTag(tag)) {
      HAL_Power::resetIdleTimer();

      if (tag.presetValid) {
        Serial.println("[NFC] Preset Tag detected!");
        Serial.printf("  Card Type   : %s\n", tag.cardType.c_str());
        Serial.printf("  Tag UID     : %s\n", tag.uid.c_str());
        Serial.printf("  Preset UUID : %s\n", tag.presetUuid.c_str());
        Serial.printf("  Preset Name : %s\n", tag.presetName.c_str());

        if (triggerNfcPresetPlayback(tag.presetUuid)) {
          startNfcLedFeedback(0, 80, 0);   // 緑: 対応音声を再生開始
        } else {
          startNfcLedFeedback(100, 0, 0);  // 赤: UUIDに対応する音声ファイル未転送
        }
      } else {
        Serial.println("[NFC] Non-preset Tag detected");
        Serial.printf("  Card Type   : %s\n", tag.cardType.c_str());
        Serial.printf("  Tag UID     : %s\n", tag.uid.c_str());
        if (!tag.note.empty()) {
          Serial.printf("  Note        : %s\n", tag.note.c_str());
        }
        if (!tag.rawHexPreview.empty()) {
          Serial.printf("  Page4-7 Hex : %s\n", tag.rawHexPreview.c_str());
        }
        startNfcLedFeedback(80, 40, 0);    // 黄橙: プリセット以外のタグ
      }
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
  // BLE接続中・ファイル転送中・音声再生中・USBホスト接続中・常時起動モード中はスリープに入らない
  if (!BLEManager::isConnected() && !BLEManager::isTransferringFile() &&
      !AudioPlayer::isPlaying() && !HAL_Power::isSleepInhibited()) {
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
