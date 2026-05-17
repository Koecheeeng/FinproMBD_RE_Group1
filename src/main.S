#define __SFR_OFFSET 0x00
#include "avr/io.h"

; Pin definitions
.equ LED_GREEN, 0 ; PB0 (D8)
.equ LED_RED, 1 ; PB1 (D9)
.equ RFID_SS, 2 ; PB2 (D10)
.equ SPI_MOSI, 3 ; PB3 (D11)
.equ SPI_MISO, 4 ; PB4 (D12)
.equ SPI_SCK, 5 ; PB5 (D13)
.equ RFID_RST, 2 ; PD2
.equ BUZZER_PIN, 3 ; PD3 (D3)

; Keypad columns on PORTC (output)
.equ KP_COL1, 0 ; PC0
.equ KP_COL2, 1 ; PC1
.equ KP_COL3, 2 ; PC2
.equ KP_COL4, 3 ; PC3

; Keypad rows on PORTD (input with pull-up)
.equ KP_ROW1, 4 ; PD4
.equ KP_ROW2, 5 ; PD5
.equ KP_ROW3, 6 ; PD6
.equ KP_ROW4, 7 ; PD7

; Switches on PORTC (input)
.equ SW_SLOT1, 4 ; PC4 (A4)
.equ SW_SLOT2, 5 ; PC5 (A5)

; USART
.equ BAUD_UBRR, 103

; states used in the state machine
.equ ST_IDLE, 0 ; waiting for RFID card
.equ ST_AUTH, 1 ; checking user card
.equ ST_ITEM_ENTRY, 2   ; entering item id
.equ ST_ITEM_VALID, 3   ; validating item
.equ ST_BORROW_VERIFY, 4    ; verify item removal
.equ ST_RETURN_VERIFY, 5    ; verify item return
.equ ST_COMPLETED, 6    ; transaction success
.equ ST_CANCELLED, 7    ; cancelled by user/timeout
.equ ST_FAILED, 8   ; error

; EEPROM
.equ NUM_ITEMS, 4   ; total number of items
.equ RECORD_SIZE, 6 ; bytes used for each item record (status(1) + userId(1) + timestamp(4))
.equ EEPROM_BASE, 0x00 

; item status values
.equ STAT_AVAILABLE, 0x00
.equ STAT_BORROWED, 0x01
.equ STAT_OVERDUE, 0x02

; session timeout (seconds)
.equ SESSION_TIMEOUT, 30

; overdue threshold (seconds)
.equ OVERDUE_LIMIT, 5

; MFRC522 Registers
.equ CommandReg, 0x01
.equ ComIrqReg, 0x04
.equ ErrorReg, 0x06
.equ FIFODataReg, 0x09
.equ FIFOLevelReg, 0x0A
.equ BitFramingReg, 0x0D
.equ CollReg, 0x0E
.equ ModeReg, 0x11
.equ TxControlReg, 0x14
.equ TxASKReg, 0x15
.equ TModeReg, 0x2A
.equ TPrescalerReg, 0x2B
.equ TReloadRegH, 0x2C
.equ TReloadRegL, 0x2D

; MFRC522 Commands
.equ PCD_Idle, 0x00
.equ PCD_Transceive, 0x0C
.equ PCD_SoftReset, 0x0F

; RFID card Commands
.equ PICC_REQA, 0x26
.equ PICC_SEL_CL1, 0x93
.equ PICC_HALT, 0x50

; Number of registered users in lookup table
.equ NUM_USERS, 3

; uninitialized variables in RAM
.section  .bss
card_uid: .space 4  ; last read card UID (4 bytes)
rfid_irq_flag: .space 1 ; set by INT0 ISR when card detected

keypad_key: .space 1    ; last detected keypad key (ASCII)
keypad_flag: .space 1   ; set by PCINT ISR when key pressed

digit_buffer: .space 4  ; buffer for keypad digit entry
digit_count: .space 1   ; Number of digits entered

