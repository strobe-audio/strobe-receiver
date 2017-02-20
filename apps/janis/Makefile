
.PHONY: clean directories
.SUFFIXES: .o .c

OS=${shell uname}
CC ?= $(CROSSCOMPILE)gcc
CXX=g++
OPTIMIZE=-Ofast
CFLAGS ?= -Wall -g -pthread -pedantic -Wno-comment -Wextra -DUSE_PTHREAD
CFLAGS += -std=gnu99 -fPIC
#-march=native

# Erlang
# see https://github.com/nerves-project/nerves_network_interface/blob/master/Makefile
# for cross-compilation example
#
ERL_PATH ?= $(shell erl -eval 'io:format("~s", [code:root_dir()])' -s init stop -noshell)

ERL_CFLAGS ?= -I$(ERL_PATH)/usr/include
ERL_EI_LIBDIR ?= $(ERL_PATH)/usr/lib
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR)  -lei -lerl_interface

LDFLAGS      += -lportaudio -lsamplerate -lm

HEADER_FILES = c_src
SOURCE_FILES = c_src/janis.c c_src/pa_ringbuffer.c c_src/monotonic_time.c c_src/stream_statistics.c c_src/pid.c

MKDIR_P      = mkdir -p
OBJECT_FILES = $(SOURCE_FILES:.c=.o)
PRIV_DIR     = priv
TARGET_LIB   = $(PRIV_DIR)/janis.so

ifeq ($(OS), Darwin)
	EXTRA_OPTIONS = -fno-common -bundle -undefined suppress -flat_namespace
else
	EXTRA_OPTIONS = -shared
endif

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	LDFLAGS += -lrt -lasound -lpthread
endif

default: all

all: directories $(TARGET_LIB)

.c.o:
	$(CC) $(CFLAGS) -fPIC $(OPTIMIZE) $(ERL_CFLAGS) -o $@ -c $<

$(TARGET_LIB): $(OBJECT_FILES)
	@echo $(ERLANG_PATH)
	$(CC) -o $@ $^ $(ERL_CFLAGS) $(ERL_LDFLAGS) $(LDFLAGS) $(EXTRA_OPTIONS) $(OPTIMIZE) -fPIC

program: $(OBJECT_FILES)

directories: $(PRIV_DIR)

${PRIV_DIR}:
	${MKDIR_P} ${PRIV_DIR}

clean:
	rm -f  c_src/*.o priv/*.so

