
# Makefile inside c/i2c

CC = gcc
CFLAGS = -O2 -Wall
TARGET = i2c

# include parent directory for address_map.h
INCLUDES = -I..

OBJS = i2c.o i2c_ip.o

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)

