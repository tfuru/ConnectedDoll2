#include "nfc_preset_parser.h"

#include <cctype>
#include <cstring>

namespace nfc_preset {

namespace {

bool isHexDigit(char c) {
    return (c >= '0' && c <= '9') ||
           (c >= 'a' && c <= 'f') ||
           (c >= 'A' && c <= 'F');
}

std::string trimAscii(const std::string& s) {
    size_t start = 0;
    while (start < s.size() &&
           (s[start] == ' ' || s[start] == '\t' || s[start] == '\r' || s[start] == '\n')) {
        ++start;
    }
    size_t end = s.size();
    while (end > start &&
           (s[end - 1] == ' ' || s[end - 1] == '\t' || s[end - 1] == '\r' || s[end - 1] == '\n')) {
        --end;
    }
    return s.substr(start, end - start);
}

bool equalsIgnoreCaseAscii(const uint8_t* data, size_t len, const char* expected) {
    const size_t expectedLen = std::strlen(expected);
    if (len != expectedLen) {
        return false;
    }
    for (size_t i = 0; i < len; ++i) {
        const unsigned char a = static_cast<unsigned char>(std::tolower(data[i]));
        const unsigned char b = static_cast<unsigned char>(std::tolower(static_cast<unsigned char>(expected[i])));
        if (a != b) {
            return false;
        }
    }
    return true;
}

void appendUtf8(std::string& out, uint32_t cp) {
    if (cp <= 0x7F) {
        out.push_back(static_cast<char>(cp));
    } else if (cp <= 0x7FF) {
        out.push_back(static_cast<char>(0xC0 | ((cp >> 6) & 0x1F)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else if (cp <= 0xFFFF) {
        out.push_back(static_cast<char>(0xE0 | ((cp >> 12) & 0x0F)));
        out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    } else if (cp <= 0x10FFFF) {
        out.push_back(static_cast<char>(0xF0 | ((cp >> 18) & 0x07)));
        out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
        out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
        out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
    }
}

bool parseHex4(const char* s, size_t len, size_t pos, uint16_t& out) {
    if (pos + 4 > len) {
        return false;
    }
    uint16_t val = 0;
    for (size_t i = 0; i < 4; ++i) {
        char c = s[pos + i];
        val <<= 4;
        if (c >= '0' && c <= '9') {
            val |= static_cast<uint16_t>(c - '0');
        } else if (c >= 'a' && c <= 'f') {
            val |= static_cast<uint16_t>(10 + (c - 'a'));
        } else if (c >= 'A' && c <= 'F') {
            val |= static_cast<uint16_t>(10 + (c - 'A'));
        } else {
            return false;
        }
    }
    out = val;
    return true;
}

struct JsonCursor {
    const char* data;
    size_t len;
    size_t pos;

    void skipWs() {
        while (pos < len) {
            char c = data[pos];
            if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
                ++pos;
            } else {
                break;
            }
        }
    }

    bool parseString(std::string& out) {
        skipWs();
        if (pos >= len || data[pos] != '"') {
            return false;
        }
        ++pos;
        out.clear();
        while (pos < len) {
            char c = data[pos++];
            if (c == '"') {
                return true;
            }
            if (static_cast<unsigned char>(c) < 0x20) {
                return false;
            }
            if (c == '\\') {
                if (pos >= len) {
                    return false;
                }
                char esc = data[pos++];
                switch (esc) {
                    case '"':  out.push_back('"');  break;
                    case '\\': out.push_back('\\'); break;
                    case '/':  out.push_back('/');  break;
                    case 'b':  out.push_back('\b'); break;
                    case 'f':  out.push_back('\f'); break;
                    case 'n':  out.push_back('\n'); break;
                    case 'r':  out.push_back('\r'); break;
                    case 't':  out.push_back('\t'); break;
                    case 'u': {
                        uint16_t u1 = 0;
                        if (!parseHex4(data, len, pos, u1)) {
                            return false;
                        }
                        pos += 4;
                        uint32_t cp = u1;
                        if (u1 >= 0xD800 && u1 <= 0xDBFF) {
                            // High surrogate: expect low surrogate \uDC00..\uDFFF
                            if (pos + 6 <= len && data[pos] == '\\' && data[pos + 1] == 'u') {
                                uint16_t u2 = 0;
                                if (parseHex4(data, len, pos + 2, u2) && u2 >= 0xDC00 && u2 <= 0xDFFF) {
                                    pos += 6;
                                    cp = 0x10000 + (((static_cast<uint32_t>(u1) - 0xD800) << 10) |
                                                    (static_cast<uint32_t>(u2) - 0xDC00));
                                }
                            }
                        }
                        appendUtf8(out, cp);
                        break;
                    }
                    default:
                        return false;
                }
            } else {
                out.push_back(c);
            }
        }
        return false;
    }

    bool skipValue(int depth = 0) {
        if (depth > 16) {
            return false;
        }
        skipWs();
        if (pos >= len) {
            return false;
        }
        char c = data[pos];
        if (c == '"') {
            std::string dummy;
            return parseString(dummy);
        }
        if (c == '{') {
            ++pos;
            skipWs();
            if (pos < len && data[pos] == '}') {
                ++pos;
                return true;
            }
            while (pos < len) {
                std::string k;
                if (!parseString(k)) return false;
                skipWs();
                if (pos >= len || data[pos] != ':') return false;
                ++pos;
                if (!skipValue(depth + 1)) return false;
                skipWs();
                if (pos >= len) return false;
                if (data[pos] == '}') {
                    ++pos;
                    return true;
                }
                if (data[pos] != ',') return false;
                ++pos;
            }
            return false;
        }
        if (c == '[') {
            ++pos;
            skipWs();
            if (pos < len && data[pos] == ']') {
                ++pos;
                return true;
            }
            while (pos < len) {
                if (!skipValue(depth + 1)) return false;
                skipWs();
                if (pos >= len) return false;
                if (data[pos] == ']') {
                    ++pos;
                    return true;
                }
                if (data[pos] != ',') return false;
                ++pos;
            }
            return false;
        }
        if (c == 't') {
            if (pos + 4 <= len && std::memcmp(data + pos, "true", 4) == 0) {
                pos += 4;
                return true;
            }
            return false;
        }
        if (c == 'f') {
            if (pos + 5 <= len && std::memcmp(data + pos, "false", 5) == 0) {
                pos += 5;
                return true;
            }
            return false;
        }
        if (c == 'n') {
            if (pos + 4 <= len && std::memcmp(data + pos, "null", 4) == 0) {
                pos += 4;
                return true;
            }
            return false;
        }
        // JSON number
        if (c == '-' || (c >= '0' && c <= '9')) {
            if (data[pos] == '-') ++pos;
            if (pos >= len || data[pos] < '0' || data[pos] > '9') return false;
            if (data[pos] == '0') {
                ++pos;
            } else {
                while (pos < len && data[pos] >= '0' && data[pos] <= '9') ++pos;
            }
            if (pos < len && data[pos] == '.') {
                ++pos;
                if (pos >= len || data[pos] < '0' || data[pos] > '9') return false;
                while (pos < len && data[pos] >= '0' && data[pos] <= '9') ++pos;
            }
            if (pos < len && (data[pos] == 'e' || data[pos] == 'E')) {
                ++pos;
                if (pos < len && (data[pos] == '+' || data[pos] == '-')) ++pos;
                if (pos >= len || data[pos] < '0' || data[pos] > '9') return false;
                while (pos < len && data[pos] >= '0' && data[pos] <= '9') ++pos;
            }
            return true;
        }
        return false;
    }
};

}  // namespace

bool isValidUuid(const std::string& value) {
    const std::string s = trimAscii(value);
    if (s.size() != 36) {
        return false;
    }
    for (size_t i = 0; i < 36; ++i) {
        if (i == 8 || i == 13 || i == 18 || i == 23) {
            if (s[i] != '-') {
                return false;
            }
        } else {
            if (!isHexDigit(s[i])) {
                return false;
            }
        }
    }
    return true;
}

TlvPeekStatus peekType2NdefBounds(const uint8_t* userMem,
                                  size_t len,
                                  size_t& ndefOffset,
                                  size_t& ndefLength,
                                  size_t& requiredTotalBytes) {
    ndefOffset = 0;
    ndefLength = 0;
    requiredTotalBytes = 0;

    if (!userMem || len == 0) {
        return TlvPeekStatus::NeedMoreData;
    }

    size_t pos = 0;
    while (pos < len) {
        const uint8_t tag = userMem[pos];
        if (tag == 0x00) {
            // NULL TLV
            ++pos;
            continue;
        }
        if (tag == 0xFE) {
            // Terminator TLV
            return TlvPeekStatus::NotFound;
        }

        // TLV with length field (0x01 Lock, 0x02 Memory, 0x03 NDEF, 0xFD Proprietary, etc.)
        if (pos + 1 >= len) {
            requiredTotalBytes = pos + 4;
            return TlvPeekStatus::NeedMoreData;
        }

        size_t valueLen = 0;
        size_t valueStart = 0;
        if (userMem[pos + 1] == 0xFF) {
            if (pos + 3 >= len) {
                requiredTotalBytes = pos + 4;
                return TlvPeekStatus::NeedMoreData;
            }
            valueLen = (static_cast<size_t>(userMem[pos + 2]) << 8) |
                       static_cast<size_t>(userMem[pos + 3]);
            valueStart = pos + 4;
        } else {
            valueLen = userMem[pos + 1];
            valueStart = pos + 2;
        }

        const size_t nextPos = valueStart + valueLen;
        if (nextPos < valueStart) {
            return TlvPeekStatus::Invalid;
        }

        if (tag == 0x03) {
            // NDEF Message TLV found
            ndefOffset = valueStart;
            ndefLength = valueLen;
            requiredTotalBytes = nextPos;
            if (nextPos <= len) {
                return TlvPeekStatus::FoundComplete;
            }
            return TlvPeekStatus::NeedMoreData;
        }

        if (nextPos > len) {
            requiredTotalBytes = nextPos + 4;
            return TlvPeekStatus::NeedMoreData;
        }
        pos = nextPos;
    }

    return TlvPeekStatus::NotFound;
}

bool parsePresetJson(const uint8_t* jsonData,
                     size_t jsonLen,
                     PresetPayload& out) {
    out = PresetPayload{};
    if (!jsonData || jsonLen == 0) {
        return false;
    }

    JsonCursor cur{reinterpret_cast<const char*>(jsonData), jsonLen, 0};
    cur.skipWs();
    if (cur.pos >= cur.len || cur.data[cur.pos] != '{') {
        return false;
    }
    ++cur.pos;
    cur.skipWs();

    bool hasUuid = false;
    std::string uuidRaw;
    std::string nameVal;

    if (cur.pos < cur.len && cur.data[cur.pos] == '}') {
        ++cur.pos;
    } else {
        while (cur.pos < cur.len) {
            std::string key;
            if (!cur.parseString(key)) {
                return false;
            }
            cur.skipWs();
            if (cur.pos >= cur.len || cur.data[cur.pos] != ':') {
                return false;
            }
            ++cur.pos;
            cur.skipWs();

            if (key == "uuid" && cur.pos < cur.len && cur.data[cur.pos] == '"') {
                if (!cur.parseString(uuidRaw)) {
                    return false;
                }
                hasUuid = true;
            } else if (key == "name" && cur.pos < cur.len && cur.data[cur.pos] == '"') {
                if (!cur.parseString(nameVal)) {
                    return false;
                }
            } else {
                if (!cur.skipValue()) {
                    return false;
                }
            }

            cur.skipWs();
            if (cur.pos >= cur.len) {
                return false;
            }
            if (cur.data[cur.pos] == '}') {
                ++cur.pos;
                break;
            }
            if (cur.data[cur.pos] != ',') {
                return false;
            }
            ++cur.pos;
        }
    }

    cur.skipWs();
    if (cur.pos != cur.len) {
        return false;
    }
    if (!hasUuid) {
        return false;
    }
    const std::string trimmedUuid = trimAscii(uuidRaw);
    if (!isValidUuid(trimmedUuid)) {
        return false;
    }

    out.valid = true;
    out.uuid = trimmedUuid;
    out.name = nameVal;
    return true;
}

bool parsePresetFromNdefMessage(const uint8_t* ndefData,
                                size_t ndefLen,
                                PresetPayload& out) {
    out = PresetPayload{};
    if (!ndefData || ndefLen < 3) {
        return false;
    }

    size_t pos = 0;
    while (pos < ndefLen) {
        if (pos + 2 > ndefLen) {
            return false;
        }
        const uint8_t flags = ndefData[pos++];
        const bool me = (flags & 0x40) != 0;
        const bool cf = (flags & 0x20) != 0;
        const bool sr = (flags & 0x10) != 0;
        const bool il = (flags & 0x08) != 0;
        const uint8_t tnf = flags & 0x07;

        const uint8_t typeLen = ndefData[pos++];

        uint32_t payloadLen = 0;
        if (sr) {
            if (pos + 1 > ndefLen) return false;
            payloadLen = ndefData[pos++];
        } else {
            if (pos + 4 > ndefLen) return false;
            payloadLen = (static_cast<uint32_t>(ndefData[pos]) << 24) |
                         (static_cast<uint32_t>(ndefData[pos + 1]) << 16) |
                         (static_cast<uint32_t>(ndefData[pos + 2]) << 8) |
                         static_cast<uint32_t>(ndefData[pos + 3]);
            pos += 4;
        }

        uint8_t idLen = 0;
        if (il) {
            if (pos + 1 > ndefLen) return false;
            idLen = ndefData[pos++];
        }

        if (static_cast<size_t>(typeLen) + static_cast<size_t>(idLen) + static_cast<size_t>(payloadLen) >
            ndefLen - pos) {
            return false;
        }

        const uint8_t* typePtr = ndefData + pos;
        pos += typeLen;
        pos += idLen;
        const uint8_t* payloadPtr = ndefData + pos;
        pos += payloadLen;

        if (!cf &&
            tnf == NDEF_TNF_MIME_MEDIA &&
            payloadLen > 0 &&
            equalsIgnoreCaseAscii(typePtr, typeLen, PRESET_MIME_TYPE)) {
            PresetPayload candidate;
            if (parsePresetJson(payloadPtr, payloadLen, candidate)) {
                out = candidate;
                return true;
            }
        }

        if (me) {
            break;
        }
    }
    return false;
}

bool parsePresetFromType2Memory(const uint8_t* userMem,
                                size_t len,
                                PresetPayload& out) {
    out = PresetPayload{};
    size_t ndefOffset = 0;
    size_t ndefLength = 0;
    size_t requiredTotal = 0;
    const TlvPeekStatus st = peekType2NdefBounds(userMem, len, ndefOffset, ndefLength, requiredTotal);
    if (st != TlvPeekStatus::FoundComplete) {
        return false;
    }
    return parsePresetFromNdefMessage(userMem + ndefOffset, ndefLength, out);
}

}  // namespace nfc_preset