timer_seconds: .space 4 ; 4=byte seconds counter (updated by Timer1 ISR)

overdue_flag: .space 1  ; indicates overdue item exists
session_active: .space 1    ; Whether a transaction session is active


.section .text
.global main

; ISR vectors
.global __vector_1  ; INT0 ISR (RFID IRQ)
.global __vector_11 ; Timer1 COMPA ISR
.global __vector_5  ; PCINT2 ISR (Keypad rows on PORTD)

; Export SRAM variables so other units can reference them
.global card_uid
.global rfid_irq_flag
.global keypad_key
.global keypad_flag
.global digit_buffer
.global digit_count
.global timer_seconds
.global overdue_flag
.global session_active

; Export flash data so other units can reference them
.global user_table
.global keymap_table
.global str_overdue
.global str_startup
.global str_ready
.global str_mfrc_ver
.global str_card_scan
.global str_uid
.global str_auth_ok
.global str_auth_fail
.global str_enter_item
.global str_item_id
.global str_item_invalid
.global str_borrow_start
.global str_return_start
.global str_borrow_ok
.global str_return_ok
.global str_by_user
.global str_timeout
.global str_completed
.global str_cancelled
.global str_failed

main:
    ; Disable interrupts during init
    CLI

    ; Initialize all hardware modules
    RCALL init_io
    RCALL init_usart
    RCALL init_spi
    RCALL init_timer1
    RCALL init_interrupts

    ; setup RFID reset pin
    SBI DDRD, RFID_RST
    SBI PORTD, RFID_RST

    ; print startup message
    LDI ZH, hi8(str_startup)
    LDI ZL, lo8(str_startup)
    RCALL usart_print_string
    
    ; initialize RFID module
    RCALL init_mfrc522

    ; clear SRAM variables
    LDI R16, 0x00
    STS rfid_irq_flag, R16
    STS keypad_flag, R16
    STS digit_count, R16
    STS overdue_flag, R16
    STS session_active, R16
    STS timer_seconds, R16

    ; clear timer bytes
    STS timer_seconds+1, R16
    STS timer_seconds+2, R16
    STS timer_seconds+3, R16

    ; initialize state machine registers
    LDI R20, ST_IDLE  ; current state = Idle
    LDI R21, 0x00 ; no authenticated user
    LDI R22, 0x00 ; no selected item
    LDI R23, 0x00 ; transaction type
    LDI R24, 0x00 ; session timeout
    LDI R25, 0x00 ; switch result

    ; Print ready message
    LDI ZH, hi8(str_ready)
    LDI ZL, lo8(str_ready)
    RCALL usart_print_string
    
    ; enable global interrupts
    SEI

main_loop:
    ; check for overdue items periodically
    RCALL check_overdue_items

overdue_ind_done:
    ; check current state
    CPI R20, ST_IDLE
    BREQ state_idle

    CPI R20, ST_AUTH
    BRNE check_item_entry
    RJMP state_auth

check_item_entry:
    CPI R20, ST_ITEM_ENTRY
    BRNE check_item_valid
    RJMP state_item_entry

check_item_valid:
    CPI R20, ST_ITEM_VALID
    BRNE check_borrow_verify
    RJMP state_item_valid

check_borrow_verify:
    CPI R20, ST_BORROW_VERIFY
    BRNE check_return_verify
    RJMP state_borrow_verify

check_return_verify:
    CPI R20, ST_RETURN_VERIFY
    BRNE check_completed
    RJMP state_return_verify

check_completed:
    CPI R20, ST_COMPLETED
    BRNE check_cancelled
    RJMP state_completed

check_cancelled:
    CPI R20, ST_CANCELLED
    BRNE check_failed
    RJMP state_cancelled

check_failed:
    CPI R20, ST_FAILED
    BRNE invalid_state
    RJMP state_failed

invalid_state:
    RJMP main_loop

