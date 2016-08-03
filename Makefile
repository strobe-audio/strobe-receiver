
.PHONY: clean directories
.SUFFIXES: .o .c

OS=${shell uname}
CC ?= $(CROSSCOMPILE)gcc
CXX=g++
OPTIMIZE=-Ofast
CFLAGS ?= -Wall -g -pedantic -Wno-comment -Wextra
CFLAGS += -std=gnu99 -fPIC
#-march=native

#echo $(ERL_PATH)
# Erlang
ERL_PATH ?= $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version) ])])' -s init stop -noshell)


ERL_CFLAGS ?= -I$(ERL_PATH)/include
ERL_EI_LIBDIR ?= $(ERL_PATH)/usr/lib
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR) -lei -lerl_interface
# ERL_LIBS    = -L$(ERL_PATH)/lib \
# 							-lerts
EI_INCLUDE  = -I$(ERL_PATH)/../usr/include

# AUDIO_INCLUDE = -I/usr/local/include -I/usr/include
# AUDIO_LIBS    = -L/usr/local/lib -lportaudio -lsamplerate
AUDIO_LIBS    = -lportaudio -lsamplerate

LDFLAGS      += -lm

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
	AUDIO_LIBS += -lrt -lasound -lpthread
endif

default: all

all: directories $(TARGET_LIB)

.c.o:
	$(CC) $(CFLAGS) -fPIC $(OPTIMIZE) $(ERL_CFLAGS) $(EI_INCLUDE) -o $@ -c $<

$(TARGET_LIB): $(OBJECT_FILES)
	@echo $(ERLANG_PATH)
	$(CC) -o $@ $^ $(ERL_CFLAGS) $(ERL_EI_LIBDIR) $(ERL_LDFLAGS) $(AUDIO_LIBS) $(LDFLAGS) $(EXTRA_OPTIONS) $(OPTIMIZE) -fPIC

program: $(OBJECT_FILES)

directories: $(PRIV_DIR)

${PRIV_DIR}:
	${MKDIR_P} ${PRIV_DIR}

clean:
	rm -f  c_src/*.o priv/*.so

