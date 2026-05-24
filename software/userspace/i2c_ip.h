// I2C IP Example
// I2C IP Library (i2c_ip.h)
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

#ifndef I2C_H_
#define I2C_H_

#include <stdint.h>
#include <stdbool.h>

//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

bool i2cOpen(void);

uint32_t getStatusReg(void);
void writeDataReg(uint32_t data);
uint32_t readDataReg(void);
void writeStatusReg(uint32_t data);
void writeControlReg(uint32_t data);
uint32_t readControlReg(void);
void writeAddressReg(uint32_t data);
uint32_t readAddressReg(void);
void writeRegister(uint32_t data);
uint32_t readRegister(void);
#endif
