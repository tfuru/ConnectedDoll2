#ifndef HAL_RTC_H
#define HAL_RTC_H

#include <Arduino.h>
#include <Wire.h>
#include <RTClib.h>

#define PIN_RTC_SDA  6 // D4
#define PIN_RTC_SCL  7 // D5

class HAL_RTC {
public:
    static bool init();
    static bool setDateTime(uint16_t year, uint8_t month, uint8_t day, uint8_t hour, uint8_t minute, uint8_t second);
    static DateTime getCurrentTime();
    static String getCurrentTimeStr();
    
private:
    static RTC_DS3231 rtc;
    static bool initialized;
};

#endif // HAL_RTC_H
