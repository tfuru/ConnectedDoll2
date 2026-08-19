#include "ble_manager.h"
#include "../hal/hal_rtc.h"
#include "../hal/hal_io.h"
#include "../hal/hal_power.h"
#include "../audio/alarm_manager.h"
#include <freertos/FreeRTOS.h>
#include <freertos/ringbuf.h>

BLEServer* BLEManager::pServer = nullptr;
volatile bool BLEManager::connected = false;
volatile bool BLEManager::fileTransferActive = false;
volatile bool BLEManager::pendingStartRequested = false;
volatile bool BLEManager::transferEndRequested = false;
String BLEManager::targetFileName = "";
String BLEManager::pendingFileName = "";
File BLEManager::activeFile;

// 転送データ用リングバッファ (24KBに拡張して高速転送バーストを受け止める)
static RingbufHandle_t s_transferRingBuf = NULL;
static const size_t RING_BUF_SIZE = 24576;

void BLEManager::init(const char* deviceName) {
    BLEDevice::init(deviceName);
    // MTUサイズを拡張して1パケットあたりの転送量を増やす（最大517）
    BLEDevice::setMTU(517); 
    
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());
    
    BLEService* pService = pServer->createService(SERVICE_UUID);
    
    // 1. 時刻設定・取得用
    BLECharacteristic* pTimeChar = pService->createCharacteristic(
        CHAR_UUID_TIME,
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_READ
    );
    pTimeChar->setCallbacks(new TimeCallbacks());
    
    // 2. ファイル転送制御用 (START:filename / END)
    BLECharacteristic* pFileCtrlChar = pService->createCharacteristic(
        CHAR_UUID_FILE_CTRL,
        BLECharacteristic::PROPERTY_WRITE
    );
    pFileCtrlChar->setCallbacks(new FileCtrlCallbacks());
    
    // 3. ファイルデータ受信用 (バイナリ)
    BLECharacteristic* pFileDataChar = pService->createCharacteristic(
        CHAR_UUID_FILE_DATA,
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
    );
    pFileDataChar->setCallbacks(new FileDataCallbacks());

    // 4. アラームスケジュール設定用 (Read/Write)
    BLECharacteristic* pAlarmChar = pService->createCharacteristic(
        CHAR_UUID_ALARM_CONFIG,
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_READ
    );
    pAlarmChar->setCallbacks(new AlarmCallbacks());

    // 5. LED明るさ設定用 (Read/Write)
    BLECharacteristic* pLEDBrightChar = pService->createCharacteristic(
        CHAR_UUID_LED_BRIGHTNESS,
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_READ
    );
    pLEDBrightChar->setCallbacks(new LEDBrightnessCallbacks());

    // 6. LED推しカラー設定用 (Read/Write)
    BLECharacteristic* pLEDColorChar = pService->createCharacteristic(
        CHAR_UUID_LED_COLOR,
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_READ
    );
    pLEDColorChar->setCallbacks(new LEDColorCallbacks());
    
    pService->start();
}

void BLEManager::startAdvertising() {
    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);  // iOS推奨パラメータ
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();
    Serial.println("BLE Advertising started");
}

bool BLEManager::isConnected() {
    if (pServer != nullptr && pServer->getConnectedCount() > 0) {
        return true;
    }
    return connected;
}

bool BLEManager::isTransferringFile() {
    return fileTransferActive;
}

String BLEManager::getTransferringFileName() {
    return targetFileName;
}

void BLEManager::ServerCallbacks::onConnect(BLEServer* pServer) {
    connected = true;
    HAL_Power::resetIdleTimer();
    Serial.println("BLE Client Connected");
}

void BLEManager::ServerCallbacks::onConnect(BLEServer* pServer, esp_ble_gatts_cb_param_t *param) {
    connected = true;
    HAL_Power::resetIdleTimer();
    Serial.println("BLE Client Connected (with params)");

    // 接続パラメータの安定化 (Connection Interval: 15-30ms, Supervision Timeout: 5000ms)
    // ファイル転送中のパケット集中によるGATT切断(status=8)を防止
    if (param != nullptr) {
        pServer->updateConnParams(param->connect.remote_bda, 12, 24, 0, 500); // 12*1.25ms=15ms, 24*1.25ms=30ms, 500*10ms=5000ms
        Serial.println("[BLE] Requested connection parameters update (Timeout: 5000ms)");
    }
}