state_idle:
    ; check if RFID interrupt flag is set
    LDS R16, rfid_irq_flag
    CPI R16, 0x01
    BREQ idle_card_detected

    ; poll RFID reader manually
    RCALL mfrc522_request
    CPI R16, 0x00
    BRNE idle_no_card

idle_card_detected:
    ; clear RFID interrupt flag
    LDI R16, 0x00
    STS rfid_irq_flag, R16

    ; move to authentication state
    LDI R20, ST_AUTH
    RJMP main_loop

idle_no_card:
    ; small delay before next poll
    RCALL delay_20ms
    RJMP main_loop

; authentication state
state_auth:
    ; set retry counter
    LDI R19, 3

auth_retry:
    ; request RFID card
    RCALL mfrc522_request
    CPI R16, 0x00
    BRNE auth_retry_next

    ; perform anticollision to read UID
    RCALL mfrc522_anticoll
    CPI R16, 0x00
    BREQ auth_uid_ok

auth_retry_next:
    ; decrease retry counter
    DEC R19
    BREQ auth_fail

    ; wait before retrying
    RCALL delay_20ms
    RJMP auth_retry

auth_uid_ok:
    ; print UID label
    LDI ZH, hi8(str_uid)
    LDI ZL, lo8(str_uid)
    RCALL usart_print_string

    ; print card UID
    RCALL usart_print_uid

    ; validate UID against lookup table
    RCALL validate_uid
    CPI R16, 0xFF
    BREQ auth_fail

    ; store authenticated user ID
    MOV R21, R16

    ; print authentication success message
    LDI ZH, hi8(str_auth_ok)
    LDI ZL, lo8(str_auth_ok)
    RCALL usart_print_string

    ; print user ID
    MOV R16, R21
    RCALL usart_print_decimal
    RCALL usart_newline

    ; enable keypad input
    RCALL keypad_enable

    ; reset session timeout
    LDI R24, SESSION_TIMEOUT

    ; mark session as active
    LDI R16, 0x01
    STS session_active, R16

    ; clear digit counter
    LDI R16, 0x00
    STS digit_count, R16

    ; play success feedback
    RCALL feedback_auth_ok

    ; switch to item entry state
    LDI R20, ST_ITEM_ENTRY

    ; prompt user for item ID
    LDI ZH, hi8(str_enter_item)
    LDI ZL, lo8(str_enter_item)
    RCALL usart_print_string

    RJMP main_loop

auth_fail:
    ; move to failed state
    LDI R20, ST_FAILED

    ; print authentication failure message
    LDI ZH, hi8(str_auth_fail)
    LDI ZL, lo8(str_auth_fail)
    RCALL usart_print_string

    ; play invalid RFID feedback
    RCALL feedback_invalid_rfid
    RJMP main_loop

; item entry state
state_item_entry:
    ; check if session timed out
    CPI R24, 0x00
    BREQ item_entry_timeout

    ; check keypad interrupt flag
    LDS R16, keypad_flag
    CPI R16, 0x01
    BREQ item_entry_do_scan

    ; scan keypad manually
    RCALL keypad_scan

    ; read detected key
    LDS R16, keypad_key
    CPI R16, 0x00
    BREQ state_item_entry_wait
    RJMP item_entry_process_key

item_entry_do_scan:
    ; clear keypad interrupt flag
    LDI R16, 0x00
    STS keypad_flag, R16

    ; scan keypad
    RCALL keypad_scan

    ; read keypad result
    LDS R16, keypad_key
    CPI R16, 0x00
    BREQ state_item_entry_wait

item_entry_process_key:
    ; check if user pressed confirm key
    CPI R16, '#'
    BREQ item_entry_confirm

    ; check if user pressed cancel key
    CPI R16, '*'
    BREQ item_entry_cancel

    ; load current digit count
    LDS R17, digit_count

    ; limit input to 4 digits
    CPI R17, 4
    BRGE state_item_entry_wait

    ; point X register to digit buffer
    LDI XL, lo8(digit_buffer)
    LDI XH, hi8(digit_buffer)

    ; offset pointer using digit count
    ADD XL, R17
    LDI R18, 0x00
    ADC XH, R18

    ; store entered digit
    ST X, R16

    ; increment digit count
    INC R17
    STS digit_count, R17

    ; print character to terminal
    RCALL usart_transmit

