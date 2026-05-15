#define __SFR_OFFSET 0x00
#include "avr/io.h"

.equ RFID_SS, 2
.equ SPI_MOSI, 3
.equ SPI_MISO, 4
.equ SPI_SCK, 5

; mfrc522 register addresses
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

; mfrc522 commands
.equ PCD_Idle, 0x00
.equ PCD_Transceive, 0x0C
.equ PCD_SoftReset, 0x0F

; card commands
.equ PICC_REQA, 0x26
.equ PICC_SEL_CL1, 0x93
.equ PICC_HALT, 0x50

.equ NUM_USERS, 3

.section .text
.global init_spi
.global init_mfrc522
.global spi_transfer
.global mfrc522_read_reg
.global mfrc522_write_reg
.global mfrc522_request
.global mfrc522_anticoll
.global mfrc522_halt
.global validate_uid

; setup master spi
init_spi:
    ; enabling spi in master mode
    ; using fosc/16 and mode 0
    LDI R16, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    OUT SPCR, R16
    ; clearing double speed bit just in case
    LDI R16, 0x00
    OUT SPSR, R16
    RET

; setup mfrc522
init_mfrc522:
    ; resetting the module first
    LDI R16, CommandReg
    LDI R17, PCD_SoftReset
    RCALL mfrc522_write_reg
    RCALL delay_500ms
    ; waiting until reset done
    ; using timeout so it doesnt stuck forever
    LDI R18, 0xFF

mfrc522_wait_reset:
    LDI R16, CommandReg
    RCALL mfrc522_read_reg
    ANDI R16, 0x10
    BREQ mfrc522_reset_done
    DEC R18
    BRNE mfrc522_wait_reset

mfrc522_reset_done:
    ; timer configuration values
    LDI R16, TModeReg
    LDI R17, 0x80
    RCALL mfrc522_write_reg
    LDI R16, TPrescalerReg
    LDI R17, 0xA9
    RCALL mfrc522_write_reg
    LDI R16, TReloadRegH
    LDI R17, 0x03
    RCALL mfrc522_write_reg
    LDI R16, TReloadRegL
    LDI R17, 0xE8
    RCALL mfrc522_write_reg
    ; forcing 100% ask modulation
    LDI R16, TxASKReg
    LDI R17, 0x40
    RCALL mfrc522_write_reg
    ; setting crc preset value
    LDI R16, ModeReg
    LDI R17, 0x3D
    RCALL mfrc522_write_reg
    ; turning antenna on
    LDI R16, TxControlReg
    RCALL mfrc522_read_reg
    ORI R16, 0x03
    MOV R17, R16
    LDI R16, TxControlReg
    RCALL mfrc522_write_reg
    RET

; send data thru spi and the sent data in r16 and result also return in r16
spi_transfer:
    OUT SPDR, R16

spi_wait:
    IN R18, SPSR
    ; waits until transfer complete
    SBRS R18, SPIF
    RJMP spi_wait
    IN R16, SPDR
    RET

; read register from mfrc522 and address r16 regster
mfrc522_read_reg:
    ; shifts address and adding read bit
    LSL R16
    ORI R16, 0x80
    ; selecting slave
    CBI PORTB, RFID_SS
    RCALL spi_transfer
    ; sends dummy byte to receive data
    LDI R16, 0x00
    RCALL spi_transfer
    ; deselecting slave
    SBI PORTB, RFID_SS
    RET

; write register to mfrc522 and address in r16 and data in r17
mfrc522_write_reg:
    ; makes write format address
    LSL R16
    ANDI R16, 0x7E
    CBI PORTB, RFID_SS
    RCALL spi_transfer
    MOV R16, R17
    RCALL spi_transfer
    SBI PORTB, RFID_SS
    RET

; check if card is close or not, if not it is 0
mfrc522_request:
    ; clearing collision register
    LDI R16, CollReg
    LDI R17, 0x80
    RCALL mfrc522_write_reg
    ; sets framing for 7 bit transmission
    LDI R16, BitFramingReg
    LDI R17, 0x07
    RCALL mfrc522_write_reg
    ; sets idle mode first
    LDI R16, CommandReg
    LDI R17, PCD_Idle
    RCALL mfrc522_write_reg
    ; clears irq flags
    LDI R16, ComIrqReg
    LDI R17, 0x7F
    RCALL mfrc522_write_reg
    ; flushes fifo buffer
    LDI R16, FIFOLevelReg
    LDI R17, 0x80
    RCALL mfrc522_write_reg
    ; sends reqa command
    LDI R16, FIFODataReg
    LDI R17, PICC_REQA
    RCALL mfrc522_write_reg
    ; starts transceive command
    LDI R16, CommandReg
    LDI R17, PCD_Transceive
    RCALL mfrc522_write_reg
    ; starts sending data
    LDI R16, BitFramingReg
    RCALL mfrc522_read_reg
    ORI R16, 0x80
    MOV R17, R16
    LDI R16, BitFramingReg
    RCALL mfrc522_write_reg
    ; waits for response from the card
    LDI R18, 0xFF
    LDI R19, 0x0F

req_poll:
    LDI R16, ComIrqReg
    RCALL mfrc522_read_reg
    MOV R17, R16
    ; checking if rx or idle interrupt happens
    ANDI R16, 0x30
    BRNE req_done
    MOV R16, R17
    ; timeout interrupt
    ANDI R16, 0x01
    BRNE req_timeout
    DEC R18
    BRNE req_poll
    DEC R19
    BRNE req_poll

req_timeout:
    ; return error
    LDI R16, 0x01
    RET

req_done:
    ; check communication if its error
    LDI R16, ErrorReg
    RCALL mfrc522_read_reg
    ANDI R16, 0x1B
    BRNE req_timeout
    ; check response is there or not
    LDI R16, FIFOLevelReg
    RCALL mfrc522_read_reg
    CPI R16, 2
    BRLO req_timeout
    ; success
    LDI R16, 0x00
    RET
