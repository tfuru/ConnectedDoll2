#ifndef NFC_PRESET_PARSER_H
#define NFC_PRESET_PARSER_H

#include <cstddef>
#include <cstdint>
#include <string>

namespace nfc_preset {

constexpr const char* PRESET_MIME_TYPE = "application/vnd.connecteddoll.preset";
constexpr uint8_t NDEF_TNF_MIME_MEDIA = 0x02;

struct PresetPayload {
    bool valid = false;
    std::string uuid;
    std::string name;
};

enum class TlvPeekStatus : uint8_t {
    FoundComplete,   // NDEF TLV found and fully present in buffer
    NeedMoreData,    // NDEF TLV found (or header truncated), read up to requiredBytes
    NotFound,        // Terminator reached or buffer exhausted without NDEF TLV
    Invalid          // Malformed TLV
};

/// RFC 4122 UUID形式 (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) を検証する（前後空白は無視）
bool isValidUuid(const std::string& value);

/// Type 2 Tag ユーザーメモリ（Page 4 先頭起点）の TLV を確認し、必要な総バイト数を算出する
TlvPeekStatus peekType2NdefBounds(const uint8_t* userMem,
                                  size_t len,
                                  size_t& ndefOffset,
                                  size_t& ndefLength,
                                  size_t& requiredTotalBytes);

/// Type 2 Tag ユーザーメモリ（Page 4 先頭起点）からプリセット NDEF MIME レコードを抽出・パースする
bool parsePresetFromType2Memory(const uint8_t* userMem,
                                size_t len,
                                PresetPayload& out);

/// NDEF メッセージバイト列からプリセット MIME レコード（TNF=0x02）を抽出・パースする
bool parsePresetFromNdefMessage(const uint8_t* ndefData,
                                size_t ndefLen,
                                PresetPayload& out);

/// UTF-8 JSON ペイロード {"uuid":"...","name":"..."} をパース・検証する
bool parsePresetJson(const uint8_t* jsonData,
                     size_t jsonLen,
                     PresetPayload& out);

}  // namespace nfc_preset

#endif  // NFC_PRESET_PARSER_H