state_item_entry_wait:
    ; debounce delay
    RCALL delay_20ms
    RCALL delay_20ms
    RCALL delay_20ms
    RJMP main_loop

item_entry_confirm:
    ; convert entered digits into number
    RCALL parse_item_id

    ; store item ID
    MOV R22, R16

    ; disable keypad
    RCALL keypad_disable

    ; print item ID
    RCALL usart_newline
    LDI ZH, hi8(str_item_id)
    LDI ZL, lo8(str_item_id)
    RCALL usart_print_string

    MOV R16, R22
    RCALL usart_print_decimal
    RCALL usart_newline

    ; move to item validation state
    LDI R20, ST_ITEM_VALID
    RJMP main_loop

item_entry_cancel:
    ; disable keypad and cancel session
    RCALL keypad_disable
    LDI R20, ST_CANCELLED
    RJMP main_loop

item_entry_timeout:
    ; disable keypad
    RCALL keypad_disable

    ; cancel session
    LDI R20, ST_CANCELLED

    ; print timeout message
    LDI ZH, hi8(str_timeout)
    LDI ZL, lo8(str_timeout)
    RCALL usart_print_string
    RJMP main_loop

; item validation state
state_item_valid:
    ; check if item ID is valid
    CPI R22, NUM_ITEMS
    BRGE item_valid_invalid

    ; calculate EEPROM address
    MOV R16, R22
    LDI R17, RECORD_SIZE
    MUL R16, R17

    ; load EEPROM offset
    MOV R16, R0
    LDI R17, 0x00

    ; read item status
    RCALL eeprom_read

    ; check if item is available
    CPI R16, STAT_AVAILABLE
    BREQ item_valid_borrow

    ; empty EEPROM treated as available
    CPI R16, 0xFF
    BREQ item_valid_borrow

    ; check borrowed state
    CPI R16, STAT_BORROWED
    BREQ item_valid_return

    ; check overdue state
    CPI R16, STAT_OVERDUE
    BREQ item_valid_return

    RJMP item_valid_borrow

item_valid_borrow:
    ; mark transaction as borrow
    LDI R23, 0x00

    ; switch to borrow verification state
    LDI R20, ST_BORROW_VERIFY

    ; prompt user to remove item
    LDI ZH, hi8(str_borrow_start)
    LDI ZL, lo8(str_borrow_start)
    RCALL usart_print_string

    ; reset timeout counter
    LDI R24, SESSION_TIMEOUT
    RJMP main_loop

item_valid_return:
    ; mark transaction as return
    LDI R23, 0x01

    ; switch to return verification state
    LDI R20, ST_RETURN_VERIFY

    ; prompt user to place item
    LDI ZH, hi8(str_return_start)
    LDI ZL, lo8(str_return_start)
    RCALL usart_print_string

    ; reset timeout counter
    LDI R24, SESSION_TIMEOUT
    RJMP main_loop

item_valid_invalid:
    ; switch to failed state
    LDI R20, ST_FAILED

    ; print invalid item message
    LDI ZH, hi8(str_item_invalid)
    LDI ZL, lo8(str_item_invalid)
    RCALL usart_print_string

    ; play feedback
    RCALL feedback_item_not_found
    RJMP main_loop

; borrow verification state
state_borrow_verify:
    ; check if session timed out
    CPI R24, 0x00
    BREQ borrow_verify_timeout

    ; read slot switch state
    ; R25 = 0 means item removed
    ; R25 = 1 means item present
    RCALL read_slot_switch

    ; verify that item was removed
    CPI R25, 0x00
    BREQ borrow_verify_ok

    ; wait before checking again
    RCALL delay_20ms
    RJMP main_loop

