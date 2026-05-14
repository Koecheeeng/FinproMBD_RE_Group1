#define __SFR_OFFSET 0x00
#include "avr/io.h"

; eeprom.S - EEPROM storage
; 6 bytes per slot: status(1) + userId(1) + timestamp(4)
; status: 0x00=available, 0x01=borrowed, 0x02=overdue

.equ NUM_ITEMS,     4
.equ RECORD_SIZE,   6
.equ STAT_AVAILABLE, 0x00
.equ STAT_BORROWED,  0x01
.equ STAT_OVERDUE,   0x02
.equ OVERDUE_LIMIT,  10
.equ LED_RED,        1

.section .text
.global eeprom_read
.global eeprom_write
.global check_overdue_items

; read one byte from EEPROM
; input: R17:R16 = address, output: R16 = data
eeprom_read:
    SBIC  EECR, EEPE
    RJMP  eeprom_read          ; Wait for previous write to finish
    OUT   EEARH, R17
    OUT   EEARL, R16
    SBI   EECR, EERE
    IN    R16, EEDR
    RET

; write one byte to EEPROM
; input: R17:R16 = address, R18 = data
eeprom_write:
    SBIC  EECR, EEPE
    RJMP  eeprom_write         ; Wait for previous write to finish
    OUT   EEARH, R17
    OUT   EEARL, R16
    OUT   EEDR, R18
    CLI
    SBI   EECR, EEMPE
    SBI   EECR, EEPE
    SEI
    RET

; scan all slots, mark overdue if borrowed > OVERDUE_LIMIT seconds
check_overdue_items:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    PUSH  R19
    PUSH  YL
    PUSH  YH
    PUSH  ZL
    PUSH  ZH
    LDI   R18, 0               ; Slot index
overdue_loop:
    CPI   R18, NUM_ITEMS
    BREQ  overdue_done
    MOV   R16, R18
    LDI   R17, RECORD_SIZE
    MUL   R16, R17
    MOV   YL, R0
    MOV   R16, YL
    LDI   R17, 0x00
    RCALL eeprom_read
    CPI   R16, STAT_BORROWED
    BRNE  overdue_next
    ; check elapsed time since borrow
    MOV   R16, YL
    SUBI  R16, -2
    LDI   R17, 0x00
    RCALL eeprom_read
    MOV   R19, R16
    LDS   R16, timer_seconds
    SUB   R16, R19
    CPI   R16, OVERDUE_LIMIT
    BRLO  overdue_next
    ; mark overdue
    MOV   R16, YL
    LDI   R17, 0x00
    LDI   R18, STAT_OVERDUE
    RCALL eeprom_write
    LDI   R16, 0x01
    STS   overdue_flag, R16
    LDI   ZH, hi8(str_overdue)
    LDI   ZL, lo8(str_overdue)
    RCALL usart_print_string
    RCALL feedback_overdue
overdue_next:
    INC   R18
    RJMP  overdue_loop
overdue_done:
    POP   ZH
    POP   ZL
    POP   YH
    POP   YL
    POP   R19
    POP   R18
    POP   R17
    POP   R16
    RET