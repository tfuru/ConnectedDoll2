#include "hal_rtc.h"

RTC_DS3231 HAL_RTC::rtc;
bool HAL_RTC::initialized = false;

bool HAL_RTC::init() {
    // 指定したピンで I2C バスを初期化
    if (!Wire.begin(PIN_RTC_SDA, PIN_RTC_SCL)) {
        Serial.println("Wire initialization failed");
        return false;
    }
    
    // Wire インスタンスを渡して RTC を初期化
    if (!rtc.begin(&Wire)) {
        Serial.println("Couldn't find RTC DS3231");
        initialized = false;
        return false;
    }
    
    if (rtc.lostPower()) {
        Serial.println("RTC lost power, setting default build time!");
        rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
    }
    
    Serial.println("RTC DS3231 Initialized successfully");
    initialized = true;
    return true;
}

bool HAL_RTC::setDateTime(uint16_t year, uint8_t month, uint8_t day, uint8_t hour, uint8_t minute, uint8_t second) {
    if (!initialized) return false;
    rtc.adjust(DateTime(year, month, day, hour, minute, second));
    return true;
}

DateTime HAL_RTC::getCurrentTime() {
    if (!initialized) {
        return DateTime((uint32_t)0);
    }
    return rtc.now();
}

String HAL_RTC::getCurrentTimeStr() {
    if (!initialized) {
        return String("RTC_UNINIT");
    }
    DateTime now = rtc.now();
    char buf[32];
    snprintf(buf, sizeof(buf), "%04d-%02d-%02d %02d:%02d:%02d", 
             now.year(), now.month(), now.day(), 
             now.hour(), now.minute(), now.second());
    return String(buf);
}
