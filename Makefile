

# HEADER_FILES = c_src
# SOURCE_FILES = c_src/portaudio.c
#
# OBJECT_FILES = $(SOURCE_FILES:.c=.o)
#
# INC = -I$(ERLANG_PATH)/include -I$(HEADER_FILES)
# LDFLAGS = -L$(ERLANG_PATH)/lib -lportaudio -L/usr/local/lib
#
# CFLAGS = -g -O3 -ansi -pedantic -Wall -Wno-comment -Wextra $(INC)
#
# .c.o:
# 	$(CC) $(CFLAGS) -fPIC -o $@ -c $<
#
# # .o.so:
#
# priv_dir/portaudio.so: priv_dir $(OBJECT_FILES)
# 	$(CC) $(CFLAGS) -bundle -flat_namespace -undefined suppress -o $@ $(OBJECT_FILES)  $(LDFLAGS) \
# 		|| $(CC) -shared -o $@ $(OBJECT_FILES) $(LDFLAGS)
#
# priv_dir:
# 	mkdir -p priv_dir
#
# clean:
# 	rm -f priv_dir/portaudio.so $(OBJECT_FILES) $(BEAM_FILES)
#
# all: priv_dir/portaudio.so
#
# default: all


.PHONY: clean
.SUFFIXES: .o .c

OS=${shell uname}
CC=gcc
CXX=g++

CFLAGS=-Wall -g -pedantic -Wno-comment -Wextra

# Erlang
ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version) ])])' -s init stop -noshell)
ERL_INCLUDE = -I$(ERLANG_PATH)/include
ERL_LIBS    = -L$(ERLANG_PATH)/lib \
							-lerts
EI_INCLUDE  = -I$(ERLANG_PATH)/../lib/erl_interface-3.8/include
EI_LIBS     = -L$(ERLANG_PATH)/../lib/erl_interface-3.8/lib \
							-lei \
							-lerl_interface
AUDIO_INCLUDE = -I/usr/local/include
AUDIO_LIBS    = -L/usr/local/lib -lportaudio -lsamplerate

HEADER_FILES = c_src
SOURCE_FILES = c_src/portaudio.c c_src/pa_ringbuffer.c

OBJECT_FILES = $(SOURCE_FILES:.c=.o)

TARGET_LIB = priv_dir/portaudio.so

ifeq ($(OS), Darwin)
	EXTRA_OPTIONS = -fno-common -bundle -undefined suppress -flat_namespace
endif

default: all

all: $(TARGET_LIB)

.c.o:
	$(CC) $(CFLAGS) $(ERL_LIBS) $(ERL_INCLUDE) $(AUDIO_INCLUDE) -o $@ -c $<

$(TARGET_LIB): $(OBJECT_FILES)
	$(CC) -o $@ $^ $(ERL_LIBS) $(EI_LIBS) $(AUDIO_LIBS) $(EXTRA_OPTIONS) -fPIC -O3

clean:
	rm -f  c_src/*.o priv_dir/*.so

