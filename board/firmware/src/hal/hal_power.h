#ifndef HAL_POWER_H
#define HAL_POWER_H

#include <Arduino.h>
#include <esp_sleep.h>

class HAL_Power {
public:
    static void init();
    static void resetIdleTimer();
    static bool isIdleTimeout(unsigned long timeoutMs);
    static bool isUsbHostConnected();
    static bool isDeepSleepDisabled();
    static void setDeepSleepDisabled(bool disabled);
    static bool toggleDeepSleepDisabled();
    static bool isSleepInhibited();
    static esp_sleep_wakeup_cause_t getWakeupCause();
    static void enterDeepSleep(uint64_t sleepDurationUs);
    static void prepareSleep();

private:
    static unsigned long lastActivityTime;
    static bool deepSleepDisabled;
};

#endif // HAL_POWER_H
