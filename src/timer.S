#define __SFR_OFFSET 0x00
#include "avr/io.h"

.section .text
.global init_timer1
.global delay_20ms
.global delay_500ms

init_timer1:
    LDI R16, 0x00
    STS TCCR1A, R16
    ; set timer1 into ctc mode and using 1024 prescaller
    ; this one for making the timer count slow
    LDI R16, (1<<WGM12)|(1<<CS12)|(1<<CS10)
    STS TCCR1B, R16
    ; OCR1A value for around 1 second delay with 16mhz clock
    ; honestly took awhile to get this value right
    LDI R16, hi8(15624)
    STS OCR1AH, R16
    LDI R16, lo8(15624)
    STS OCR1AL, R16
    ; enabling compare match interrupt for timer1
    LDI R16, (1<<OCIE1A)
    STS TIMSK1, R16
    RET

delay_20ms:
    PUSH R16
    PUSH R17
    ; small software delay like around 20ms
    ; just using nested loop here
    LDI R16, 160

dly20_outer:
    LDI R17, 250

dly20_inner:
    NOP
    NOP
    DEC R17
    BRNE dly20_inner
    DEC R16
    BRNE dly20_outer
    POP R17
    POP R16
    RET

delay_500ms:
    PUSH R16
    PUSH R17
    PUSH R18
    ; delay for like half secodn
    LDI R16, 25

dly500_l3:
    LDI R17, 200

dly500_l2:
    LDI R18, 250

dly500_l1:
    NOP
    DEC R18
    BRNE dly500_l1
    DEC R17
    BRNE dly500_l2
    DEC R16
    BRNE dly500_l3
    POP R18
    POP R17
    POP R16
    RET
