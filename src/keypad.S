#define __SFR_OFFSET 0x00
#include "avr/io.h"

; 4x4 keypad
; Columns = PC0-PC3
; Rows = PD4-PD7

.equ KP_COL1, 0
.equ KP_COL2, 1
.equ KP_COL3, 2
.equ KP_COL4, 3

.equ KP_ROW1, 4
.equ KP_ROW2, 5
.equ KP_ROW3, 6
.equ KP_ROW4, 7


.equ SW_SLOT1, 4
.equ SW_SLOT2, 5

.section .text
.global keypad_enable
.global keypad_disable
.global keypad_scan

; enable keypad interrupt
keypad_enable:
	IN R16, PORTC
	ANDI R16, 0xF0
	ORI R16, 0x30             ; keep pull-ups on PC4-PC5
	OUT PORTC, R16

	; enable PCINT2 for PD4-PD7 (keypad rows)
	LDI R16, (1<<PCIE2)
	STS PCICR, R16
	LDI R16, (1<<PCINT20)|(1<<PCINT21)|(1<<PCINT22)|(1<<PCINT23)
	STS PCMSK2, R16
	RET

; disable keypad interrupt
keypad_disable:
	LDI R16, 0x00
	STS PCICR, R16
	STS PCMSK2, R16
	LDI R16, 0xFF
	OUT PORTC, R16
	RET

; scan keypad by driving one column LOW at a time
keypad_scan:
	RCALL delay_20ms
	LDI R18, 0                ; column index

kp_col_loop:
	CPI R18, 4
	BRNE kp_scan_col
	RJMP kp_no_key

kp_scan_col:
	LDI R16, 0xFF
	MOV R17, R18
	LDI R19, 0x01             ; bit mask for column

kp_shift:
	CPI R17, 0
	BREQ kp_shift_done
	LSL R19
	DEC R17
	RJMP kp_shift

kp_shift_done:
	COM R19                   ; invert mask = selected column LOW
	AND R16, R19
	ORI R16, 0x30             ; keep pull-ups on PC4-PC5
	OUT PORTC, R16

	RCALL delay_20ms

	IN R16, PIND
	ORI R16, 0x0F             ; mask lower nibble

	CPI R16, 0xFF             ; all rows high = no key
	BREQ kp_next_col

	; active low: pressed row bit = 0
	SBRS R16, 4
	RJMP kp_row0
	SBRS R16, 5
	RJMP kp_row1
	SBRS R16, 6
	RJMP kp_row2
	SBRS R16, 7
	RJMP kp_row3
	RJMP kp_next_col

kp_row0:
	LDI R17, 0
	RJMP kp_lookup

kp_row1:
	LDI R17, 1
	RJMP kp_lookup

kp_row2:
	LDI R17, 2
	RJMP kp_lookup

kp_row3:
	LDI R17, 3

; index = row * 4 + column
kp_lookup:
	MOV R16, R17
	LSL R16
	LSL R16
	ADD R16, R18

	LDI ZH, hi8(keymap_table)
	LDI ZL, lo8(keymap_table)
	LDI R19, 0x00
	ADD ZL, R16
	ADC ZH, R19

	LPM R16, Z                ; read ASCII from flash
	STS keypad_key, R16

	; wait for key release
	PUSH R16
	IN R16, PORTC
	ANDI R16, 0xF0
	ORI R16, 0x30
	OUT PORTC, R16

kp_wait_release:
	RCALL delay_20ms
	IN R16, PIND
	ORI R16, 0x0F
	CPI R16, 0xFF
	BRNE kp_wait_release

	RCALL delay_20ms
	POP R16

	LDI R16, 0xFF
	OUT PORTC, R16
	RET

kp_next_col:
	INC R18
	RJMP kp_col_loop

kp_no_key:
	LDI R16, 0x00
	STS keypad_key, R16

	LDI R16, 0xFF
	OUT PORTC, R16
	RET