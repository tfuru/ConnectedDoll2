#ifndef HAL_OTA_H
#define HAL_OTA_H

#include <Arduino.h>

class HAL_OTA {
public:
    // SDカード上の更新ファイル（デフォルト: /update.bin）を検証し、OTAアップデートを実行する
    // 成功した場合はデバイスを自動再起動する
    static bool performUpdateFromSD(const char* filePath = "/update.bin");

    // 指定された更新ファイルが存在するか確認する
    static bool hasPendingUpdate(const char* filePath = "/update.bin");
};

#endif // HAL_OTA_H
