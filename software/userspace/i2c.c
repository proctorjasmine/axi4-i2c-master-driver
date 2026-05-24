// I2C IP Example, i2c.c
// I2C Shell Command
// Jasmine Proctor

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: Xilinx XUP Blackboard

// Hardware configuration:
//
// AXI4-Lite interface:
//   Mapped to offset of 0
//

//-----------------------------------------------------------------------------

#include <stdlib.h>          
#include <stdio.h>   
#include <stdint.h>        
#include <string.h> 
#include <unistd.h>   // for usleep()
#include "i2c_ip.h"       

void printStatus(uint32_t status){
    printf("I2C Status Register: 0x%08X\n", status);
    printf("TXFO=%u TXFF=%u TXFE=%u \n"
        "RXFO=%u RXFF=%u RXFE=%u \n"
        "wr=%u rd=%u\n",
        (unsigned)((status >> 3) & 1),
        (unsigned)((status >> 4) & 1),
        (unsigned)((status >> 5) & 1),
        (unsigned)((status >> 0) & 1),
        (unsigned)((status >> 1) & 1),
        (unsigned)((status >> 2) & 1),
        (unsigned)((status >> 8) & 0xF),
        (unsigned)((status >> 12) & 0xF));
}

int main(int argc, char *argv[]){
    uint32_t data;
    uint32_t status;
    if (argc == 3) //write
    {
        i2cOpen();
        data = atoi(argv[2]);
        if(strcmp(argv[1], "write") == 0){
            writeDataReg(data);
            printf("----------------------------\n");
            //printf("Wrote 0x%08X to I2C Data Register.\n", data);
            printf("Wrote %u to I2C Data Register.\n", (unsigned)data);

            //read status after
            status = getStatusReg();
            printStatus(status);

        }
        else if (strcmp(argv[1], "writectl") == 0){
            writeControlReg(data);
            printf("----------------------------\n");
            //printf("Wrote 0x%08X to I2C Control Register.\n", data);
            printf("Wrote %u to the Control Register.\n", (unsigned)data);

            uint32_t ctl = readControlReg();
            printf("I2C Control Register now: 0x%08X\n", ctl);
            //byte count in bits 1-4
            printf("R/~W=%u Byte Count=%u Use_Reg=%u Use_repeated_start=%u Start=%u Test_out=%u\n",
                (unsigned)((ctl >> 0) & 1),
                (unsigned)((ctl >> 1) & 0xF),
                (unsigned)((ctl >> 5) & 1),
                (unsigned)((ctl >> 6) & 1),
                (unsigned)((ctl >> 7) & 1),
                (unsigned)((ctl >> 8) & 1));
        }
        else if (strcmp(argv[1], "writeaddr") == 0){
            writeAddressReg(data);
            printf("----------------------------\n");
            //printf("Wrote 0x%08X to I2C Address Register.\n", data);
            printf("Wrote %u to the Address Register.\n", (unsigned)data);

            uint32_t addr = readAddressReg();
            printf("I2C Address Register now: 0x%08X\n", addr);
        }
        else if (strcmp(argv[1], "writereg") == 0){
            writeRegister(data);
            printf("----------------------------\n");
            //printf("Wrote 0x%08X to I2C Register.\n", data);
            printf("Wrote %u to the Register.\n", (unsigned)data);

            uint32_t reg = readRegister();
            printf("I2C Register now: 0x%08X\n", reg);
        }

    }
    else if(argc == 2) //read
    {
        i2cOpen();
        if(strcmp(argv[1], "read") == 0){
            data = readDataReg();
            printf("----------------------------\n");

            //printf("Read 0x%08X from I2C Data Register.\n", data);
            printf("Read %u from I2C Data Register.\n", (unsigned)data);

            //read status after
            status = getStatusReg();
            printStatus(status);
        }
        else if (strcmp(argv[1], "status") == 0) {
            status = getStatusReg();
            printf("----------------------------\n");

            printStatus(status);
        }
        else if(strcmp(argv[1], "cleartx") == 0){
            //clear the overflow by writing 1 to bit 3 of the status register
            writeStatusReg(0x00000008); // write 1 to bit 3
            printf("----------------------------\n");
            printf("Overflow Cleared.\n");

            uint32_t status = getStatusReg();
            printStatus(status);

        }
        else if (strcmp(argv[1], "clearrx") == 0){
            //clear the overflow by writing 1 to bit 0 of the status register
            writeStatusReg(0x00000001); // write 1 to bit 0
            printf("----------------------------\n");
            printf("Overflow Cleared.\n");

            uint32_t status = getStatusReg();
            printStatus(status);
        }
        else if (strcmp(argv[1], "clearack") == 0){
            //clear the ack error by writing 1 to bit 6 of the status register
            writeStatusReg(0x00000040); // write 1 to bit 6
            printf("----------------------------\n");
            printf("ACK Error Cleared.\n");

            uint32_t status = getStatusReg();
            printStatus(status);
        }
        else if (strcmp(argv[1], "testout") == 0){
            //set the test output bit by writing 1 to bit 8 of the control register
            writeControlReg(0x00000100); // write 1 to bit 8
            printf("----------------------------\n");
            printf("Test Output Bit Set.\n");

            uint32_t status = getStatusReg();
            printStatus(status);
        }
        else if(strcmp(argv[1], "testoff") == 0){
            //clear the test output bit by writing 0 to bit 8 of the control register
            writeControlReg(0x00000000); // write 0 to bit 8
            printf("----------------------------\n");
            printf("Test Output Bit Cleared.\n");

            uint32_t status = getStatusReg();
            printStatus(status);
        }
        else if(strcmp(argv[1], "control") == 0){
            uint32_t ctl = readControlReg();
            printf("----------------------------\n");
            printf("I2C Control Register: 0x%08X\n", ctl);
            //byte count in bits 1-4
            printf("R/~W=%u Byte Count=%u Use_Reg=%u Use_repeated_start=%u Start=%u Test_out=%u\n",
                (unsigned)((ctl >> 0) & 1),
                (unsigned)((ctl >> 1) & 0xF),
                (unsigned)((ctl >> 5) & 1),
                (unsigned)((ctl >> 6) & 1),
                (unsigned)((ctl >> 7) & 1),
                (unsigned)((ctl >> 8) & 1));
        }
        else if(strcmp(argv[1], "readaddr") == 0){
            uint32_t addr = readAddressReg();
            printf("----------------------------\n");
            printf("I2C Address Register: 0x%08X\n", addr);
        }
        else if(strcmp(argv[1], "readreg") == 0){
            uint32_t reg = readRegister();
            printf("----------------------------\n");
            printf("I2C Register: 0x%08X\n", reg);
        }
        else if(strcmp(argv[1], "test") == 0){
            printf("Before write operation:\n");
            uint32_t status = getStatusReg();
            printf("I2C Status Register: 0x%08X\n", status);
            printf("TXFO=%u TXFF=%u TXFE=%u  wr=%u rd=%u\n",
                (unsigned)((status >> 3) & 1),
                (unsigned)((status >> 4) & 1),
                (unsigned)((status >> 5) & 1),
                (unsigned)((status >> 8) & 0xF),
                (unsigned)((status >> 12) & 0xF));

            writeDataReg(10);
            printf("After write operation:\n");
            status = getStatusReg();
            printf("I2C Status Register: 0x%08X\n", status);
            printf("TXFO=%u TXFF=%u TXFE=%u  wr=%u rd=%u\n",
                (unsigned)((status >> 3) & 1),
                (unsigned)((status >> 4) & 1),
                (unsigned)((status >> 5) & 1),
                (unsigned)((status >> 8) & 0xF),
                (unsigned)((status >> 12) & 0xF));

            
            uint32_t data = readDataReg();
            printf("I2C Data Register: 0x%08X\n", data);
            status = getStatusReg();
            printf("After read operation:\n");
            printf("I2C Status Register: 0x%08X\n", status);
            printf("TXFO=%u TXFF=%u TXFE=%u  wr=%u rd=%u\n",
                    (unsigned)((status >> 3) & 1),
                    (unsigned)((status >> 4) & 1),
                    (unsigned)((status >> 5) & 1),
                    (unsigned)((status >> 8) & 0xF),
                    (unsigned)((status >> 12) & 0xF));

            //continue to write until fifo full
            for (int i = 0; i < 15; i++){
                writeDataReg(i);
                status = getStatusReg();
                printf("After write %d operation:\n", i+1);
                printf("I2C Status Register: 0x%08X\n", status);
                printf("TXFO=%u TXFF=%u TXFE=%u  wr=%u rd=%u\n",
                    (unsigned)((status >> 3) & 1),
                    (unsigned)((status >> 4) & 1),
                    (unsigned)((status >> 5) & 1),
                    (unsigned)((status >> 8) & 0xF),
                    (unsigned)((status >> 12) & 0xF));
                usleep(400000); // Sleep for 400 ms
            }
            writeDataReg(0x0000000F);
            printf("After write 16 operation (should be overflow):\n");
            status = getStatusReg();
            printf("I2C Status Register: 0x%08X\n", status);
            printf("TXFO=%u TXFF=%u TXFE=%u  wr=%u rd=%u\n",
                (unsigned)((status >> 3) & 1),
                (unsigned)((status >> 4) & 1),
                (unsigned)((status >> 5) & 1),
                (unsigned)((status >> 8) & 0xF),
                (unsigned)((status >> 12) & 0xF));   
        }
    }
    else
        printf("  command not recognized.\n");

    return EXIT_SUCCESS;
}
