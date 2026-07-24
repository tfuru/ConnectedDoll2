#ifndef HAL_IO_H
#define HAL_IO_H

#include <Adafruit_NeoPixel.h>
#include <Arduino.h>

// GPIOピン定義
#define PIN_TACT_SW 2 // D0
#define PIN_VOLUME 3  // D1
#define PIN_WS2812B 5 // D3

// LEDの数
#define NUM_LEDS 1

class HAL_IO {
public:
  static void init();
  static bool isKeyPressed();
  static float readVolume(); // 0.0 ~ 1.0
  static void setLEDColor(uint8_t r, uint8_t g, uint8_t b);
  static void setLEDBrightness(uint8_t brightness);
  static uint8_t getLEDBrightness();
  static void update();

private:
  static Adafruit_NeoPixel pixels;
  static uint8_t currentBrightness;
  static void IRAM_ATTR handleButtonInterrupt();
  static volatile bool keyPressedFlag;
  static volatile unsigned long lastDebounceTime;
  static const unsigned long debounceDelay = 150; // デバウンス閾値 (ms)
};

#endif // HAL_IO_H