void BLEManager::ServerCallbacks::onDisconnect(BLEServer* pServer) {
    connected = false;
    HAL_Power::resetIdleTimer();
    Serial.println("BLE Client Disconnected");
    
    // 転送中に切断された場合はファイルを安全に閉じる
    if (fileTransferActive) {
        if (activeFile) {
            activeFile.close();
            Serial.println("File closed prematurely due to disconnect");
        }
        fileTransferActive = false;
        transferEndRequested = false;
        if (s_transferRingBuf != NULL) {
            vRingbufferDelete(s_transferRingBuf);
            s_transferRingBuf = NULL;
        }
    }
    // アドバタイズを再開して再接続を待つ
    BLEDevice::startAdvertising();
}

void BLEManager::TimeCallbacks::onWrite(BLECharacteristic* pCharacteristic) {
    HAL_Power::resetIdleTimer();
    std::string value = pCharacteristic->getValue();
    
    // 文字列形式 "YYYY-MM-DD HH:MM:SS" (長さ19) を優先的に判別
    if (value.length() == 19) {
        String timeStr = String(value.c_str());
        int year = timeStr.substring(0, 4).toInt();
        int month = timeStr.substring(5, 7).toInt();
        int day = timeStr.substring(8, 10).toInt();
        int hour = timeStr.substring(11, 13).toInt();
        int minute = timeStr.substring(14, 16).toInt();
        int second = timeStr.substring(17, 19).toInt();
        
        HAL_RTC::setDateTime(year, month, day, hour, minute, second);
        Serial.printf("RTC synced via BLE (str): %s\n", timeStr.c_str());
    } else if (value.length() == 7) {
        // バイナリ形式 [YYYY(2bytes), MM(1), DD(1), HH(1), MM(1), SS(1)]
        uint16_t year = (value[0] << 8) | value[1];
        uint8_t month = value[2];
        uint8_t day = value[3];
        uint8_t hour = value[4];
        uint8_t minute = value[5];
        uint8_t second = value[6];
        
        HAL_RTC::setDateTime(year, month, day, hour, minute, second);
        Serial.printf("RTC synced via BLE (bin): %04d-%02d-%02d %02d:%02d:%02d\n",
                      year, month, day, hour, minute, second);
    } else {
        Serial.printf("RTC sync failed: Invalid payload length (%d)\n", value.length());
    }
}

void BLEManager::TimeCallbacks::onRead(BLECharacteristic* pCharacteristic) {
    HAL_Power::resetIdleTimer();
    String timeStr = HAL_RTC::getCurrentTimeStr();
    pCharacteristic->setValue(timeStr.c_str());
    Serial.printf("BLE RTC Time READ requested. Value: %s\n", timeStr.c_str());
}

void BLEManager::FileCtrlCallbacks::onWrite(BLECharacteristic* pCharacteristic) {
    HAL_Power::resetIdleTimer();
    std::string value = pCharacteristic->getValue();
    String cmd = String(value.c_str());
    
    if (cmd.startsWith("START:")) {
        String rawName = cmd.substring(6);
        int commaIdx = rawName.indexOf(',');
        if (commaIdx != -1) {
            rawName = rawName.substring(0, commaIdx);
        }
        pendingFileName = "/" + rawName;
        pendingStartRequested = true;
        fileTransferActive = true;
        transferEndRequested = false;
        
        // 既存リングバッファの再生成
        if (s_transferRingBuf != NULL) {
            vRingbufferDelete(s_transferRingBuf);
            s_transferRingBuf = NULL;
        }
        s_transferRingBuf = xRingbufferCreate(RING_BUF_SIZE, RINGBUF_TYPE_BYTEBUF);
        Serial.printf("[BLE] START received for %s (Non-blocking queue init)\n", pendingFileName.c_str());
    } else if (cmd == "END") {
        if (fileTransferActive) {
            transferEndRequested = true;
            Serial.println("[BLE] END received. Flushing remaining buffer...");
        }
    }
}

