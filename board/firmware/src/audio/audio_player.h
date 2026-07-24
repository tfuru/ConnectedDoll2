#ifndef AUDIO_PLAYER_H
#define AUDIO_PLAYER_H

#include <Arduino.h>
#include "Audio.h"

// I2S ピン定義
#define PIN_I2S_BCLK    21 // D6
#define PIN_I2S_LRC     20 // D7
#define PIN_I2S_DOUT    10 // D10

class AudioPlayer {
public:
    static void init();
    static void playMP3(const char* filepath);
    static void stop();
    static void update();
    static void setVolume(uint8_t vol); // 0 ~ 21 (ESP32-audioI2S の音量範囲)
    static uint8_t getVolume();
    static bool isPlaying();
    
private:
    static Audio audio;
    static uint8_t currentVolume;
};

#endif // AUDIO_PLAYER_H
