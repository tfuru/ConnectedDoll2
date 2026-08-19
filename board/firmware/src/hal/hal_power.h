#ifndef HAL_POWER_H
#define HAL_POWER_H

#include <Arduino.h>
#include <esp_sleep.h>

class HAL_Power {
public:
    static void init();
    static void resetIdleTimer();
    static bool isIdleTimeout(unsigned long timeoutMs);
    static esp_sleep_wakeup_cause_t getWakeupCause();
    static void enterDeepSleep(uint64_t sleepDurationUs);
    static void prepareSleep();

private:
    static unsigned long lastActivityTime;
};

#endif // HAL_POWER_H