void BLEManager::FileDataCallbacks::onWrite(BLECharacteristic* pCharacteristic) {
    HAL_Power::resetIdleTimer();
    if (!fileTransferActive || s_transferRingBuf == NULL) {
        return;
    }
    
    std::string value = pCharacteristic->getValue();
    if (value.length() > 0) {
        // SDへの直接書き込みを行わず、リングバッファへ即時格納 (最大10ms待機)
        BaseType_t res = xRingbufferSend(s_transferRingBuf, value.data(), value.length(), pdMS_TO_TICKS(10));
        if (res != pdTRUE) {
            Serial.println("[BLE] Warning: RingBuffer overflow, dropping packet!");
        }
    }
}

void BLEManager::processTransferBuffer() {
    // 1. ファイルオープンの保留要求があればメインループ上で安全にSDを初期化
    if (pendingStartRequested) {
        pendingStartRequested = false;
        targetFileName = pendingFileName;
        
        if (activeFile) {
            activeFile.close();
        }
        if (SD.exists(targetFileName)) {
            SD.remove(targetFileName);
        }
        
        activeFile = SD.open(targetFileName, FILE_WRITE);
        if (activeFile) {
            Serial.printf("[SD] File opened for writing: %s\n", targetFileName.c_str());
        } else {
            Serial.printf("[SD] Failed to open file for writing: %s\n", targetFileName.c_str());
            fileTransferActive = false;
        }
    }

    if (!fileTransferActive || !activeFile) {
        return;
    }
    
    HAL_Power::resetIdleTimer();

    // 2. リングバッファからデータを取得してSDへ書き込む (マルチセクタ単位: 4096バイト)
    if (s_transferRingBuf != NULL) {
        size_t itemSize = 0;
        uint8_t* item = (uint8_t*)xRingbufferReceiveUpTo(s_transferRingBuf, &itemSize, 0, 4096);
        if (item != NULL && itemSize > 0) {
            activeFile.write(item, itemSize);
            vRingbufferReturnItem(s_transferRingBuf, (void*)item);
        }
    }

    // 3. ENDが要求され、かつリングバッファが完全に空になったらファイルをクローズ
    if (transferEndRequested) {
        size_t remainingSize = 0;
        uint8_t* checkItem = (uint8_t*)xRingbufferReceiveUpTo(s_transferRingBuf, &remainingSize, 0, 1);
        if (checkItem != NULL) {
            // まだデータが残っているので戻して次回以降に処理
            vRingbufferReturnItem(s_transferRingBuf, (void*)checkItem);
        } else {
            // 全データ書き込み完了
            activeFile.flush();
            activeFile.close();
            fileTransferActive = false;
            transferEndRequested = false;

            if (s_transferRingBuf != NULL) {
                vRingbufferDelete(s_transferRingBuf);
                s_transferRingBuf = NULL;
            }

            File f = SD.open(targetFileName);
            size_t size = f ? f.size() : 0;
            if (f) f.close();
            Serial.printf("[SD] File transfer completed: %s (Size: %d bytes)\n", targetFileName.c_str(), size);
        }
    }
}

void BLEManager::AlarmCallbacks::onWrite(BLECharacteristic* pCharacteristic) {
    HAL_Power::resetIdleTimer();
    std::string value = pCharacteristic->getValue();
    String cmd = String(value.c_str());
    
    if (cmd.startsWith("SET:")) {
        // フォーマット: SET:index,YYYY-MM-DD HH:MM
        int commaIndex = cmd.indexOf(',');
        if (commaIndex != -1) {
            uint8_t index = cmd.substring(4, commaIndex).toInt();
            String dateStr = cmd.substring(commaIndex + 1);
            if (dateStr.startsWith("DAILY ")) {
                if (dateStr.length() == 11) { // "DAILY HH:MM"
                    uint8_t hour = dateStr.substring(6, 8).toInt();
                    uint8_t minute = dateStr.substring(9, 11).toInt();
                    if (AlarmManager::setAlarm(index, 0, 0, 0, hour, minute, true)) {
                        Serial.printf("BLE Alarm SET success (Daily): slot %d to %s\n", index, dateStr.c_str());
                    } else {
                        Serial.println("BLE Alarm SET failed: Invalid index");
                    }
                } else {
                    Serial.println("BLE Alarm SET failed: Invalid DAILY string length");
                }
            } else if (dateStr.length() == 16) { // "YYYY-MM-DD HH:MM"
                uint16_t year = dateStr.substring(0, 4).toInt();
                uint8_t month = dateStr.substring(5, 7).toInt();
                uint8_t day = dateStr.substring(8, 10).toInt();
                uint8_t hour = dateStr.substring(11, 13).toInt();
                uint8_t minute = dateStr.substring(14, 16).toInt();
                
                if (AlarmManager::setAlarm(index, year, month, day, hour, minute, false)) {
                    Serial.printf("BLE Alarm SET success: slot %d to %s\n", index, dateStr.c_str());
                } else {
                    Serial.println("BLE Alarm SET failed: Invalid index");
                }
            } else {
                Serial.println("BLE Alarm SET failed: Invalid date string length");
            }
        }
    } else if (cmd.startsWith("DEL:")) {
        // フォーマット: DEL:index
        uint8_t index = cmd.substring(4).toInt();
        if (AlarmManager::deleteAlarm(index)) {
            Serial.printf("BLE Alarm DEL success: slot %d\n", index);
        } else {
            Serial.println("BLE Alarm DEL failed: Invalid index");
        }
    }
}

