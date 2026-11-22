# Lab 12
CFLAGS = -Wall -pthread
PROGS  = prodcons condvar readers deadlock deadlock_original

all: $(PROGS)

%: %.c
	gcc $(CFLAGS) -o $@ $<

clean:
	rm -f $(PROGS)
