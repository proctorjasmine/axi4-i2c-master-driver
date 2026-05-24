# AXI I2C Master Driver

Custom AXI4-Lite I2C master IP core with Linux user-space and kernel-space software support.

This project implements a memory-mapped I2C master peripheral for a Xilinx Zynq / Blackboard system. The design includes a custom Verilog I2C controller, transmit and receive FIFOs, AXI4-Lite register control, user-space `/dev/mem` access, and a Linux sysfs kernel driver interface.

## Features

- Custom I2C master IP core written in Verilog
- AXI4-Lite memory-mapped register interface
- 7-bit I2C addressing
- 100 kbps I2C bus operation
- TX and RX FIFOs
- Register-addressed I2C transactions
- Optional repeated-start support
- ACK error detection
- User-space C test application
- Linux kernel module with sysfs interface
- MCP23008 GPIO expander demo

## Project Background

This project was developed for a System-on-Chip Design course. The goal was to design an I2C master IP core that could be controlled by the hard processor system through an AXI4-Lite interface.

The I2C core communicates with external I2C peripherals using SDA and SCL signals routed through a PMOD connector. A test output signal is also included for debugging the internal timing reference.

## System Architecture

```text
User-Space C App        Linux Kernel Module
      |                         |
      |                         v
      |                  /sys/kernel/i2c
      |                         |
      +-----------+-------------+
                  |
                  v
            AXI4-Lite Bus
                  |
                  v
        Custom I2C Master IP
                  |
                  v
          External I2C Device
```

## Register Map

The I2C IP core uses a 5-word, 20-byte AXI4-Lite register space.

| Offset | Register | Access | Description |
|---|---|---|---|
| `0x00` | `ADDRESS` | R/W | 7-bit I2C device address |
| `0x04` | `REGISTER` | R/W | 8-bit internal register address |
| `0x08` | `DATA` | R/W | Write to TX FIFO or read from RX FIFO |
| `0x0C` | `STATUS` | R/W1C | FIFO flags, ACK error, busy flag, and debug bits |
| `0x10` | `CONTROL` | R/W | Transaction configuration and start control |

## Status Register

| Bit | Name | Description |
|---|---|---|
| `0` | `RXFO` | RX FIFO overflow |
| `1` | `RXFF` | RX FIFO full |
| `2` | `RXFE` | RX FIFO empty |
| `3` | `TXFO` | TX FIFO overflow |
| `4` | `TXFF` | TX FIFO full |
| `5` | `TXFE` | TX FIFO empty |
| `6` | `ACK_ERROR` | ACK error detected |
| `7` | `BUSY` | I2C transaction in progress |
| `31:8` | `DEBUG_IN` | Debug information |

## Control Register

| Bit(s) | Name | Description |
|---|---|---|
| `0` | `R/~W` | `1` = read, `0` = write |
| `4:1` | `BYTE_COUNT` | Number of bytes to read or write |
| `5` | `USE_REGISTER` | Enables internal register addressing |
| `6` | `USE_REPEATED_START` | Enables repeated-start during reads |
| `7` | `START` | Starts an I2C transaction |
| `8` | `TEST_OUT` | Enables test output signal |
| `31:24` | `DEBUG_OUT` | Debug output |

## Software Interfaces

This project includes two ways to control the I2C IP core from Linux.

### User-Space Control

The user-space C application uses `/dev/mem` to access the AXI4-Lite register space.

Example commands:

```bash
./i2c writeaddr 0x20
./i2c writereg 0x00
./i2c write 0x08
./i2c writectl 162
./i2c status
```

### Kernel Sysfs Driver

The Linux kernel module creates a sysfs interface at:

```text
/sys/kernel/i2c
```

Supported files:

| File | Description |
|---|---|
| `mode` | Sets read or write mode |
| `byte_count` | Number of bytes to transfer |
| `register` | Internal I2C device register or `none` |
| `address` | 7-bit I2C device address |
| `use_repeated_start` | Enables or disables repeated start |
| `start` | Starts a transaction |
| `tx_data` | Writes data to the TX FIFO |
| `rx_data` | Reads data from the RX FIFO |

Example sysfs usage:

```bash
echo 0x20 > /sys/kernel/i2c/address
echo 0x00 > /sys/kernel/i2c/register
echo write > /sys/kernel/i2c/mode
echo 8 > /sys/kernel/i2c/tx_data
echo 1 > /sys/kernel/i2c/byte_count
echo 1 > /sys/kernel/i2c/start
```

## MCP23008 Demo

An MCP23008 I2C GPIO expander was used to test the design with external hardware.

The demo uses:

- Pin 0: Red LED
- Pin 1: Green LED
- Pin 3: Pushbutton input with pull-up enabled

The program turns on the red LED, waits for a pushbutton press, then switches to the green LED.

## Repository Structure

```text
.
├── README.md
├── rtl/
│   ├── i2c.v
│   ├── i2c_slave_lite_v2_0_AXI.v
│   └── fifo.v
├── constraints/
│   └── blackboard.xdc
├── software/
│   ├── address_map.h
│   ├── userspace/
│   │   ├── Makefile
│   │   ├── i2c.c
│   │   ├── i2c_ip.c
│   │   ├── i2c_ip.h
│   │   └── i2c_regs.h
│   └── kernel/
│       ├── i2c_driver.c
│       └── Makefile
└── examples/
    ├── stop_go_i2c.c
    └── stop_go_bash.sh
```

## Testing and Verification

Testing included:

- AXI4-Lite register read/write testing
- FIFO empty, full, and overflow testing
- I2C read and write transactions
- ACK error detection
- Repeated-start behavior
- Logic analyzer verification
- MCP23008 GPIO expander hardware demo
- User-space and kernel-space software validation

## Future Improvements

- Add interrupt support
- Add device tree integration
- Add support for additional I2C bus speeds
- Package the IP for easier Vivado reuse

## Notes

This repository is a cleaned and documented portfolio version of a university System-on-Chip Design project.

## Author

Jasmine Proctor
