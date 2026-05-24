#!/bin/bash

I2C=/sys/kernel/i2c

#mcp registers
MCP23008_ADDR=0x20
MCP_IODIR=0x00
MCP_GPPU=0x06
MCP_GPIO=0x09
MCP_OLAT=0x0A

#PB_PIN=3

#comment

write_dir(){
    echo $MCP23008_ADDR > $I2C/address
    echo $MCP_IODIR > $I2C/register
    echo write > $I2C/mode
    echo 8 > $I2C/tx_data
    echo 1 > $I2C/byte_count
    echo 1 > $I2C/start
}

en_pullup(){
    echo $MCP23008_ADDR > $I2C/address
    echo $MCP_GPPU > $I2C/register
    echo write > $I2C/mode
    echo 8 > $I2C/tx_data
    echo 1 > $I2C/byte_count
    echo 1 > $I2C/start
}

write_leds(){
    led_state=$1
    echo $MCP23008_ADDR > $I2C/address 
    echo $MCP_OLAT > $I2C/register
    echo write > $I2C/mode
    echo $led_state > $I2C/tx_data
    echo 1 > $I2C/byte_count
    echo 1 > $I2C/start
    sleep 0.1
}

read_pin(){
    echo $MCP23008_ADDR > $I2C/address
    echo $MCP_GPIO > $I2C/register
    echo read > $I2C/mode
    echo 1 > $I2C/byte_count
    echo 1 > $I2C/start
    #sleep 0.1
    cat $I2C/rx_data
}

echo "-----------------------"
echo "Stop Go using Bash Script"
write_dir #set pin 3 as output
en_pullup #enable pull up on pin 3
echo "inialization complete"
write_leds 1 #turn on red led
echo "Red LED ON"
echo "waiting for push button..."
while true; do
    pin_state=$(read_pin)
    pb=$((pin_state & (1 << 3)))
    if [ $pb -eq 0 ]; then  
        break
    fi
done
echo "Push Button Pressed"
write_leds 2 #turn on green led
echo "Green LED ON"






