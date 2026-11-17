#pragma once

// Fixture sintetica: testes nao leem a configuracao/credenciais locais.
#include "../../include/config.example.h"

#ifdef TEST_FULL_HARDWARE
#undef DOOR_ENABLED
#define DOOR_ENABLED 1
#undef FEEDBACK_BUZZER_ENABLED
#define FEEDBACK_BUZZER_ENABLED 1
#undef DOOR_SERVO_POSITIONAL
#define DOOR_SERVO_POSITIONAL 1
#undef DOOR_SERVO_OPEN
#define DOOR_SERVO_OPEN 135
#undef DOOR_SERVO_CLOSE
#define DOOR_SERVO_CLOSE 45
#undef LCD_ENABLED
#define LCD_ENABLED 1
#undef TERMINAL_DISPLAY_OLED
#define TERMINAL_DISPLAY_OLED 1
#endif