borrow_verify_ok:
    ; calculate EEPROM base address
    MOV R16, R22
    LDI R17, RECORD_SIZE
    MUL R16, R17

    ; store EEPROM offset in YL
    MOV YL, R0

    ; write status as borrowed
    MOV R16, YL
    LDI R17, 0x00
    LDI R18, STAT_BORROWED
    RCALL eeprom_write

    ; write borrower user ID
    MOV R16, YL
    SUBI R16, -1
    LDI R17, 0x00
    MOV R18, R21
    RCALL eeprom_write

    ; write timestamp byte 0
    MOV R16, YL
    SUBI R16, -2
    LDI R17, 0x00
    LDS R18, timer_seconds
    RCALL eeprom_write

    ; write timestamp byte 1
    MOV R16, YL
    SUBI R16, -3
    LDI R17, 0x00
    LDS R18, timer_seconds+1
    RCALL eeprom_write

    ; write timestamp byte 2
    MOV R16, YL
    SUBI R16, -4
    LDI R17, 0x00
    LDS R18, timer_seconds+2
    RCALL eeprom_write

    ; write timestamp byte 3
    MOV R16, YL
    SUBI R16, -5
    LDI R17, 0x00
    LDS R18, timer_seconds+3
    RCALL eeprom_write

    ; move to completed state
    LDI R20, ST_COMPLETED

    ; print borrow success message
    LDI ZH, hi8(str_borrow_ok)
    LDI ZL, lo8(str_borrow_ok)
    RCALL usart_print_string

    ; print item ID
    MOV R16, R22
    RCALL usart_print_decimal

    ; print user label
    LDI ZH, hi8(str_by_user)
    LDI ZL, lo8(str_by_user)
    RCALL usart_print_string

    ; print user ID
    MOV R16, R21
    RCALL usart_print_decimal
    RCALL usart_newline

    ; play success feedback
    RCALL feedback_borrow_ok
    RJMP main_loop

borrow_verify_timeout:
    ; cancel transaction due to timeout
    LDI R20, ST_CANCELLED

    ; print timeout message
    LDI ZH, hi8(str_timeout)
    LDI ZL, lo8(str_timeout)
    RCALL usart_print_string
    RJMP main_loop

; return verification state
state_return_verify:
    ; check if session timed out
    CPI R24, 0x00
    BREQ return_verify_timeout

    ; read slot switch state
    RCALL read_slot_switch

    ; verify that item was returned
    CPI R25, 0x01
    BREQ return_verify_ok

    ; wait before checking again
    RCALL delay_20ms
    RJMP main_loop

return_verify_ok:
    ; calculate EEPROM base address
    MOV R16, R22
    LDI R17, RECORD_SIZE
    MUL R16, R17

    ; store EEPROM offset in YL
    MOV YL, R0

    ; write status as available
    MOV R16, YL
    LDI R17, 0x00
    LDI R18, STAT_AVAILABLE
    RCALL eeprom_write

    ; clear user ID
    MOV R16, YL
    SUBI R16, -1
    LDI R17, 0x00
    LDI R18, 0x00
    RCALL eeprom_write

    ; clear timestamp byte 0
    MOV R16, YL
    SUBI R16, -2
    LDI R17, 0x00
    LDI R18, 0x00
    RCALL eeprom_write

    ; clear timestamp byte 1
    MOV R16, YL
    SUBI R16, -3
    LDI R17, 0x00
    LDI R18, 0x00
    RCALL eeprom_write

    ; clear timestamp byte 2
    MOV R16, YL
    SUBI R16, -4
    LDI R17, 0x00
    LDI R18, 0x00
    RCALL eeprom_write

    ; clear timestamp byte 3
    MOV R16, YL
    SUBI R16, -5
    LDI R17, 0x00
    LDI R18, 0x00
    RCALL eeprom_write

    ; move to completed state
    LDI R20, ST_COMPLETED

    ; print return success message
    LDI ZH, hi8(str_return_ok)
    LDI ZL, lo8(str_return_ok)
    RCALL usart_print_string

    ; print item ID
    MOV R16, R22
    RCALL usart_print_decimal

    ; print user label
    LDI ZH, hi8(str_by_user)
    LDI ZL, lo8(str_by_user)
    RCALL usart_print_string

    ; print user ID
    MOV R16, R21
    RCALL usart_print_decimal
    RCALL usart_newline

    ; play success feedback
    RCALL feedback_return_ok
    RJMP main_loop

