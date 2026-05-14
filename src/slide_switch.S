#define __SFR_OFFSET 0x00
#include "avr/io.h"

; slide_switch.S - slot presence detection
; active-low: LOW = present, HIGH = empty
; slots 0-1 have physical switches, slots 2-3 auto-complete
; input: R22 = slot index, R23 = txn type (0=borrow, 1=return)
; output: R25 = 0x00 (absent) or 0x01 (present)

.equ SW_SLOT1,  4           ; PC4
.equ SW_SLOT2,  5           ; PC5

.section .text
.global read_slot_switch

read_slot_switch:
    CPI   R22, 0
    BREQ  switch_read_slot0
    CPI   R22, 1
    BREQ  switch_read_slot1
    ; slots 2-3: auto-complete based on txn type
    CPI   R23, 0x00
    BREQ  switch_empty
    LDI   R25, 0x01
    RET
switch_read_slot0:
    IN    R16, PINC
    SBRC  R16, SW_SLOT1
    RJMP  switch_empty
    LDI   R25, 0x01
    RET
switch_read_slot1:
    IN R16, PINC
    SBRC R16, SW_SLOT2
    RJMP  switch_empty
    LDI  R25, 0x01
    RET
switch_empty:
    LDI   R25, 0x00
    RET