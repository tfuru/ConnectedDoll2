#include "hal_sd.h"

bool HAL_SD::mounted = false;

bool HAL_SD::init() {
    // 標準のグローバル SPI オブジェクトを指定ピンで初期化 (CS=-1で競合回避)
    SPI.begin(PIN_SD_SCK, PIN_SD_MISO, PIN_SD_MOSI, -1);
    
    // SDライブラリの開始。標準の SPI オブジェクトを渡し、16MHzに設定して高速書き込みを実現
    if (!SD.begin(PIN_SD_CS, SPI, 16000000)) { 
        Serial.println("SD Card Mount Failed (16MHz), retrying at 8MHz...");
        if (!SD.begin(PIN_SD_CS, SPI, 8000000)) {
            Serial.println("SD Card Mount Failed");
            mounted = false;
            return false;
        }
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

bool HAL_SD::ensureParentDirectories(const char* filePath) {
    if (!mounted || filePath == nullptr) return false;
    String fullPath(filePath);
    if (!fullPath.startsWith("/")) {
        fullPath = "/" + fullPath;
    }

    int lastSlash = fullPath.lastIndexOf('/');
    if (lastSlash <= 0) {
        // ルート直下のファイルなのでサブディレクトリ作成不要
        return true;
    }

    int searchFrom = 1;
    while (searchFrom <= lastSlash) {
        int nextSlash = fullPath.indexOf('/', searchFrom);
        if (nextSlash == -1 || nextSlash > lastSlash) {
            break;
        }
        String dirPath = fullPath.substring(0, nextSlash);
        if (dirPath.length() > 0 && !SD.exists(dirPath)) {
            if (!SD.mkdir(dirPath)) {
                Serial.printf("[SD] Failed to create directory: %s\n", dirPath.c_str());
                return false;
            }
            Serial.printf("[SD] Created directory: %s\n", dirPath.c_str());
        }
        searchFrom = nextSlash + 1;
    }
    return true;
}
