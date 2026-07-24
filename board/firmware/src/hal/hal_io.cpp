#include "hal_io.h"
#include <Preferences.h>

Adafruit_NeoPixel HAL_IO::pixels =
    Adafruit_NeoPixel(NUM_LEDS, PIN_WS2812B, NEO_GRB + NEO_KHZ800);
volatile bool HAL_IO::keyPressedFlag = false;
volatile unsigned long HAL_IO::lastDebounceTime = 0;
uint8_t HAL_IO::currentBrightness = 128;

void HAL_IO::init() {
  pinMode(PIN_TACT_SW, INPUT_PULLUP);
  pinMode(PIN_VOLUME, INPUT);

  // プルアップが電気的に安定するのを少し待つ
  delay(10);
  keyPressedFlag = false;
  lastDebounceTime = 0;

  // スイッチ押下（HIGH -> LOW / FALLING エッジ）で割り込み登録
  attachInterrupt(digitalPinToInterrupt(PIN_TACT_SW), handleButtonInterrupt,
                  FALLING);

  pixels.begin();
  
  // フラッシュからLED明るさを読み出して適用
  Preferences prefs;
  prefs.begin("system", true);
  currentBrightness = prefs.getUChar("led_bright", 128);
  prefs.end();
  pixels.setBrightness(currentBrightness);
  if (currentBrightness == 0) {
    pixels.clear();
  }
  
  pixels.show(); // すべて消灯
}

void IRAM_ATTR HAL_IO::handleButtonInterrupt() {
  unsigned long currentTime = millis();
  // ソフトウェア・デバウンス (前回割り込みから一定時間経過している場合のみ検知)
  if (currentTime - lastDebounceTime > debounceDelay) {
    keyPressedFlag = true;
    lastDebounceTime = currentTime;
  }
}

void HAL_IO::update() {
  // 割り込み化されたため、スイッチのポーリング処理は不要
}

bool HAL_IO::isKeyPressed() {
  if (keyPressedFlag) {
    keyPressedFlag = false; // フラグクリア
    return true;
  }
  return false;
}

float HAL_IO::readVolume() {
  int val = analogRead(PIN_VOLUME);
  // ESP32C3 12bit ADC (0-4095) を 0.0 ~ 1.0 に正規化
  float vol = (float)val / 4095.0f;
  if (vol > 1.0f)
    vol = 1.0f;
  if (vol < 0.0f)
    vol = 0.0f;
  return vol;
}

void HAL_IO::setLEDColor(uint8_t r, uint8_t g, uint8_t b) {
  if (currentBrightness == 0) {
    // 明るさが0%の時は即座に処理をスキップし、データ送信（show）も行わない（RFノイズ干渉による誤点灯を防ぐため）
    return;
  }
  pixels.setPixelColor(0, pixels.Color(r, g, b));
  pixels.show();
}

void HAL_IO::setLEDBrightness(uint8_t brightness) {
  currentBrightness = brightness;
  pixels.setBrightness(brightness);
  if (brightness == 0) {
    pixels.clear();
  }
  pixels.show();

  Preferences prefs;
  prefs.begin("system", false);
  prefs.putUChar("led_bright", brightness);
  prefs.end();
}

uint8_t HAL_IO::getLEDBrightness() {
  return currentBrightness;
}
