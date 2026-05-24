//STOP GO program for mcp
//
//pin map
//pmod0 - not used
//pmod1 - SCL
//pmod2 - SDA
//pmod3 - test out

//mcp pins
//pin 0 - red led
//pin 1 - green led
//pin 2 - unused
//pin 3 - pushbutton (with pullup enabled)


#include <stdlib.h>          
#include <stdio.h>   
#include <stdint.h>        
#include <string.h> 
#include <unistd.h>   // for usleep()
#include "i2c_ip.h"    


#define MCP23008_ADDR   0x20u  
#define MCP_IODIR       0x00u
#define MCP_GPPU        0x06u
#define MCP_GPIO        0x09u
#define MCP_OLAT        0x0Au

#define PB_PIN          3u

#define CTRL_WRITE      162u//418u
#define CTRL_READ       163u//419u



void write_dir(){
    writeAddressReg(MCP23008_ADDR);
    writeRegister(MCP_IODIR);    // IODIR register
    writeDataReg(0x08);          // Set pin 3 (PB) as input, others as output
    writeControlReg(CTRL_WRITE);
    uint32_t status = getStatusReg();
    do{
        status = getStatusReg();
    } while((status >> 7) & 1);

    //wait for TXFE bit to be set
    while (!(status & (1 << 5))) { status = getStatusReg(); }
}

void en_pullup(){
    writeAddressReg(MCP23008_ADDR);
    writeRegister(MCP_GPPU);    // GPPU register
    writeDataReg(8);         // Enable pull-up on pin 3 (PB)

    writeControlReg(CTRL_WRITE);
    uint32_t status;
    do{
        status = getStatusReg();
    } while((status >> 7) & 1);

    //wait for TXFE bit to be set
    while (!(status & (1 << 5))) { status = getStatusReg(); }
}

void write_leds(uint8_t led_state){
    writeAddressReg(MCP23008_ADDR);
    writeRegister(MCP_OLAT);    // OLAT register
    writeDataReg(led_state);     // Set LED states
    writeControlReg(CTRL_WRITE);
    uint32_t status;

     do{
        status = getStatusReg();
    } while((status >> 7) & 1);
    //wait for TXFE bit to be set
    while (!(status & (1 << 5))) { status = getStatusReg(); }

    
}
uint8_t read_pin(void){
    writeAddressReg(MCP23008_ADDR);
    writeRegister(MCP_GPIO);    // GPIO register
    writeControlReg(CTRL_READ);
    uint32_t status;
    do{
        status = getStatusReg();
    } while((status >> 7) & 1);
    //make sure fifo is not empty before read
    while (status & (1 << 2)) { status = getStatusReg(); }

    uint32_t data = readDataReg();
    return (uint8_t)data;
}

void waitPbPress()
{
    while(1){
        uint8_t pins = read_pin();
        if (!(pins & (1 << PB_PIN))){
            break;
        }
        //wait until not busy
    }
}
int main(){
    i2cOpen(); // Initialize the I2C interface


    write_dir();

    en_pullup();
    //print status register
    uint32_t status = getStatusReg();
    printf("I2C Status Register after setting IODIR: 0x%08X\n", status);

    uint8_t led_state = 0;
    led_state |= (1<<0); //turn on red led
    led_state &= ~(1<<1); //turn off green led
    write_leds(led_state);
    printf("Red LED ON\n");
 

    waitPbPress();
    printf("Pushbutton Pressed! \n");


    led_state &= ~(1<<0); //turn off red
    led_state |= (1<<1);  //turn on green
    write_leds(led_state);
    printf("Green LED ON\n");

    return 0;
}