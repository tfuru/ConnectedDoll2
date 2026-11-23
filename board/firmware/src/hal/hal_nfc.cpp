#include "hal_nfc.h"

#include "nfc/nfc_preset_parser.h"

#include <M5UnitUnified.h>
#include <M5UnitUnifiedNFC.h>
#include <Wire.h>
#include <cctype>
#include <cstring>
#include <vector>

namespace {

constexpr uint8_t NFC_I2C_ADDR = 0x50;
constexpr unsigned long SAME_TAG_COOLDOWN_MS = 1500;
constexpr size_t MAX_TYPE2_READ_BYTES = 512;

m5::unit::UnitUnified s_units;
m5::unit::UnitNFC s_unit{NFC_I2C_ADDR};
m5::nfc::NFCLayerA s_nfcA{s_unit};

std::string s_lastUid;
unsigned long s_lastReadMs = 0;

bool equalsIgnoreCaseCstr(const char* a, const char* b) {
    if (!a || !b) return false;
    while (*a && *b) {
        if (std::tolower(static_cast<unsigned char>(*a)) !=
            std::tolower(static_cast<unsigned char>(*b))) {
            return false;
        }
        ++a;
        ++b;
    }
    return *a == '\0' && *b == '\0';
}

std::string formatHexPreview(const uint8_t* data, size_t len, size_t maxBytes = 16) {
    if (!data || len == 0) return "";
    const size_t n = (len < maxBytes) ? len : maxBytes;
    std::string out;
    out.reserve(n * 3);
    char buf[4];
    for (size_t i = 0; i < n; ++i) {
        snprintf(buf, sizeof(buf), (i + 1 < n) ? "%02X " : "%02X", data[i]);
        out += buf;
    }
    return out;
}

bool readType2FallbackAndPreview(NfcReadResult& out) {
    // Type 2 Tag ユーザー領域は Page 4 開始（16バイト = 4ページ単位で読み出し）
    std::vector<uint8_t> userMem;
    userMem.reserve(160);

    uint8_t chunk[16]{};
    if (!s_nfcA.read16(chunk, 4)) {
        return false;
    }
    userMem.insert(userMem.end(), chunk, chunk + 16);
    out.rawHexPreview = formatHexPreview(chunk, 16);

    size_t ndefOffset = 0;
    size_t ndefLen = 0;
    size_t requiredTotal = 0;
    auto peek = nfc_preset::peekType2NdefBounds(
        userMem.data(), userMem.size(), ndefOffset, ndefLen, requiredTotal);

    uint8_t nextPage = 8;
    while (peek == nfc_preset::TlvPeekStatus::NeedMoreData &&
           userMem.size() < MAX_TYPE2_READ_BYTES) {
        const size_t targetBytes =
            (requiredTotal > 0 && requiredTotal <= MAX_TYPE2_READ_BYTES)
                ? requiredTotal
                : (userMem.size() + 16);

        while (userMem.size() < targetBytes && userMem.size() < MAX_TYPE2_READ_BYTES) {
            if (!s_nfcA.read16(chunk, nextPage)) {
                break;
            }
            userMem.insert(userMem.end(), chunk, chunk + 16);
            nextPage = static_cast<uint8_t>(nextPage + 4);
        }

        const size_t prevSize = userMem.size();
        peek = nfc_preset::peekType2NdefBounds(
            userMem.data(), userMem.size(), ndefOffset, ndefLen, requiredTotal);
        if (userMem.size() == prevSize && peek == nfc_preset::TlvPeekStatus::NeedMoreData &&
            requiredTotal <= userMem.size()) {
            break;
        }
        if (userMem.size() < targetBytes) {
            // これ以上読めなかった
            break;
        }
    }

    if (peek == nfc_preset::TlvPeekStatus::FoundComplete) {
        nfc_preset::PresetPayload parsed;
        if (nfc_preset::parsePresetFromNdefMessage(
                userMem.data() + ndefOffset, ndefLen, parsed)) {
            out.presetValid = true;
            out.presetUuid = parsed.uuid;
            out.presetName = parsed.name;
            out.note.clear();
            return true;
        }
    }
    return false;
}

}  // namespace

bool HAL_NFC::initialized = false;

