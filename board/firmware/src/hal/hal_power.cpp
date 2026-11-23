#include "hal_power.h"
#include "hal_io.h"
#include "hal_nfc.h"
#include <driver/gpio.h>
#if defined(ARDUINO_USB_MODE) && ARDUINO_USB_MODE && defined(ARDUINO_USB_CDC_ON_BOOT) && ARDUINO_USB_CDC_ON_BOOT
#include <HWCDC.h>
#endif

unsigned long HAL_Power::lastActivityTime = 0;
bool HAL_Power::deepSleepDisabled = false;

void HAL_Power::init() {
    deepSleepDisabled = false;
    resetIdleTimer();
}

void HAL_Power::resetIdleTimer() {
    lastActivityTime = millis();
}

bool HAL_Power::isIdleTimeout(unsigned long timeoutMs) {
    return (millis() - lastActivityTime >= timeoutMs);
}

bool HAL_Power::isUsbHostConnected() {
#if defined(ARDUINO_USB_MODE) && ARDUINO_USB_MODE && defined(ARDUINO_USB_CDC_ON_BOOT) && ARDUINO_USB_CDC_ON_BOOT
    return HWCDC::isPlugged();
#else
    return false;
#endif
}

bool HAL_Power::isDeepSleepDisabled() {
    return deepSleepDisabled;
}

void HAL_Power::setDeepSleepDisabled(bool disabled) {
    deepSleepDisabled = disabled;
    if (disabled) {
        resetIdleTimer();
    }
}

bool HAL_Power::toggleDeepSleepDisabled() {
    deepSleepDisabled = !deepSleepDisabled;
    resetIdleTimer();
    return deepSleepDisabled;
}

bool HAL_Power::isSleepInhibited() {
    return deepSleepDisabled || isUsbHostConnected();
}

esp_sleep_wakeup_cause_t HAL_Power::getWakeupCause() {
    return esp_sleep_get_wakeup_cause();
}

void HAL_Power::prepareSleep() {
    // NFC RF出力停止・省電力モードへ移行
    HAL_NFC::sleep();

    // LEDを完全に消灯
    HAL_IO::turnOffLED();
    
    // シリアル出力をフラッシュ
    Serial.println("[Power] Preparing to enter Deep Sleep...");
    Serial.flush();
}

void HAL_Power::enterDeepSleep(uint64_t sleepDurationUs) {
    prepareSleep();

    // タクトスイッチ(GPIO2)をLowレベルトリガーで復帰ソースに設定
    // ESP32-C3 では RTC IO (GPIO 0~5) が Deep Sleep の GPIO 復帰に対応
    esp_deep_sleep_enable_gpio_wakeup(1ULL << PIN_TACT_SW, ESP_GPIO_WAKEUP_GPIO_LOW);

    // タイマー復帰の設定
    if (sleepDurationUs > 0) {
        esp_sleep_enable_timer_wakeup(sleepDurationUs);
        Serial.printf("[Power] Entering Deep Sleep for %llu ms (or on button press)\n", sleepDurationUs / 1000ULL);
    } else {
        Serial.println("[Power] Entering Deep Sleep indefinitely until button press");
    }
    Serial.flush();

    esp_deep_sleep_start();
}
