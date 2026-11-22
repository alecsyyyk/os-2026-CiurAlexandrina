# Lab 11 - compile everything WITHOUT -O2 (the optimizer would hide the race)
CFLAGS = -Wall -pthread
PROGS  = race mutex sem order parking atomic

all: $(PROGS)

%: %.c
	gcc $(CFLAGS) -o $@ $<

clean:
	rm -f $(PROGS)
