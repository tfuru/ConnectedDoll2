#include "ble_manager.h"
#include "../hal/hal_rtc.h"
#include "../hal/hal_io.h"
#include "../audio/alarm_manager.h"

bool BLEManager::connected = false;
bool BLEManager::fileTransferActive = false;
String BLEManager::targetFileName = "";
File BLEManager::activeFile;

void BLEManager::init(const char* deviceName) {
    BLEDevice::init(deviceName);
    // MTUサイズを拡張して1パケットあたりの転送量を増やす（最大517）
    BLEDevice::setMTU(517); 
    
    BLEServer* pServer = BLEDevice::createServer();
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
    Serial.println("BLE Client Connected");
}

void BLEManager::ServerCallbacks::onDisconnect(BLEServer* pServer) {
    connected = false;
    Serial.println("BLE Client Disconnected");
    
    // 転送中に切断された場合はファイルを安全に閉じる
    if (fileTransferActive) {
        if (activeFile) {
            activeFile.close();
            Serial.println("File closed prematurely due to disconnect");
        }
        fileTransferActive = false;
    }
    // アドバタイズを再開して再接続を待つ
    BLEDevice::startAdvertising();
}

void BLEManager::TimeCallbacks::onWrite(BLECharacteristic* pCharacteristic) {
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
    String timeStr = HAL_RTC::getCurrentTimeStr();
    pCharacteristic->setValue(timeStr.c_str());
    Serial.printf("BLE RTC Time READ requested. Value: %s\n", timeStr.c_str());
}

void BLEManager::FileCtrlCallbacks::onWrite(BLECharacteristic* pCharacteristic) {
    std::string value = pCharacteristic->getValue();
    String cmd = String(value.c_str());
    
    if (cmd.startsWith("START:")) {
        String rawName = cmd.substring(6);
        int commaIdx = rawName.indexOf(',');
        if (commaIdx != -1) {
            rawName = rawName.substring(0, commaIdx);
        }
        targetFileName = "/" + rawName;
        
        // 既存ファイルをクリアして新しく書き込みオープン
        if (SD.exists(targetFileName)) {
            SD.remove(targetFileName);
        }
        
        activeFile = SD.open(targetFileName, FILE_WRITE);
        if (activeFile) {
            fileTransferActive = true;
            Serial.printf("File transfer started: %s\n", targetFileName.c_str());
        } else {
            Serial.printf("Failed to open file for writing: %s\n", targetFileName.c_str());
        }
    } else if (cmd == "END") {
        if (fileTransferActive && activeFile) {
            activeFile.close();
            fileTransferActive = false;
            
            // 受信完了ログと最終ファイルサイズの確認
            File f = SD.open(targetFileName);
            size_t size = f.size();
            f.close();
            Serial.printf("File transfer completed: %s (Size: %d bytes)\n", targetFileName.c_str(), size);
        }
    }
}

void BLEManager::FileDataCallbacks::onWrite(BLECharacteristic* pCharacteristic) {
    if (!fileTransferActive || !activeFile) {
        return;
    }
    
    std::string value = pCharacteristic->getValue();
    if (value.length() > 0) {
        activeFile.write((const uint8_t*)value.data(), value.length());
    }
}

void BLEManager::AlarmCallbacks::onWrite(BLECharacteristic* pCharacteristic) {
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
    String state = AlarmManager::getSchedulesStr();
    pCharacteristic->setValue(state.c_str());
    Serial.printf("BLE Alarm READ requested. Value: %s\n", state.c_str());
}

void BLEManager::LEDBrightnessCallbacks::onWrite(BLECharacteristic* pCharacteristic) {
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
    uint8_t brightness = HAL_IO::getLEDBrightness();
    char buf[8];
    itoa(brightness, buf, 10);
    pCharacteristic->setValue(buf);
    Serial.printf("BLE LED Brightness READ requested. Value: %d\n", brightness);
}