void BLEManager::AlarmCallbacks::onRead(BLECharacteristic* pCharacteristic) {
    HAL_Power::resetIdleTimer();
    String state = AlarmManager::getSchedulesStr();
    pCharacteristic->setValue(state.c_str());
    Serial.printf("BLE Alarm READ requested. Value: %s\n", state.c_str());
}

void BLEManager::LEDBrightnessCallbacks::onWrite(BLECharacteristic* pCharacteristic) {
    HAL_Power::resetIdleTimer();
    std::string value = pCharacteristic->getValue();
    if (value.length() > 0) {
        int brightness = 0;
        if (value.length() == 1 && (value[0] < '0' || value[0] > '9')) {
            brightness = (uint8_t)value[0];
        } else {
            brightness = atoi(value.c_str());
        }
        if (brightness < 0) brightness = 0;
        if (brightness > 255) brightness = 255;
        HAL_IO::setLEDBrightness(brightness);
        Serial.printf("LED Brightness updated via BLE: %d\n", brightness);
    }
}

void BLEManager::LEDBrightnessCallbacks::onRead(BLECharacteristic* pCharacteristic) {
    HAL_Power::resetIdleTimer();
    uint8_t brightness = HAL_IO::getLEDBrightness();
    char buf[8];
    itoa(brightness, buf, 10);
    pCharacteristic->setValue(buf);
    Serial.printf("BLE LED Brightness READ requested. Value: %d\n", brightness);
}

void BLEManager::LEDColorCallbacks::onWrite(BLECharacteristic* pCharacteristic) {
    HAL_Power::resetIdleTimer();
    std::string value = pCharacteristic->getValue();
    if (value.length() >= 3) {
        uint8_t r = 0, g = 0, b = 0;
        if (value[0] == '#' && value.length() == 7) {
            // Hex文字列形式: #RRGGBB
            long rgb = strtol(value.substr(1).c_str(), NULL, 16);
            r = (rgb >> 16) & 0xFF;
            g = (rgb >> 8) & 0xFF;
            b = rgb & 0xFF;
        } else if (value.length() == 3) {
            // バイナリ形式: 3バイトRGB
            r = (uint8_t)value[0];
            g = (uint8_t)value[1];
            b = (uint8_t)value[2];
        } else {
            // カンマ区切り形式: "R,G,B"
            int ir = 0, ig = 0, ib = 0;
            if (sscanf(value.c_str(), "%d,%d,%d", &ir, &ig, &ib) == 3) {
                r = (uint8_t)ir;
                g = (uint8_t)ig;
                b = (uint8_t)ib;
            }
        }
        HAL_IO::setThemeColor(r, g, b);
        Serial.printf("LED Theme Color updated via BLE: R=%d, G=%d, B=%d\n", r, g, b);
    }
}

void BLEManager::LEDColorCallbacks::onRead(BLECharacteristic* pCharacteristic) {
    HAL_Power::resetIdleTimer();
    uint8_t r, g, b;
    HAL_IO::getThemeColor(r, g, b);
    char buf[10];
    snprintf(buf, sizeof(buf), "#%02X%02X%02X", r, g, b);
    pCharacteristic->setValue(buf);
    Serial.printf("BLE LED Theme Color READ requested. Value: %s\n", buf);
}

