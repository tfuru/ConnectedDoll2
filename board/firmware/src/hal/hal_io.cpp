#include "hal_io.h"
#include <Preferences.h>

Adafruit_NeoPixel HAL_IO::pixels =
    Adafruit_NeoPixel(NUM_LEDS, PIN_WS2812B, NEO_GRB + NEO_KHZ800);
bool HAL_IO::lastRawPressed = false;
bool HAL_IO::stablePressed = false;
bool HAL_IO::ignoreUntilRelease = false;
bool HAL_IO::longPressHandled = false;
bool HAL_IO::shortPressEvent = false;
bool HAL_IO::longPressEvent = false;
unsigned long HAL_IO::lastRawChangeMs = 0;
unsigned long HAL_IO::pressStartMs = 0;
uint8_t HAL_IO::currentBrightness = 128;
uint8_t HAL_IO::themeR = 79;   // デフォルト: インディゴ (Indigo: #4F46E5)
uint8_t HAL_IO::themeG = 70;
uint8_t HAL_IO::themeB = 229;

void HAL_IO::init() {
  pinMode(PIN_TACT_SW, INPUT_PULLUP);
  pinMode(PIN_VOLUME, INPUT);

  // プルアップが電気的に安定するのを少し待つ
  delay(10);
  const bool initiallyPressed = (digitalRead(PIN_TACT_SW) == LOW);
  lastRawPressed = initiallyPressed;
  stablePressed = initiallyPressed;
  // スリープ復帰時の押しっぱなしで誤再生しないよう、離されるまで初回押下を無視する
  ignoreUntilRelease = initiallyPressed;
  longPressHandled = false;
  shortPressEvent = false;
  longPressEvent = false;
  lastRawChangeMs = millis();
  pressStartMs = lastRawChangeMs;

  pixels.begin();
  
  // フラッシュからLED明るさとテーマカラーを読み出して適用
  Preferences prefs;
  prefs.begin("system", true);
  currentBrightness = prefs.getUChar("led_bright", 128);
  themeR = prefs.getUChar("theme_r", 79);
  themeG = prefs.getUChar("theme_g", 70);
  themeB = prefs.getUChar("theme_b", 229);
  prefs.end();
  pixels.setBrightness(currentBrightness);
  if (currentBrightness == 0) {
    pixels.clear();
  }
  
  pixels.show(); // すべて消灯
}

void HAL_IO::update() {
  const unsigned long now = millis();
  const bool rawPressed = (digitalRead(PIN_TACT_SW) == LOW);

  if (rawPressed != lastRawPressed) {
    lastRawPressed = rawPressed;
    lastRawChangeMs = now;
  }

  if ((now - lastRawChangeMs) >= debounceDelay && rawPressed != stablePressed) {
    stablePressed = rawPressed;
    if (stablePressed) {
      // 押下開始
      pressStartMs = now;
      longPressHandled = false;
    } else {
      // 離した瞬間
      if (ignoreUntilRelease) {
        ignoreUntilRelease = false;
      } else if (!longPressHandled) {
        shortPressEvent = true;
      }
      longPressHandled = false;
    }
  }

  // 3秒長押し判定（押したまま3秒経過した瞬間に発火し、離した時の短押しを抑制）
  if (stablePressed && !ignoreUntilRelease && !longPressHandled) {
    if ((now - pressStartMs) >= longPressDelay) {
      longPressHandled = true;
      longPressEvent = true;
    }
  }
}

bool HAL_IO::isKeyPressed() {
  if (shortPressEvent) {
    shortPressEvent = false;
    return true;
  }
  return false;
}

bool HAL_IO::isLongPressed() {
  if (longPressEvent) {
    longPressEvent = false;
    return true;
  }
  return false;
}

bool HAL_IO::isButtonHeld() {
  return stablePressed && !ignoreUntilRelease;
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

void HAL_IO::setThemeColor(uint8_t r, uint8_t g, uint8_t b) {
  themeR = r;
  themeG = g;
  themeB = b;

  Preferences prefs;
  prefs.begin("system", false);
  prefs.putUChar("theme_r", r);
  prefs.putUChar("theme_g", g);
  prefs.putUChar("theme_b", b);
  prefs.end();

  setLEDColor(r, g, b);
}

void HAL_IO::getThemeColor(uint8_t &r, uint8_t &g, uint8_t &b) {
  r = themeR;
  g = themeG;
  b = themeB;
}

void HAL_IO::turnOffLED() {
  pixels.clear();
  pixels.show();
  // 自動電源遮断回路の放電を確実に促すため、ピンをLOWに固定
  pinMode(PIN_WS2812B, OUTPUT);
  digitalWrite(PIN_WS2812B, LOW);
}

