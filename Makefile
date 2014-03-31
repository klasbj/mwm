
DC := gdc
DCFLAGS := -g -Wall
#-funittest

INCLUDES := -Ixcb.d
INCLUDES += -Isource
INCLUDES += -IZeroMQ
INCLUDES += -Imsgpack-d/src
#INCLUDES +=

LIBS := $(shell pkg-config --libs xcb)
LIBS += $(shell pkg-config --libs xcb-xinerama)
LIBS += -lpthread
LIBS += $(shell pkg-config --libs libzmq)

vpath %.d source
vpath %.d source/mwm
vpath %.d msgpack-d/src

OBJS := mwm.o common.o x.o wm.o msgpack.o messages.o xrunner.o
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

# dependencies
mwm.o: xrunner.d wm.d

xrunner.o wm.o: x.d common.d messages.d

wm.o: x.d

x.o: common.d