return_verify_timeout:
    ; cancel transaction due to timeout
    LDI R20, ST_CANCELLED

    ; print timeout message
    LDI ZH, hi8(str_timeout)
    LDI ZL, lo8(str_timeout)
    RCALL usart_print_string
    RJMP main_loop

; completed state
state_completed:
    ; mark session as inactive
    LDI R16, 0x00
    STS session_active, R16

    ; print completion message
    LDI ZH, hi8(str_completed)
    LDI ZL, lo8(str_completed)
    RCALL usart_print_string

    ; turn off status LEDs
    CBI PORTB, LED_GREEN
    CBI PORTB, LED_RED

    ; halt RFID communication
    RCALL mfrc522_halt

    ; short delay before reset
    RCALL delay_500ms

    ; reset state machine values
    LDI R20, ST_IDLE
    LDI R21, 0x00
    LDI R22, 0x00
    LDI R23, 0x00

    ; print ready message
    LDI ZH, hi8(str_ready)
    LDI ZL, lo8(str_ready)
    RCALL usart_print_string

    RJMP main_loop

; cancelled state
state_cancelled:
    ; mark session as inactive
    LDI R16, 0x00
    STS session_active, R16

    ; disable keypad
    RCALL keypad_disable

    ; print cancellation message
    RCALL usart_newline
    LDI ZH, hi8(str_cancelled)
    LDI ZL, lo8(str_cancelled)
    RCALL usart_print_string

    ; turn off LEDs
    CBI PORTB, LED_GREEN
    CBI PORTB, LED_RED

    ; halt RFID communication
    RCALL mfrc522_halt

    ; short delay before reset
    RCALL delay_500ms

    ; reset state machine values
    LDI R20, ST_IDLE
    LDI R21, 0x00
    LDI R22, 0x00
    LDI R23, 0x00

    ; print ready message
    LDI ZH, hi8(str_ready)
    LDI ZL, lo8(str_ready)
    RCALL usart_print_string

    RJMP main_loop

; failed state
state_failed:
    ; mark session as inactive
    LDI R16, 0x00
    STS session_active, R16

    ; disable keypad
    RCALL keypad_disable

    ; print failure message
    LDI ZH, hi8(str_failed)
    LDI ZL, lo8(str_failed)
    RCALL usart_print_string

    ; short delay before reset
    RCALL delay_500ms

    ; turn off LEDs
    CBI PORTB, LED_GREEN
    CBI PORTB, LED_RED

    ; halt RFID communication
    RCALL mfrc522_halt

    ; reset state machine values
    LDI R20, ST_IDLE
    LDI R21, 0x00
    LDI R22, 0x00
    LDI R23, 0x00

    ; print ready message
    LDI ZH, hi8(str_ready)
    LDI ZL, lo8(str_ready)
    RCALL usart_print_string

    RJMP main_loop

; convert digit buffer into numeric value
parse_item_id:
    ; point X register to digit buffer
    LDI XL, lo8(digit_buffer)
    LDI XH, hi8(digit_buffer)

    ; load digit count
    LDS R17, digit_count

    ; clear result register
    LDI R16, 0

