#ifndef HAL_NFC_H
#define HAL_NFC_H

#include <Arduino.h>
#include <string>

struct NfcReadResult {
    std::string uid;
    std::string cardType;
    bool presetValid = false;
    std::string presetUuid;
    std::string presetName;
    std::string note;
    std::string rawHexPreview;
};

class HAL_NFC {
public:
    /// ST25R3916 (I2C 0x50) を初期化。未接続時は false を返し既存機能へ影響しない
    static bool init();

    /// NFC ユニットが利用可能かどうか
    static bool isInitialized();

    /// 非ブロッキングで NFC-A タグを 1 回ポーリングし、検出時に NDEF プリセット ID を読み取る
    static bool pollTag(NfcReadResult& out);

    /// Deep Sleep 突入前に ST25R3916 の RF 出力を停止し Power-Down 状態へ移行する
    static void sleep();

private:
    static bool initialized;
};

#endif  // HAL_NFC_H
