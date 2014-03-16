
DC := gdc
DCFLAGS := -g -Wall -funittest

INCLUDES := -Ixcb.d
INCLUDES += -Isource
INCLUDES += -IZeroMQ
#INCLUDES +=

LIBS := $(shell pkg-config --libs xcb)
LIBS += -lpthread
LIBS += $(shell pkg-config --libs libzmq)

vpath %.d source
vpath %.d source/mwm

OBJS := mwm.o common.o x.o wm.o
BIN := mwm

.PHONY: all clean
all: $(BIN)

%.o: %.d
	@echo Compile $<...
	@$(DC) $(DCFLAGS) $(INCLUDES) -c $<

$(BIN): $(OBJS)
	@echo Link $@
	@$(DC) $(DCFLAGS) $(LIBS) -o $@ $^

clean:
	-rm -f $(OBJS)
	-rm -f $(BIN)
