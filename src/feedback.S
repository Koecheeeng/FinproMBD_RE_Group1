#define __SFR_OFFSET 0x00
#include "avr/io.h"

;===============================================================================
; feedback.S - LED & Buzzer Feedback Module
;
; Provides audio-visual feedback patterns for each system event.
;
; Hardware:
;   PB0 (LED_GREEN) - Green LED
;   PB1 (LED_RED)   - Red LED
;   PD3 (BUZZER)    - Active buzzer (high = on)
;
; Event -> Pattern mapping (per report):
;   Auth OK / Borrow OK : Green LED 2 short blinks + 2 short beeps
;   Return OK           : Green LED 1 long blink  + 1 long beep
;   Invalid RFID        : Red LED   1 short blink  + 1 short beep
;   Item not found      : Red LED   2 short blinks + 2 short beeps
;   Switch/sensor fail  : Red LED   3 rapid blinks + 3 short beeps
;
; Public subroutines:
;   feedback_auth_ok
;   feedback_borrow_ok
;   feedback_return_ok
;   feedback_invalid_rfid
;   feedback_item_not_found
;   feedback_switch_fail
;===============================================================================

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

;===============================================================================
; feedback_auth_ok - 2 short green blinks + 2 short beeps
;===============================================================================
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

;===============================================================================
; feedback_borrow_ok - 2 short green blinks + 2 short beeps
;===============================================================================
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

;===============================================================================
; feedback_return_ok - 1 long green blink + 1 long beep
;===============================================================================
feedback_return_ok:
    SBI   PORTB, LED_GREEN
    SBI   PORTD, BUZZER_PIN
    RCALL delay_500ms
    CBI   PORTB, LED_GREEN
    CBI   PORTD, BUZZER_PIN
    RET

;===============================================================================
; feedback_invalid_rfid - 1 short red blink + 1 short beep
;===============================================================================
feedback_invalid_rfid:
    SBI   PORTB, LED_RED
    SBI   PORTD, BUZZER_PIN
    RCALL delay_20ms
    RCALL delay_20ms
    RCALL delay_20ms
    CBI   PORTB, LED_RED
    CBI   PORTD, BUZZER_PIN
    RET

;===============================================================================
; feedback_item_not_found - 2 short red blinks + 2 short beeps
;===============================================================================
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

;===============================================================================
; feedback_switch_fail - 3 rapid red blinks + 3 short beeps
;===============================================================================
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

;===============================================================================
; feedback_overdue - Slow red LED blink + long buzzer beep, repeated 3 times
; Called from check_overdue_items in eeprom.S when an overdue item is detected.
; Red LED stays ON between calls (set by main_loop overdue indicator).
;===============================================================================
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
    ; Leave red LED on as persistent overdue indicator
    SBI   PORTB, LED_RED
    RET
