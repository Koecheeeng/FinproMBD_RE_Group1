#define __SFR_OFFSET 0x00
#include "avr/io.h"

.equ BAUD_UBRR, 103 ; UBRR value for 9600 baud at 16 MHz

.section .text
.global init_usart
.global usart_transmit
.global usart_print_string
.global usart_newline
.global usart_print_hex
.global usart_print_uid
.global usart_print_decimal

; initialize usart
init_usart:
    ; load high byte of baud
    LDI R16, hi8(BAUD_UBRR)
    STS UBRR0H, R16

    ; load low byte of baud
    LDI R16, lo8(BAUD_UBRR)
    STS UBRR0L, R16

    ;enable transmitter and receiver
    LDI R16, (1<<TXEN0)|(1<<RXEN0)
    STS UCSR0B, R16

    ; set to 8-bit data mode
    LDI R16, (1<<UCSZ01)|(1<<UCSZ00)
    STS UCSR0C, R16
    RET

usart_transmit:
    ; save register
    PUSH R17
usart_tx_wait:
    ; read usart status register
    LDS R17, UCSR0A

    ; check if transmit buffer is empty 
    SBRS R17, UDRE0

    ; wait until it is ready
    RJMP usart_tx_wait

    ; send character
    STS UDR0, R16

    ; restore register
    POP R17
    RET

usart_print_string:
    ; load next character
    LPM R16, Z+

    ; check for null terminator
    CPI R16, 0x00
    
    ; end if string is finished (encounters terminator)
    BREQ usart_ps_done

    ; print character
    RCALL usart_transmit

    ; repeat for next character
    RJMP usart_print_string
usart_ps_done:
    RET

; send carriage return and line feed
usart_newline:
    LDI R16, 0x0D
    RCALL usart_transmit
    LDI R16, 0x0A
    RCALL usart_transmit
    RET

usart_print_hex:
    ; save original value
    PUSH R16

    ; print upper nibble first and then lower nibble
    ; swap the upper and lower nibbles
    SWAP R16

    ; keep only lower 4 bits
    ANDI R16, 0x0F

    ; convert to ascii
    RCALL hex_to_ascii
    RCALL usart_transmit

    ; restore original value and do the same for lower nibble
    POP R16
    ANDI R16, 0x0F
    RCALL hex_to_ascii
    RCALL usart_transmit
    RET

hex_to_ascii:
    ; check if digit is 0-9
    CPI R16, 10
    BRLO hex_digit

    ; convert 10-15 into A-F
    SUBI R16, -('A' - 10)
    RET
hex_digit:
    ; convert 0-9 into ascii
    SUBI R16, -'0'
    RET

; print 4-byte card UID separated by colons
; example: AA:BB:CC:DD
usart_print_uid:
    LDS R16, card_uid
    RCALL usart_print_hex

    LDI R16, ':'
    RCALL usart_transmit

    LDS R16, card_uid+1
    RCALL usart_print_hex

    LDI R16, ':'
    RCALL usart_transmit

    LDS R16, card_uid+2
    RCALL usart_print_hex

    LDI R16, ':'
    RCALL usart_transmit

    LDS R16, card_uid+3
    RCALL usart_print_hex
    
    RCALL usart_newline
    RET

usart_print_decimal:
    PUSH R16
    PUSH R17
    PUSH R18

    ; copy number
    MOV R17, R16

    ; flag to track printing
    LDI R18, 0

    ; counter for hundreds
    LDI R16, 0

; repeatedly subtracts 100 to count how many hundreds are in the number
dec_hundreds:
    CPI R17, 100
    BRLO dec_print_h
    SUBI R17, 100
    INC R16
    RJMP dec_hundreds

; print hundreds digit if not zero
dec_print_h:
    CPI R16, 0
    BREQ dec_skip_h
    SUBI R16, -'0'
    RCALL usart_transmit

    ; mark that a digit was printed
    LDI R18, 1
dec_skip_h:
    ; reset counter for tens
    LDI R16, 0
dec_tens:
    ; count tens digit (same method as counting hundreds)
    CPI R17, 10
    BRLO dec_print_t
    SUBI R17, 10
    INC R16
    RJMP dec_tens

; print tens digit if needed
dec_print_t:
    CPI R18, 0
    BRNE dec_print_t2

    CPI R16, 0
    BREQ dec_skip_t
dec_print_t2:
    SUBI R16, -'0'
    RCALL usart_transmit
dec_skip_t:
    ; ones (always printed)
    MOV R16, R17
    SUBI R16, -'0'
    RCALL usart_transmit

    ; restore registers
    POP R18
    POP R17
    POP R16
    RET