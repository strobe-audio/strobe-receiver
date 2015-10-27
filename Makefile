
.PHONY: clean
.SUFFIXES: .o .c

OS=${shell uname}
CC=gcc
CXX=g++

CFLAGS=-Wall -std=c99 -g -pedantic -Wno-comment -Wextra

#echo $(ERLANG_PATH)
# Erlang
ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version) ])])' -s init stop -noshell)


ERL_INCLUDE = -I$(ERLANG_PATH)/include
ERL_LIBS    = -L$(ERLANG_PATH)/lib \
							-lerts
EI_INCLUDE  = -I$(ERLANG_PATH)/../lib/erl_interface-3.8/include
EI_LIBS     = -L$(ERLANG_PATH)/../lib/erl_interface-3.8/lib \
							-lei \
							-lerl_interface
AUDIO_INCLUDE = -I/usr/local/include -I/usr/include
AUDIO_LIBS    = -L/usr/local/lib -lportaudio -lsamplerate

STD_LIBS      = -lm

HEADER_FILES = c_src
SOURCE_FILES = c_src/portaudio.c c_src/pa_ringbuffer.c c_src/monotonic_time.c c_src/stream_statistics.c c_src/pid.c

OBJECT_FILES = $(SOURCE_FILES:.c=.o)

TARGET_LIB = priv_dir/portaudio.so

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

all: $(TARGET_LIB)

.c.o:
	$(CC) $(CFLAGS) $(ERL_INCLUDE) $(EI_INCLUDE) $(AUDIO_INCLUDE) -o $@ -c $<

$(TARGET_LIB): $(OBJECT_FILES)
	@echo $(ERLANG_PATH)
	$(CC) -o $@ $^ $(ERL_INCLUDE) $(ERL_LIBS) $(EI_LIBS) $(AUDIO_LIBS) $(STD_LIBS) $(EXTRA_OPTIONS) -fPIC -O3

clean:
	rm -f  c_src/*.o priv_dir/*.so

