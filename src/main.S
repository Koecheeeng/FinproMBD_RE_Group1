#include <avr/io.h>
#include "rfid.S"
#include "keypad.S"
#include "init_io.S"
#include "eeprom.S"
#include "timer.S"
#include "feedback.S"
#include "usart.S"
#include "slide_switch.S"

.global main

main: