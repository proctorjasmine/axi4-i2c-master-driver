# axi4-i2c-master-driver
# AXI4-Lite I2C Master with Linux Driver

This project implements a custom I2C master IP core with an AXI4-Lite interface, designed for use on a Xilinx Zynq-based system. The core supports register-based control of I2C transactions, transmit and receive FIFOs, repeated-start operation, ACK error detection, and status reporting through memory-mapped registers.

The project also includes Linux-side software support for controlling and observing the I2C core from user space through a kernel module/sysfs interface.

## Features

- Custom I2C master written in Verilog/SystemVerilog
- AXI4-Lite memory-mapped register interface
- 7-bit I2C addressing
- Register-addressed I2C reads and writes
- Repeated-start support
- TX and RX FIFO support
- ACK error detection
- Busy/status flag reporting
- Linux kernel module for user-space access
- Tested using simulation, on-board debugging, LEDs, and logic analyzer captures

## System Architecture

```text
Linux User Space
      |
      v
Linux Kernel Module / Sysfs Interface
      |
      v
AXI4-Lite Bus
      |
      v
Custom I2C Master IP
      |
      v
I2C Bus
      |
      v
External I2C Peripheral
