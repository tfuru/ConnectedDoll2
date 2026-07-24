#ifndef BLE_MANAGER_H
#define BLE_MANAGER_H

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <SD.h>

#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHAR_UUID_TIME         "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define CHAR_UUID_FILE_CTRL    "e32a4e2b-fbc6-4b95-a22a-28d88b409600"
#define CHAR_UUID_FILE_DATA    "7b01d784-fb3b-4ce1-897b-cfd1264c7847"
#define CHAR_UUID_ALARM_CONFIG "e82d0001-fbc6-4b95-a22a-28d88b409600"
#define CHAR_UUID_LED_BRIGHTNESS "e82d0002-fbc6-4b95-a22a-28d88b409600"

class BLEManager {
public:
    static void init(const char* deviceName);
    static void startAdvertising();
    static bool isConnected();
    static bool isTransferringFile();
    static String getTransferringFileName();
    
private:
    static bool connected;
    static bool fileTransferActive;
    static String targetFileName;
    static File activeFile;

    class ServerCallbacks : public BLEServerCallbacks {
        void onConnect(BLEServer* pServer) override;
        void onDisconnect(BLEServer* pServer) override;
    };

    class TimeCallbacks : public BLECharacteristicCallbacks {
        void onWrite(BLECharacteristic* pCharacteristic) override;
        void onRead(BLECharacteristic* pCharacteristic) override;
    };

    class FileCtrlCallbacks : public BLECharacteristicCallbacks {
        void onWrite(BLECharacteristic* pCharacteristic) override;
    };

    class FileDataCallbacks : public BLECharacteristicCallbacks {
        void onWrite(BLECharacteristic* pCharacteristic) override;
    };

    class AlarmCallbacks : public BLECharacteristicCallbacks {
        void onWrite(BLECharacteristic* pCharacteristic) override;
        void onRead(BLECharacteristic* pCharacteristic) override;
    };

    class LEDBrightnessCallbacks : public BLECharacteristicCallbacks {
        void onWrite(BLECharacteristic* pCharacteristic) override;
        void onRead(BLECharacteristic* pCharacteristic) override;
    };
};

#endif // BLE_MANAGER_H
