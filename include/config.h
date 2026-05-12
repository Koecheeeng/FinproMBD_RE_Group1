#ifndef CONFIG_H
#define CONFIG_H

#include <avr/io.h>

#define F_CPU 16000000UL
#define BAUD 9600
#define UBRR_VAL ((F_CPU / (16UL * BAUD)) - 1) // 103

// modify as needed
#define BORROW_LIMIT_SEC 300
#define SESSION_TIMEOUT_SEC 15

#define EEPROM_BASE 0x00
#define SLOT_RECORD_SIZE 6
#define NUM_SLOTS 4

#define STATE_IDLE 0
#define STATE_AUTH 1
#define STATE_ITEM_ENTRY 2
#define STATE_VALIDATION 3
#define STATE_BORROW_VERIFY 4
#define STATE_RETURN_VERIFY 5
#define STATE_COMPLETED 6
#define STATE_FAILED 7
#define STATE_CANCELLED 8

#define ACTION_BORROW 0
#define ACTION_RETURN 1

#define STATUS_AVAILABLE 0
#define STATUS_BORROWED 1
#define STATUS_OVERDUE 2

#endif