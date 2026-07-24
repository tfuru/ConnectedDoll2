#ifndef ALARM_MANAGER_H
#define ALARM_MANAGER_H

#include <Arduino.h>
#include <Preferences.h>
#include <RTClib.h>

#define MAX_ALARMS 5

struct AlarmSchedule {
    bool enabled;
    bool isDaily;
    uint16_t year;
    uint8_t month;
    uint8_t day;
    uint8_t hour;
    uint8_t minute;
};

class AlarmManager {
public:
    static void init();
    static bool setAlarm(uint8_t index, uint16_t year, uint8_t month, uint8_t day, uint8_t hour, uint8_t minute, bool isDaily = false);
    static bool deleteAlarm(uint8_t index);
    static String getSchedulesStr();
    static void update(const DateTime& now);

private:
    static AlarmSchedule schedules[MAX_ALARMS];
    static int lastTriggeredDay[MAX_ALARMS];
    static Preferences preferences;
    static void loadSettings();
    static void saveSettings(uint8_t index);
};

#endif // ALARM_MANAGER_H
