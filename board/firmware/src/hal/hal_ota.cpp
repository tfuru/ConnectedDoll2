#include "hal_ota.h"
#include "hal_sd.h"
#include "hal_io.h"
#include "hal_power.h"
#include <SD.h>
#include <Update.h>

bool HAL_OTA::hasPendingUpdate(const char* filePath) {
    if (!HAL_SD::isMounted()) {
        return false;
    }
    return SD.exists(filePath);
}

bool HAL_OTA::performUpdateFromSD(const char* filePath) {
    if (!HAL_SD::isMounted()) {
        Serial.println("[OTA] Error: SD card is not mounted.");
        return false;
    }

    if (!SD.exists(filePath)) {
        Serial.printf("[OTA] Update file not found: %s\n", filePath);
        return false;
    }

    File updateFile = SD.open(filePath, FILE_READ);
    if (!updateFile) {
        Serial.printf("[OTA] Failed to open update file: %s\n", filePath);
        return false;
    }

    size_t updateSize = updateFile.size();
    if (updateSize == 0) {
        Serial.println("[OTA] Error: Update file is empty (0 bytes).");
        updateFile.close();
        SD.remove(filePath);
        return false;
    }

    Serial.printf("[OTA] Starting firmware update from %s (Size: %u bytes)...\n", filePath, updateSize);

    // OTA書き込み中のLED表示: 紫色点灯
    HAL_IO::setLEDColor(80, 0, 80);

    if (!Update.begin(updateSize, U_FLASH)) {
        Serial.printf("[OTA] Error: Update.begin failed. Error code: %u\n", Update.getError());
        Update.printError(Serial);
        updateFile.close();
        HAL_IO::setLEDColor(100, 0, 0); // 赤色エラー
        delay(1000);
        return false;
    }

    const size_t BUFFER_SIZE = 1024;
    uint8_t buffer[BUFFER_SIZE];
    size_t written = 0;
    size_t lastPercent = 0;
    bool ledToggle = false;

    while (updateFile.available()) {
        HAL_Power::resetIdleTimer();
        size_t bytesRead = updateFile.read(buffer, BUFFER_SIZE);
        if (bytesRead > 0) {
            size_t bytesWritten = Update.write(buffer, bytesRead);
            if (bytesWritten != bytesRead) {
                Serial.printf("[OTA] Error: Write mismatch (%u != %u)\n", bytesWritten, bytesRead);
                break;
            }
            written += bytesWritten;

            // 進捗のパーセント表示
            size_t percent = (written * 100) / updateSize;
            if (percent >= lastPercent + 10) {
                lastPercent = percent;
                Serial.printf("[OTA] Flashing: %u%% (%u / %u bytes)\n", percent, written, updateSize);
                
                // LED点滅で書き込み中をアピール
                ledToggle = !ledToggle;
                if (ledToggle) {
                    HAL_IO::setLEDColor(120, 0, 120);
                } else {
                    HAL_IO::setLEDColor(40, 0, 40);
                }
            }
        }
    }

    updateFile.close();

    if (written == updateSize && Update.end(true)) {
        if (Update.isFinished()) {
            Serial.println("[OTA] Firmware update SUCCESSFUL! Cleaning up and restarting...");
            // 更新成功: 緑色点灯
            HAL_IO::setLEDColor(0, 120, 0);
            SD.remove(filePath);
            delay(1000);
            ESP.restart();
            return true;
        } else {
            Serial.println("[OTA] Error: Update not finished.");
        }
    } else {
        Serial.printf("[OTA] Update failed! Error code: %u\n", Update.getError());
        Update.printError(Serial);
    }

    // 失敗時は赤色点灯
    HAL_IO::setLEDColor(120, 0, 0);
    delay(2000);
    return false;
}
