MCU = atmega328p
F_CPU = 16000000UL

CC = avr-gcc
OBJCOPY = avr-objcopy
AVRDUDE = avrdude

CFLAGS = -mmcu=$(MCU) -DF_CPU=$(F_CPU) -I include/ -x assembler-with-cpp

SRC = src/main.S
ELF = build/main.elf
HEX = build/main.hex

all: $(HEX)

$(HEX): $(ELF)
	$(OBJCOPY) -O ihex $< $@

$(ELF): $(SRC) | build/
	$(CC) $(CFLAGS) -o $@ $<

build/:
	mkdir -p build
clean:
	rm -rf build