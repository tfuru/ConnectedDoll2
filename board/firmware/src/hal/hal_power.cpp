#include "hal_power.h"
#include "hal_io.h"
#include <driver/gpio.h>

unsigned long HAL_Power::lastActivityTime = 0;

void HAL_Power::init() {
    resetIdleTimer();
}

void HAL_Power::resetIdleTimer() {
    lastActivityTime = millis();
}

bool HAL_Power::isIdleTimeout(unsigned long timeoutMs) {
    return (millis() - lastActivityTime >= timeoutMs);
}

esp_sleep_wakeup_cause_t HAL_Power::getWakeupCause() {
    return esp_sleep_get_wakeup_cause();
}

void HAL_Power::prepareSleep() {
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
