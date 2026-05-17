#define __SFR_OFFSET 0x00
#include "avr/io.h"

.equ NUM_ITEMS, 4
.equ RECORD_SIZE, 6
.equ STAT_AVAILABLE, 0x00
.equ STAT_BORROWED, 0x01
.equ STAT_OVERDUE, 0x02
.equ OVERDUE_LIMIT, 5
.equ LED_RED, 1

.section .text

.global eeprom_read
.global eeprom_write
.global check_overdue_items

; read data from eeprom
eeprom_read:
 SBIC EECR, EEPE ; wait if EEPROM is busy writing
 RJMP eeprom_read

 OUT EEARH, R17 ; set EEPROM address high byte
 OUT EEARL, R16 ; set EEPROM address low byte

 SBI EECR, EERE ; start EEPROM read
 IN R16, EEDR ; get data from EEPROM

 RET

; write data to eeprom
eeprom_write:
    SBIC EECR, EEPE ; wait until EEPROM is free
    RJMP eeprom_write

    OUT EEARH, R17 ; EEPROM address high byte
    OUT EEARL, R16 ; EEPROM address low byte
    OUT EEDR, R18 ; data to write

    CLI ; disable interrupts during write

    SBI EECR, EEMPE ; enable master write
    SBI EECR, EEPE ; start EEPROM write

    SEI ; enable interrupts again

    RET

; check all items for overdue status
check_overdue_items:
    ; save registers
    PUSH R16
    PUSH R17
    PUSH R18
    PUSH R19
    PUSH YL
    PUSH YH
    PUSH ZL
    PUSH ZH

    LDI R18, 0 ; item counter
    LDI R19, 0 ; overdue item counter

overdue_loop:
    ; check if all items already scanned
    CPI R18, NUM_ITEMS
    BREQ overdue_scan_done

    ; calculate EEPROM address
    MOV R16, R18
    LDI R17, RECORD_SIZE
    MUL R16, R17

    MOV YL, R0

    ; read item status
    MOV R16, YL
    LDI R17, 0x00
    RCALL eeprom_read

    ; if item available, skip
    CPI R16, STAT_AVAILABLE
    BREQ overdue_next

    ; blank EEPROM also treated as available
    CPI R16, 0xFF
    BREQ overdue_next

    ; already overdue
    CPI R16, STAT_OVERDUE
    BREQ overdue_already

    ; if not borrowed, ignore
    CPI R16, STAT_BORROWED
    BRNE overdue_next

    ; check borrow time
    MOV R16, YL
    SUBI R16, -2 ; move to timestamp address

    LDI R17, 0x00
    RCALL eeprom_read ; read borrow timestamp

    LDS R17, timer_seconds ; current timer value

    SUB R17, R16 ; elapsed time

    ; if below limit, still okay
    CPI R17, OVERDUE_LIMIT
    BRLO overdue_borrowed_ok

    ; change status to borrow
    PUSH R18

    MOV R16, YL
    LDI R17, 0x00
    LDI R18, STAT_OVERDUE

    RCALL eeprom_write

    POP R18

    ; print overdue message
    LDI ZH, hi8(str_overdue)
    LDI ZL, lo8(str_overdue)

    RCALL usart_print_string
    RCALL feedback_overdue

; item already overdue
overdue_already:
    INC R19

overdue_borrowed_ok:

 ; continue loop
overdue_next:
    INC R18
    RJMP overdue_loop

overdue_scan_done:
    ; if no overdue items
    CPI R19, 0
    BRNE overdue_keep_flag

    LDI R16, 0x00
    STS overdue_flag, R16

    CBI PORTB, LED_RED ; turn off LED

    RJMP overdue_exit

; if overdue items exist
overdue_keep_flag:
    LDI R16, 0x01
    STS overdue_flag, R16

    SBI PORTB, LED_RED ; turn on LED

; restore registers
overdue_exit:
    POP ZH
    POP ZL
    POP YH
    POP YL
    POP R19
    POP R18
    POP R17
    POP R16

    RET