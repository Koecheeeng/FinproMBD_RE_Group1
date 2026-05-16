#define __SFR_OFFSET 0x00
#include "avr/io.h"

;===============================================================================
; init_io.S - I/O Port and Interrupt Initialization
;
; Configures all GPIO directions and initial states, then sets up external
; interrupt INT0 (RFID IRQ on PD2) and disables PCINT2 until needed.
;
; Public subroutines:
;   init_io         - Configure DDRB / DDRC / DDRD and initial port states
;   init_interrupts - INT0 falling-edge + PCINT2 disabled
;===============================================================================

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

;===============================================================================
; init_io
;===============================================================================
init_io:
    ; PORTB: PB0 (green LED), PB1 (red LED), PB2 (SS), PB3 (MOSI), PB5 (SCK) output
    LDI   R16, (1<<LED_GREEN)|(1<<LED_RED)|(1<<RFID_SS)|(1<<SPI_MOSI)|(1<<SPI_SCK)
    OUT   DDRB, R16
    ; SS deselected, LEDs off
    SBI   PORTB, RFID_SS
    CBI   PORTB, LED_GREEN
    CBI   PORTB, LED_RED
    ; PORTC: PC0-PC3 output (keypad cols), PC4-PC5 input (slide switches)
    LDI   R16, (1<<KP_COL1)|(1<<KP_COL2)|(1<<KP_COL3)|(1<<KP_COL4)
    OUT   DDRC, R16
    ; All columns HIGH initially; enable pull-ups on PC4-PC5
    LDI   R16, 0xFF
    OUT   PORTC, R16
    ; PORTD: PD3 output (buzzer); PD2 input (INT0/RFID IRQ); PD4-PD7 input (keypad rows)
    LDI   R16, (1<<BUZZER_PIN)
    OUT   DDRD, R16
    ; Pull-ups on keypad rows; buzzer off
    LDI   R16, (1<<KP_ROW1)|(1<<KP_ROW2)|(1<<KP_ROW3)|(1<<KP_ROW4)
    OUT   PORTD, R16
    CBI   PORTD, BUZZER_PIN
    RET

;===============================================================================
; init_interrupts
;===============================================================================
init_interrupts:
    ; INT0: falling edge (ISC01=1, ISC00=0)
    LDI   R16, (1<<ISC01)
    STS   EICRA, R16
    ; Enable INT0
    LDI   R16, (1<<INT0)
    OUT   EIMSK, R16
    ; PCINT2 disabled until keypad_enable is called
    LDI   R16, 0x00
    STS   PCICR, R16
    RET