bool HAL_NFC::init() {
    initialized = false;
    s_lastUid.clear();
    s_lastReadMs = 0;

    // 事前 I2C 疎通チェック（未接続時にリトライ待機で起動遅延させない）
    Wire.beginTransmission(NFC_I2C_ADDR);
    const uint8_t i2cErr = Wire.endTransmission();
    if (i2cErr != 0) {
        Serial.printf("[NFC] ST25R3916 (0x%02X) not found on I2C bus (err=%u). Continuing without NFC.\n",
                      NFC_I2C_ADDR, i2cErr);
        return false;
    }

    auto cfg = s_unit.config();
    cfg.mode = m5::nfc::NFC::A;
    cfg.vdd_voltage_5V = false;  // M5Stack Unit NFC (U216) 標準設定（内部3.3V動作）
    cfg.using_irq = false;       // HY2.0-4P 接続のため IRQ ピン未使用
    s_unit.config(cfg);

    if (!s_units.add(s_unit, Wire) || !s_units.begin()) {
        Serial.println("[NFC] Failed to initialize ST25R3916 via M5UnitUnified.");
        return false;
    }

    initialized = true;
    Serial.println("[NFC] ST25R3916 (0x50) initialized successfully.");
    return true;
}

bool HAL_NFC::isInitialized() {
    return initialized;
}

bool HAL_NFC::pollTag(NfcReadResult& out) {
    out = NfcReadResult{};
    if (!initialized) {
        return false;
    }

    s_units.update();

    // REQA による単発プローブ（非検出時は数msで即復帰し、音声・BLEを阻害しない）
    m5::nfc::a::PICC picc{};
    if (!s_nfcA.request(picc.atqa)) {
        return false;
    }

    if (!s_nfcA.select(picc)) {
        s_nfcA.deactivate();
        return false;
    }

    const std::string uidStr = picc.uidAsString();
    const unsigned long nowMs = millis();

    // RF 瞬断等による同一タグの連続再検出を抑止
    if (!s_lastUid.empty() && uidStr == s_lastUid &&
        (nowMs - s_lastReadMs) < SAME_TAG_COOLDOWN_MS) {
        s_nfcA.deactivate();
        return false;
    }

    // タグ種別識別（identify は完了後に HALT するため reactivate で再アクティブ化）
    const bool identified = s_nfcA.identify(picc);
    const bool active = s_nfcA.reactivate(picc);

    out.uid = picc.uidAsString();
    out.cardType = picc.typeAsString();

    if (active) {
        bool validNdef = false;
        if (identified && picc.supportsNDEF() && s_nfcA.ndefIsValidFormat(validNdef)) {
            if (validNdef) {
                m5::nfc::ndef::TLV msg{};
                if (s_nfcA.ndefRead(msg) && msg.isMessageTLV()) {
                    for (const auto& rec : msg.records()) {
                        if (rec.tnf() == m5::nfc::ndef::TNF::MIMEMedia &&
                            equalsIgnoreCaseCstr(rec.type(), nfc_preset::PRESET_MIME_TYPE) &&
                            rec.payload() != nullptr &&
                            rec.payloadSize() > 0) {
                            nfc_preset::PresetPayload parsed;
                            if (nfc_preset::parsePresetJson(rec.payload(), rec.payloadSize(), parsed)) {
                                out.presetValid = true;
                                out.presetUuid = parsed.uuid;
                                out.presetName = parsed.name;
                                break;
                            }
                        }
                    }
                    if (!out.presetValid) {
                        out.note = "MIME 'application/vnd.connecteddoll.preset' not found or invalid JSON";
                    }
                } else {
                    out.note = "NDEF Message TLV not found or read failed";
                }
            } else {
                out.note = "Tag is not NDEF formatted";
            }
        } else {
            out.note = identified ? "Tag does not support NDEF" : "Tag type identification failed";
        }

        // Type 2 Tag のフォールバック読取＆未検出時診断ダンプ取得
        if (!out.presetValid && (picc.isNTAG2() || picc.isMifareUltralight() || !identified)) {
            readType2FallbackAndPreview(out);
        }
    } else {
        out.note = "Failed to reactivate tag after identify";
    }

    // タグを HALT 状態へ移行（置いたままの連続再検出を防止）
    s_nfcA.deactivate();

    s_lastUid = out.uid;
    s_lastReadMs = nowMs;
    return true;
}

void HAL_NFC::sleep() {
    if (!initialized) {
        return;
    }
    Serial.println("[NFC] Stopping RF field and entering ST25R3916 power-down...");
    s_unit.writeDirectCommand(m5::unit::st25r3916::command::CMD_STOP_ALL_ACTIVITIES);
    // Operation Control レジスタを 0x00 に設定（osc / rx / tx / wu をすべて停止）
    s_unit.writeOperationControl(0x00);
}
