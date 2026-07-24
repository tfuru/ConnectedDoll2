#include "hal_sd.h"

bool HAL_SD::mounted = false;

bool HAL_SD::init() {
    // 標準のグローバル SPI オブジェクトを指定ピンで初期化 (CS=-1で競合回避)
    SPI.begin(PIN_SD_SCK, PIN_SD_MISO, PIN_SD_MOSI, -1);
    
    // SDライブラリの開始。標準の SPI オブジェクトを渡し、4MHzに設定して信号のなまりを防ぐ
    if (!SD.begin(PIN_SD_CS, SPI, 4000000)) { 
        Serial.println("SD Card Mount Failed");
        mounted = false;
        return false;
    }
    
    Serial.println("SD Card Mounted Successfully");
    mounted = true;
    return true;
}

bool HAL_SD::isMounted() {
    return mounted;
}

bool HAL_SD::writeFile(const char* path, const uint8_t* data, size_t len) {
    if (!mounted) return false;
    File file = SD.open(path, FILE_WRITE);
    if (!file) {
        Serial.printf("Failed to open file %s for writing\n", path);
        return false;
    }
    
    size_t written = file.write(data, len);
    file.close();
    return (written == len);
}

bool HAL_SD::appendFile(const char* path, const uint8_t* data, size_t len) {
    if (!mounted) return false;
    File file = SD.open(path, FILE_APPEND);
    if (!file) {
        Serial.printf("Failed to open file %s for appending\n", path);
        return false;
    }
    
    size_t written = file.write(data, len);
    file.close();
    return (written == len);
}

bool HAL_SD::deleteFile(const char* path) {
    if (!mounted) return false;
    return SD.remove(path);
}

bool HAL_SD::fileExists(const char* path) {
    if (!mounted) return false;
    return SD.exists(path);
}
