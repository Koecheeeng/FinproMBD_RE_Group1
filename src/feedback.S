assembly#define __SFR_OFFSET 0x00
#include "avr/io.h"

; --- Hardware Pins ---
.equ LED_GREEN,  0          ; PB0
.equ LED_RED,    1          ; PB1
.equ BUZZER_PIN, 3          ; PD3

.section .text
.global feedback_auth_ok
.global feedback_borrow_ok
.global feedback_return_ok
.global feedback_invalid_rfid
.global feedback_item_not_found
.global feedback_switch_fail
.global feedback_overdue

; --- Auth OK: 2 green blinks + 2 pings ---
feedback_auth_ok:
    SBI   PORTB, LED_GREEN
    SBI   PORTD, BUZZER_PIN
    RCALL delay_20ms
    RCALL delay_20ms
    RCALL delay_20ms
    CBI   PORTB, LED_GREEN
    CBI   PORTD, BUZZER_PIN
    RCALL delay_20ms
    RCALL delay_20ms
    SBI   PORTB, LED_GREEN
    SBI   PORTD, BUZZER_PIN
    RCALL delay_20ms
    RCALL delay_20ms
    RCALL delay_20ms
    CBI   PORTB, LED_GREEN
    CBI   PORTD, BUZZER_PIN
    RET

; --- Borrow OK: 2 green blinks + 2 pings ---
feedback_borrow_ok:
    SBI   PORTB, LED_GREEN
    SBI   PORTD, BUZZER_PIN
    RCALL delay_20ms
    RCALL delay_20ms
    RCALL delay_20ms
    CBI   PORTB, LED_GREEN
    CBI   PORTD, BUZZER_PIN
    RCALL delay_20ms
    RCALL delay_20ms
    SBI   PORTB, LED_GREEN
    SBI   PORTD, BUZZER_PIN
    RCALL delay_20ms
    RCALL delay_20ms
    RCALL delay_20ms
    CBI   PORTB, LED_GREEN
    CBI   PORTD, BUZZER_PIN
    RET

; --- Return OK: 1 long green blink + 1 long pings ---
feedback_return_ok:
    SBI   PORTB, LED_GREEN
    SBI   PORTD, BUZZER_PIN
    RCALL delay_500ms
    CBI   PORTB, LED_GREEN
    CBI   PORTD, BUZZER_PIN
    RET

; --- Invalid RFID: 1 short red blink + 1 short pings ---
feedback_invalid_rfid:
    SBI   PORTB, LED_RED
    SBI   PORTD, BUZZER_PIN
    RCALL delay_20ms
    RCALL delay_20ms
    RCALL delay_20ms
    CBI   PORTB, LED_RED
    CBI   PORTD, BUZZER_PIN
    RET

; --- Item Not Found: 2 short red blinks + 2 short pings ---
feedback_item_not_found:
    SBI   PORTB, LED_RED
    SBI   PORTD, BUZZER_PIN
    RCALL delay_20ms
    RCALL delay_20ms
    RCALL delay_20ms
    CBI   PORTB, LED_RED
    CBI   PORTD, BUZZER_PIN
    RCALL delay_20ms
    RCALL delay_20ms
    SBI   PORTB, LED_RED
    SBI   PORTD, BUZZER_PIN
    RCALL delay_20ms
    RCALL delay_20ms
    RCALL delay_20ms
    CBI   PORTB, LED_RED
    CBI   PORTD, BUZZER_PIN
    RET

; --- Sensor Fail: 3 rapid red blinks + 3 short pings ---
feedback_switch_fail:
    LDI   R16, 3
fb_switch_loop:
    SBI   PORTB, LED_RED
    SBI   PORTD, BUZZER_PIN
    RCALL delay_20ms
    RCALL delay_20ms
    CBI   PORTB, LED_RED
    CBI   PORTD, BUZZER_PIN
    RCALL delay_20ms
    DEC   R16
    BRNE  fb_switch_loop
    RET

; --- Overdue: 3 slow red blinks + 3 long pings (it leaves the LED ON) ---
feedback_overdue:
    LDI   R16, 3
fb_overdue_loop:
    SBI   PORTB, LED_RED
    SBI   PORTD, BUZZER_PIN
    RCALL delay_500ms
    CBI   PORTB, LED_RED
    CBI   PORTD, BUZZER_PIN
    RCALL delay_500ms
    DEC   R16
    BRNE  fb_overdue_loop
    SBI   PORTB, LED_RED
    RET