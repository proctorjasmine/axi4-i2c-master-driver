// I2C IP Example
// I2C IP Library (i2c_ip.c)
// Jasmine Proctor

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: Xilinx XUP Blackboard

// AXI4-Lite interface: 
//   Mapped to offset of 0
//

//-----------------------------------------------------------------------------


#include <stdint.h>          // C99 integer types -- uint32_t
#include <stdbool.h>         // bool
#include <fcntl.h>           // open
#include <sys/mman.h>        // mmap
#include <unistd.h>          // close
#include "../address_map.h"  // address map
#include "i2c_ip.h"         // i2c
#include "i2c_regs.h"       // registers

//-----------------------------------------------------------------------------
// Global variables
//-----------------------------------------------------------------------------

uint32_t *base = NULL;

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

bool i2cOpen()
{
    // Open /dev/mem
    int file = open("/dev/mem", O_RDWR | O_SYNC);
    bool bOK = (file >= 0);
    if (bOK)
    {
        // Create a map from the physical memory location of
        // /dev/mem at an offset to LW avalon interface
        // with an aperature of SPAN_IN_BYTES bytes
        // to any location in the virtual 32-bit memory space of the process
        //void *map = mmap(NULL, SPAN_IN_BYTES, PROT_READ | PROT_WRITE, MAP_SHARED,
        //            file, AXI4_LITE_BASE + I2C_BASE_OFFSET);
        base = mmap(NULL, SPAN_IN_BYTES, PROT_READ | PROT_WRITE, MAP_SHARED,
                   file, AXI4_LITE_BASE + I2C_BASE_OFFSET);
        //base = ( volatile uint32_t *)map;
        bOK = (base != MAP_FAILED);

        // Close /dev/mem
        close(file);
    }
    return bOK;
}

uint32_t getStatusReg()
{
    uint32_t status = *(base + OFS_STATUS);
    //uint32_t status = base[OFS_STATUS];
    return status;
}

void writeDataReg(uint32_t data)
{
    *(base + OFS_DATA) = data;
    //base[OFS_DATA] = data;
}

uint32_t readDataReg()
{
    uint32_t data = *(base + OFS_DATA);
    //uint32_t data = base[OFS_DATA];
    return data;
}

void writeStatusReg(uint32_t data)
{
    *(base + OFS_STATUS) = data;
    //base[OFS_STATUS] = data;
}

void writeControlReg(uint32_t data)
{
    *(base + OFS_CONTROL) = data;
    //base[OFS_CONTROL] = data;
}

uint32_t readControlReg()
{
    uint32_t control = *(base + OFS_CONTROL);
    return control;
}

void writeAddressReg(uint32_t data)
{
    *(base + OFS_ADDRESS) = data;
    //base[OFS_ADDRESS] = data;
}

uint32_t readAddressReg()
{
    uint32_t address = *(base + OFS_ADDRESS);
    return address;
}

void writeRegister(uint32_t data)
{
    *(base + OFS_REGISTER) = data;
    //base[OFS_REGISTER] = data;
}

uint32_t readRegister()
{
    uint32_t reg = *(base + OFS_REGISTER);
    return reg;
}
