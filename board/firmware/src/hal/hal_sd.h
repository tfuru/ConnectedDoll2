#ifndef HAL_SD_H
#define HAL_SD_H

#include <Arduino.h>
#include <SPI.h>
#include <SD.h>

#define PIN_SD_SCK   8
#define PIN_SD_MISO  9
#define PIN_SD_MOSI  4
#define PIN_SD_CS   5  // 基板上はGND直結のため、影響の最も少ない GPIO5 (D3: WS2812B) をダミーCSとして割り当て

class HAL_SD {
public:
    static bool init();
    static bool isMounted();
    static bool writeFile(const char* path, const uint8_t* data, size_t len);
    static bool appendFile(const char* path, const uint8_t* data, size_t len);
    static bool deleteFile(const char* path);
    static bool fileExists(const char* path);
    
private:
    static bool mounted;
};

#endif // HAL_SD_H
