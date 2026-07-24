#include "alarm_manager.h"
#include "audio_player.h"
#include "../hal/hal_sd.h"

AlarmSchedule AlarmManager::schedules[MAX_ALARMS];
int AlarmManager::lastTriggeredDay[MAX_ALARMS];
Preferences AlarmManager::preferences;

void AlarmManager::init() {
    for (int i = 0; i < MAX_ALARMS; i++) {
        lastTriggeredDay[i] = -1;
    }
    loadSettings();
}

void AlarmManager::loadSettings() {
    preferences.begin("alarm_conf", false);
    
    for (uint8_t i = 0; i < MAX_ALARMS; i++) {
        char key_en[8], key_da[8], key_yr[8], key_mo[8], key_dy[8], key_hr[8], key_mn[8];
        snprintf(key_en, sizeof(key_en), "en_%d", i);
        snprintf(key_da, sizeof(key_da), "da_%d", i);
        snprintf(key_yr, sizeof(key_yr), "yr_%d", i);
        snprintf(key_mo, sizeof(key_mo), "mo_%d", i);
        snprintf(key_dy, sizeof(key_dy), "dy_%d", i);
        snprintf(key_hr, sizeof(key_hr), "hr_%d", i);
        snprintf(key_mn, sizeof(key_mn), "mn_%d", i);

        schedules[i].enabled = preferences.getBool(key_en, false);
        schedules[i].isDaily = preferences.getBool(key_da, false);
        schedules[i].year = preferences.getUShort(key_yr, 0);
        schedules[i].month = preferences.getUChar(key_mo, 0);
        schedules[i].day = preferences.getUChar(key_dy, 0);
        schedules[i].hour = preferences.getUChar(key_hr, 0);
        schedules[i].minute = preferences.getUChar(key_mn, 0);
    }
    preferences.end();
    Serial.println("Alarm settings loaded from Preferences.");
}

void AlarmManager::saveSettings(uint8_t index) {
    if (index >= MAX_ALARMS) return;
    
    preferences.begin("alarm_conf", false);
    
    char key_en[8], key_da[8], key_yr[8], key_mo[8], key_dy[8], key_hr[8], key_mn[8];
    snprintf(key_en, sizeof(key_en), "en_%d", index);
    snprintf(key_da, sizeof(key_da), "da_%d", index);
    snprintf(key_yr, sizeof(key_yr), "yr_%d", index);
    snprintf(key_mo, sizeof(key_mo), "mo_%d", index);
    snprintf(key_dy, sizeof(key_dy), "dy_%d", index);
    snprintf(key_hr, sizeof(key_hr), "hr_%d", index);
    snprintf(key_mn, sizeof(key_mn), "mn_%d", index);

    preferences.putBool(key_en, schedules[index].enabled);
    preferences.putBool(key_da, schedules[index].isDaily);
    preferences.putUShort(key_yr, schedules[index].year);
    preferences.putUChar(key_mo, schedules[index].month);
    preferences.putUChar(key_dy, schedules[index].day);
    preferences.putUChar(key_hr, schedules[index].hour);
    preferences.putUChar(key_mn, schedules[index].minute);
    
    preferences.end();
    Serial.printf("Alarm slot %d configuration updated in NVS.\n", index);
}

bool AlarmManager::setAlarm(uint8_t index, uint16_t year, uint8_t month, uint8_t day, uint8_t hour, uint8_t minute, bool isDaily) {
    if (index >= MAX_ALARMS) return false;
    
    schedules[index].enabled = true;
    schedules[index].isDaily = isDaily;
    schedules[index].year = year;
    schedules[index].month = month;
    schedules[index].day = day;
    schedules[index].hour = hour;
    schedules[index].minute = minute;
    
    lastTriggeredDay[index] = -1; // ロックを解除して即時反応可能にする
    
    saveSettings(index);
    return true;
}

bool AlarmManager::deleteAlarm(uint8_t index) {
    if (index >= MAX_ALARMS) return false;
    
    schedules[index].enabled = false;
    saveSettings(index);
    return true;
}

String AlarmManager::getSchedulesStr() {
    // フォーマット: "0:1,2026-07-25 15:30;1:1,DAILY 18:00;..."
    String res = "";
    for (uint8_t i = 0; i < MAX_ALARMS; i++) {
        res += String(i) + ":";
        if (schedules[i].enabled) {
            char buf[48];
            if (schedules[i].isDaily) {
                snprintf(buf, sizeof(buf), "1,DAILY %02d:%02d",
                         schedules[i].hour, schedules[i].minute);
            } else {
                snprintf(buf, sizeof(buf), "1,%04d-%02d-%02d %02d:%02d",
                         schedules[i].year, schedules[i].month, schedules[i].day,
                         schedules[i].hour, schedules[i].minute);
            }
            res += String(buf);
        } else {
            res += "0";
        }
        if (i < MAX_ALARMS - 1) {
            res += ";";
        }
    }
    return res;
}

void AlarmManager::update(const DateTime& now) {
    for (uint8_t i = 0; i < MAX_ALARMS; i++) {
        if (!schedules[i].enabled) continue;
        
        bool isTriggered = false;

        if (schedules[i].isDaily) {
            // 毎日アラーム: 時・分だけをチェック
            if (now.hour() == schedules[i].hour &&
                now.minute() == schedules[i].minute) {
                
                if (lastTriggeredDay[i] != now.day()) {
                    isTriggered = true;
                    lastTriggeredDay[i] = now.day(); // ロック
                }
            }
        } else {
            // 1回限りアラーム: 年・月・日・時・分を全てチェック
            if (now.year() == schedules[i].year &&
                now.month() == schedules[i].month &&
                now.day() == schedules[i].day &&
                now.hour() == schedules[i].hour &&
                now.minute() == schedules[i].minute) {
                
                isTriggered = true;
            }
        }

        if (isTriggered) {
            Serial.printf("[Alarm] Slot %d triggered!\n", i);
            
            // スロットに対応した個別音声ファイルパス (WAV優先、MP3フォールバック)
            char path_wav[32];
            char path_mp3[32];
            snprintf(path_wav, sizeof(path_wav), "/alarm%d.wav", i);
            snprintf(path_mp3, sizeof(path_mp3), "/alarm%d.mp3", i);
            
            if (HAL_SD::fileExists(path_wav)) {
                AudioPlayer::playMP3(path_wav);
            } else if (HAL_SD::fileExists(path_mp3)) {
                AudioPlayer::playMP3(path_mp3);
            } else {
                Serial.printf("[Alarm Error] File not found: %s / %s\n", path_wav, path_mp3);
            }
            
            // 1回限りアラームの場合のみ、実行後に無効化してセーブ
            if (!schedules[i].isDaily) {
                schedules[i].enabled = false;
                saveSettings(i);
            }
        }
    }
}