parse_loop:
    ; stop when all digits processed
    CPI R17, 0
    BREQ parse_done

    ; multiply current result by 10
    MOV R18, R16
    LSL R16
    LSL R16
    ADD R16, R18
    LSL R16

    ; load next digit
    LD R18, X+

    ; convert ascii digit into number
    SUBI R18, '0'

    ; add digit to result
    ADD R16, R18

    ; decrease digit counter
    DEC R17
    RJMP parse_loop

parse_done:
    RET

; interrupt service routines

; RFID interrupt service routine
; triggered when RFID module signals card detection
__vector_1:
    ; save working register
    PUSH R16

    ; save status register
    IN R16, SREG
    PUSH R16

    ; set RFID interrupt flag
    LDI R16, 0x01
    STS rfid_irq_flag, R16

    ; restore status register
    POP R16
    OUT SREG, R16

    ; restore working register
    POP R16
    RETI

; timer1 compare match interrupt
; runs once every second
__vector_11:
    ; save registers
    PUSH R16
    IN R16, SREG
    PUSH R16
    PUSH R17

    ; load timer counter bytes
    LDS R16, timer_seconds
    LDS R17, timer_seconds+1

    ; increment low byte
    INC R16
    BRNE timer_store

    ; increment high byte on overflow
    INC R17

timer_store:
    ; store updated timer values
    STS timer_seconds, R16
    STS timer_seconds+1, R17

    ; check if session is active
    LDS R16, session_active
    CPI R16, 1
    BRNE t1_done

    ; check if timeout already reached zero
    CPI R24, 0
    BREQ t1_done

    ; decrease timeout counter
    DEC R24

t1_done:
    ; restore registers
    POP R17
    POP R16
    OUT SREG, R16
    POP R16
    RETI

; keypad pin change interrupt
; triggered when keypad row state changes
__vector_5:
    ; save working register
    PUSH R16

    ; save status register
    IN R16, SREG
    PUSH R16

    ; set keypad interrupt flag
    LDI R16, 0x01
    STS keypad_flag, R16

    ; restore status register
    POP R16
    OUT SREG, R16

    ; restore working register
    POP R16
    RETI


; Format: UID0, UID1, UID2, UID3, UserID
.section .text
user_table:
    .byte 0x59, 0x5C, 0xFC, 0x03, 0x01   ; User 1
    .byte 0x13, 0x4C, 0x7D, 0x14, 0x02   ; User 2
    .byte 0xA1, 0xB2, 0xC3, 0xD4, 0x03   ; User 3

; 4x4 Keypad mapping table
keymap_table:
    .byte '1', '2', '3', 'A'
    .byte '4', '5', '6', 'B'
    .byte '7', '8', '9', 'C'
    .byte '*', '0', '#', 'D'


str_startup:
    .asciz "\r\n=== RFID Borrowing System ===\r\n"
str_ready:
    .asciz "System ready. Scan RFID card...\r\n"
str_card_scan:
    .asciz "Card detected, authenticating...\r\n"
str_uid:
    .asciz "UID: "
str_auth_ok:
    .asciz "Auth OK. User ID: "
str_auth_fail:
    .asciz "Auth FAILED: Unknown card.\r\n"
str_enter_item:
    .asciz "Enter item ID (0-3), press #:\r\n"
str_item_id:
    .asciz "Item ID: "
str_item_invalid:
    .asciz "Invalid item ID!\r\n"
str_borrow_start:
    .asciz "Remove item from slot...\r\n"
str_return_start:
    .asciz "Place item into slot...\r\n"
str_borrow_ok:
    .asciz "BORROW OK. Item "
str_return_ok:
    .asciz "RETURN OK. Item "
str_by_user:
    .asciz " by User "
str_timeout:
    .asciz "Session timeout. Cancelled.\r\n"
str_completed:
    .asciz "Transaction complete.\r\n"
str_cancelled:
    .asciz "Transaction cancelled.\r\n"
str_failed:
    .asciz "Transaction failed.\r\n"
str_overdue:
    .asciz "ALERT: Item overdue!\r\n"