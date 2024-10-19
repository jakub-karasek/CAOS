COMPILER=gcc
COMPILER_FLAGS=-Wall -Wextra -Wno-implicit-fallthrough -std=gnu17 -fPIC -O2
LINKER_FLAGS=-shared -Wl,--wrap=malloc -Wl,--wrap=calloc -Wl,--wrap=realloc -Wl,--wrap=reallocarray -Wl,--wrap=free -Wl,--wrap=strdup -Wl,--wrap=strndup

SOURCES=nand.c memory_tests.c
OBJECTS=$(SOURCES:.c=.o)
HEADERS=nand.h memory_tests.h
EXAMPLE=nand_tests
LIBRARY=libnand.so

.PHONY: everything clear

everything: $(LIBRARY) $(EXAMPLE)

$(LIBRARY): $(OBJECTS)
	$(COMPILER) $(LINKER_FLAGS) -o $@ $^

$(EXAMPLE): nand_tests.o $(LIBRARY)
	$(COMPILER) -o $@ $< -L. -lnand

%.o: %.c $(HEADERS)
	$(COMPILER) $(COMPILER_FLAGS) -c -o $@ $<

clean:
	rm -f $(OBJECTS) $(LIBRARY) $(EXAMPLE) main.o nand_tests.o

