#define __SFR_OFFSET 0x00
#include "avr/io.h"

; --- Hardware Pins ---
.equ LED_GREEN,  0          ; PB0
.equ LED_RED,    1          ; PB1
.equ RFID_SS,    2          ; PB2
.equ SPI_MOSI,   3          ; PB3
.equ SPI_SCK,    5          ; PB5
.equ KP_COL1,    0          ; PC0
.equ KP_COL2,    1          ; PC1
.equ KP_COL3,    2          ; PC2
.equ KP_COL4,    3          ; PC3
.equ KP_ROW1,    4          ; PD4
.equ KP_ROW2,    5          ; PD5
.equ KP_ROW3,    6          ; PD6
.equ KP_ROW4,    7          ; PD7
.equ BUZZER_PIN, 3          ; PD3

.section .text
.global init_io
.global init_interrupts

; --- Initialize GPIO Pins ---
init_io:
    ; Config outputs for LEDs and SPI pins
    LDI   R16, (1<<LED_GREEN)|(1<<LED_RED)|(1<<RFID_SS)|(1<<SPI_MOSI)|(1<<SPI_SCK)
    OUT   DDRB, R16
    ; Turn off LEDs and deselect RFID SS
    SBI   PORTB, RFID_SS
    CBI   PORTB, LED_GREEN
    CBI   PORTB, LED_RED
    ; Config keypad columns as output
    LDI   R16, (1<<KP_COL1)|(1<<KP_COL2)|(1<<KP_COL3)|(1<<KP_COL4)
    OUT   DDRC, R16
    ; Pull up all Port C pins (switches and columns)
    LDI   R16, 0xFF
    OUT   PORTC, R16
    ; Config buzzer pin as output
    LDI   R16, (1<<BUZZER_PIN)
    OUT   DDRD, R16
    ; Pull up keypad rows and turn buzzer off
    LDI   R16, (1<<KP_ROW1)|(1<<KP_ROW2)|(1<<KP_ROW3)|(1<<KP_ROW4)
    OUT   PORTD, R16
    CBI   PORTD, BUZZER_PIN
    RET

; --- Initialize INT0 and Disable PCINT2 ---
init_interrupts:
    ; Set INT0 to trigger on falling edge
    LDI   R16, (1<<ISC01)
    STS   EICRA, R16
    ; Enable INT0 external interrupt
    LDI   R16, (1<<INT0)
    OUT   EIMSK, R16
    ; Disable pin change interrupts for now
    LDI   R16, 0x00
    STS   PCICR, R16
    RET