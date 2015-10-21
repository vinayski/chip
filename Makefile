CC=$(CROSS_COMPILE)gcc

spl-image-builder: spl-image-builder.o
	$(CC) -o $@ $<

all: spl-image-builder

clean:
	rm -rf *.o
	rm spl-image-builder
