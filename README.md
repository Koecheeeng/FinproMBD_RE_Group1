# RFID-Based Borrowing System Using AVR Assembly

## Introduction to the Problem and the Solution

In shared environments such as laboratories, workshops, and project rooms, items are often borrowed without proper tracking. This can cause missing items, incorrect borrowing records, and difficulty identifying who borrowed an item. Manual systems are usually unreliable because they depend on human discipline and memory.

This project solves the problem by creating an embedded borrowing system using an ATmega328P microcontroller programmed in AVR Assembly language. The system uses RFID authentication to identify users and a keypad for entering item IDs. Slide switches are used to physically verify whether an item has been removed or returned. EEPROM memory stores transaction data even after power loss, while Timer1 interrupts monitor overdue items and session timeouts.

The system follows a state-machine architecture that manages all transaction stages, including authentication, item entry, validation, borrowing verification, return verification, and completion.

---

# Hardware Design and Implementation Details

The hardware design is based on the Arduino Uno platform using the ATmega328P microcontroller. Several peripheral devices are connected to support authentication, item validation, feedback, and communication.

## Main Components

- Arduino Uno (ATmega328P)
- RC522 RFID reader module
- RFID cards
- 4x4 matrix keypad
- Slide switches
- LEDs
- Active buzzer
- Breadboard and jumper wires

## Hardware Functions

### RFID Module

The RC522 module communicates with the microcontroller using the SPI protocol. It reads RFID card UIDs for user authentication.

### Keypad

The 4x4 keypad is used for entering item IDs and transaction commands such as confirm (`#`) and cancel (`*`).

### Slide Switches

Each item slot uses a slide switch to detect whether an item is physically present or removed. The switches use active-low logic.

### LEDs and Buzzer

The LEDs and buzzer provide visual and audio feedback for system events such as:
- Successful authentication
- Successful borrowing
- Successful return
- Invalid RFID
- Invalid item ID
- Overdue alerts

### EEPROM

EEPROM memory stores:
- Item status
- User ID
- Borrowing timestamp

This allows transaction data to remain available after power loss.

## Pin Allocation

### PORTB

| Pin | Function |
|---|---|
| PB0 | Green LED |
| PB1 | Red LED |
| PB2 | RC522 SS |
| PB3 | SPI MOSI |
| PB4 | SPI MISO |
| PB5 | SPI SCK |

### PORTC

| Pin | Function |
|---|---|
| PC0-PC3 | Keypad Columns |
| PC4-PC5 | Slide Switch Inputs |

### PORTD

| Pin | Function |
|---|---|
| PD0 | USART RX |
| PD1 | USART TX |
| PD2 | RC522 RST |
| PD3 | Buzzer |
| PD4-PD7 | Keypad Rows |

---

# Software Implementation Details

The software was developed entirely using AVR Assembly language without using the Arduino framework.

## State Machine

The system uses several states:
1. Idle
2. Authentication
3. Item Entry
4. Item Validation
5. Borrow Verification
6. Return Verification
7. Completed
8. Cancelled
9. Failed

The state machine controls the flow of the borrowing and returning process.

## RFID Authentication

The RC522 module communicates through SPI. The system reads the RFID UID and compares it with a lookup table stored in Flash memory. If the UID matches a registered user, authentication succeeds.

## Keypad Scanning

The keypad scanning process works by activating one column at a time and reading the row inputs. A debounce routine is used to avoid multiple detections from a single key press.

Digit inputs are temporarily stored in SRAM and converted into an item ID using the following formula:

```math
value = (value \times 10) + digit
```

The final item ID is stored in register `R22`.

## Slide Switch Validation

The slide switches verify physical item movement:
- Borrowing requires the slot to become empty
- Returning requires the slot to become occupied

The verification result determines whether the transaction succeeds or fails.

## EEPROM Storage

Each item slot uses 6 bytes in EEPROM:
- Byte 0: Item status
- Byte 1: User ID
- Bytes 2-5: Borrow timestamp

## USART Communication

USART0 is configured at 9600 baud with 8N1 format. Serial messages are sent for debugging and monitoring purposes.

## Timer and Interrupts

Timer1 is configured in CTC mode to generate 1-second interrupts.

```math
f_{interrupt} = \frac{16 \text{ MHz}}{1024 \times (15624 + 1)} \approx 1 \text{ Hz}
```

The timer is used for:
- Session timeout
- Borrow duration tracking
- Overdue detection

Interrupts are also used for RFID detection and keypad input handling.

---

# Test Results and Performance Evaluation

The system was tested both in the Wokwi simulator and on physical hardware.

## RFID Authentication Test

- Registered RFID cards were accepted successfully
- Unregistered cards were rejected
- SPI communication between RC522 and ATmega328P was stable

## Keypad Test

- Numeric item IDs were entered correctly
- Confirm and cancel buttons worked properly
- Debounce logic prevented repeated key detection

## Slide Switch Validation Test

- Borrowing transactions succeeded only when the item was physically removed
- Return transactions succeeded only when the item was physically returned
- Invalid physical actions caused the system to enter the Failed state

## EEPROM Test

- Borrowing records remained stored after system reset
- Item status and timestamps were restored successfully

## Timer and Overdue Test

- Timer1 interrupts correctly tracked borrowing duration
- Overdue items triggered LED and buzzer alerts

## USART Communication Test

- Serial messages were transmitted correctly at 9600 baud
- User IDs and item IDs were displayed properly

## Overall Performance

The complete system successfully integrated:
- RFID authentication
- Keypad input
- Slide switch validation
- EEPROM storage
- Timer interrupts
- USART communication

---

# Conclusion and Future Work

The RFID-based borrowing system was successfully implemented using the ATmega328P microcontroller and AVR Assembly language. The system can manage borrowing and returning transactions using RFID authentication, keypad input, slide switch verification, EEPROM storage, timer interrupts, and serial communication.

Testing results showed that the system worked correctly both individually and as a complete integrated embedded system. The state-machine architecture also helped organize the transaction process clearly and reliably.

However, the current prototype still has several limitations:
- Limited number of item slots due to ATmega328P hardware constraints
- Manual item ID entry through the keypad
- Slide switches cannot fully verify whether the correct item is returned to the correct slot

For future work, the system can be improved by:
- Adding automatic item recognition
- Expanding storage capacity
- Supporting more item slots
- Using a database or wireless communication system
- Improving item verification accuracy using additional sensors