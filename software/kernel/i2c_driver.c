// I2C DRIVER (i2c_driver.c)
// Jasmine Proctor

//-----------------------------------------------------------------------------
// Hardware Target
//-----------------------------------------------------------------------------

// Target Platform: Xilinx Zynq-7000
//
// Hardware configuration:
//
// AXI4-Lite interface
//   Mapped to offset of 0x20000


//-----------------------------------------------------------------------------
#include <linux/kernel.h>     // kstrtouint
#include <linux/module.h>     // MODULE_ macros
#include <linux/init.h>       // __init
#include <linux/kobject.h>    // kobject, kobject_atribute,

#include <linux/sysfs.h>     // sysfs_create_group
#include <asm/io.h>           // iowrite, ioread, ioremap

#include "../address_map.h"   // overall memory map
#include "i2c_regs.h"         // register offsets in I2C IP 

//-----------------------------------------------------------------------------
// Kernel module information
//-----------------------------------------------------------------------------
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Jasmine Proctor");
MODULE_DESCRIPTION("I2C IP Driver");
//-----------------------------------------------------------------------------
// Global variables
//-----------------------------------------------------------------------------
static unsigned int *base = NULL;
extern struct kobject *kernel_kobj;  
//-----------------------------------------------------------------------------
// Subroutines
//-----------------------------------------------------------------------------

//use repeated start condition on bit 6 of control register
void useRepeatedStart(bool use)
{
    unsigned int control = ioread32(base + OFS_CONTROL);
    if (use)
        control |= (1 << 6);
    else
        control &= ~(1 << 6);
    iowrite32(control, base + OFS_CONTROL);
}

bool isRepeatedStartUsed(void)
{
    return (ioread32(base + OFS_CONTROL) >> 6) & 1;
}

//-----------------------------------------------------------------------------
// Kernel Objects
//-----------------------------------------------------------------------------

//Mode
// write value = read or write
// read = last written value
static int mode = 0;
module_param(mode, int, S_IRUGO);
MODULE_PARM_DESC(mode, " I2C mode: 0 = write, 1 = read");
static ssize_t modeStore(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
{
    if (strncmp(buffer, "write", strlen("write")) == 0)
    {
        mode = 0;
        unsigned int control = ioread32(base + OFS_CONTROL);
        control &= ~1; //clear bit 0 for write
        iowrite32(control, base + OFS_CONTROL);
    }
    else
        if (strncmp(buffer, "read", strlen("read")) == 0)
        {
            mode = 1;
            unsigned int control = ioread32(base + OFS_CONTROL);
            control |= 1; //set bit 0 for read
            iowrite32(control, base + OFS_CONTROL);
        }  
    return count;     
}

static ssize_t modeShow(struct kobject *kobj, struct kobj_attribute *attr, char *buffer)
{
    unsigned int control = ioread32(base + OFS_CONTROL);
    mode = control & 1; //read bit 0
    if (mode == 0)
        strcpy(buffer, "write\n");
    else
        strcpy(buffer, "read\n");
    return strlen(buffer);
}

static struct kobj_attribute modeAttr = __ATTR(mode, 0664, modeShow, modeStore);

// Byte Count
static int byteCount = 0;
module_param(byteCount, int, S_IRUGO);
MODULE_PARM_DESC(byteCount, " Number of bytes to transfer");

static ssize_t byteCountStore(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
{
    int result = kstrtouint(buffer, 0, &byteCount);
    if (result == 0)
    {
        unsigned int control = ioread32(base + OFS_CONTROL); //read current control register
        control &= ~(0x0F << 1); // clear bits [4:1]
        control |= (byteCount & 0x0F) << 1; // set new byte count
        iowrite32(control, base + OFS_CONTROL);
    }
    return count;
}

static ssize_t byteCountShow(struct kobject *kobj, struct kobj_attribute *attr, char *buffer)
{
    unsigned int control = ioread32(base + OFS_CONTROL);
    byteCount = (control >> 1) & 0x0F; // extract bits [4:1]
    return sprintf(buffer, "%d\n", byteCount);
}

static struct kobj_attribute byteCountAttr = __ATTR(byte_count, 0664, byteCountShow, byteCountStore);


// Register
// 8 bit number to register regsister
//if "none" is written, no register is used (make sure to set bit 5 of control register to 0)
// if any value is written, that value is used as register (make sure to set bit 5 of control register to 1)
static int i2c_register = 0;
module_param(i2c_register, int, S_IRUGO);
MODULE_PARM_DESC(i2c_register, " Register for i2c");

static ssize_t registerStore(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
{
    if (strncmp(buffer, "none", strlen("none")) == 0)
    {
        //clear bit 5 of control register
        unsigned int control = ioread32(base + OFS_CONTROL);
        control &= ~(1 << 5);
        iowrite32(control, base + OFS_CONTROL);
    }
    else
    {
        int result = kstrtouint(buffer, 0, &i2c_register);
        if (result == 0)
        {
            iowrite32(i2c_register & 0xFF   , base + OFS_REGISTER); //write only 8 bits
            unsigned int control = ioread32(base + OFS_CONTROL);
            control |= (1 << 5); //enable bit 5 of control register
            iowrite32(control, base + OFS_CONTROL);
        }
    }
    return count;
}

// static ssize_t registerStore(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
// {
//     int result = kstrtouint(buffer, 0, &i2c_register);
//     if (result == 0)
//     {
//         iowrite32(i2c_register & 0xFF   , base + OFS_REGISTER); //write only 8 bits
//     }
//     return count;
// }

static ssize_t registerShow(struct kobject *kobj, struct kobj_attribute *attr, char *buffer)
{
    i2c_register = ioread32(base + OFS_REGISTER) & 0xFF; //make sure to read only 8 bits
    return sprintf(buffer, "%d\n", i2c_register);
}

static struct kobj_attribute registerAttr = __ATTR(register, 0664, registerShow, registerStore);

// Address
// 7 bit address for i2c device
static int address = 0;
module_param(address, int, S_IRUGO);
MODULE_PARM_DESC(address, " Address for i2c ");

static ssize_t addressStore(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
{
    int result = kstrtouint(buffer, 0, &address);
    if (result == 0)
    {
        iowrite32(address & 0x7F   , base + OFS_ADDRESS); //write only 7 bits
    }
    return count;
}

static ssize_t addressShow(struct kobject *kobj, struct kobj_attribute *attr, char *buffer)
{
    address = ioread32(base + OFS_ADDRESS) & 0x7F; //make sure to read only 7 bits
    return sprintf(buffer, "%d\n", address);
}

static struct kobj_attribute addressAttr = __ATTR(address, 0664, addressShow, addressStore);

// Use Repeated Start
// bit 6 of control register
static bool repeatedStart = 0;
module_param(repeatedStart, bool, S_IRUGO);
MODULE_PARM_DESC(repeatedStart, " Use repeated start condition");

static ssize_t repeatedStartStore(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
{
    if (strncmp(buffer, "true", strlen("true")) == 0)
    {
        repeatedStart = true;
        useRepeatedStart(repeatedStart);
    }
    else
        if (strncmp(buffer, "false", strlen("false")) == 0)
        {
            repeatedStart = false;
            useRepeatedStart(repeatedStart);
        }
    return count;
}

static ssize_t repeatedStartShow(struct kobject *kobj, struct kobj_attribute *attr, char *buffer)
{
    repeatedStart = isRepeatedStartUsed();
    if (repeatedStart)
        strcpy(buffer, "true\n");
    else
        strcpy(buffer, "false\n");

    return strlen(buffer);
}

static struct kobj_attribute useRepeatedStartAttr = __ATTR(use_repeated_start, 0664, repeatedStartShow, repeatedStartStore);

//Start
// any write to control register bit 7 starts transaction
// read shows start status

static ssize_t startStore(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
{
    unsigned int control = ioread32(base + OFS_CONTROL);
    control |= (1 << 7); //set bit 7 to start transaction
    iowrite32(control, base + OFS_CONTROL);
    return count;
}

static ssize_t startShow(struct kobject *kobj, struct kobj_attribute *attr, char *buffer)
{
    unsigned int control = ioread32(base + OFS_CONTROL);
    int startStatus = (control >> 7) & 1; //read bit 7
    if (startStatus == 1)
        strcpy(buffer, "1\n");
    else
        strcpy(buffer, "0\n");
    return strlen(buffer);
}

static struct kobj_attribute startAttr = __ATTR(start, 0664, startShow, startStore);

//Tx Data
// write: value for tx-fifo
// read : n/a
//(use data register)
// 8 bit data to send over i2c
static int txData = 0;

static ssize_t txDataStore(struct kobject *kobj, struct kobj_attribute *attr, const char *buffer, size_t count)
{
    int result = kstrtouint(buffer, 0, &txData);
    if (result == 0)
    {
        iowrite32(txData & 0xFF   , base + OFS_DATA); //write only 8 bits
    }
    return count;
}

static struct kobj_attribute txDataAttr = __ATTR(tx_data, 0220, NULL, txDataStore);

//Rx Data
// write: n/a
// read : value in fifo, or -1 if empty
// read from data register

static ssize_t rxDataShow(struct kobject *kobj, struct kobj_attribute *attr, char *buffer)
{
    //rx fifo empty check (bit 2 of status register)
    if ((ioread32(base + OFS_STATUS) >> 2) & 1)
    {
        return sprintf(buffer, "-1\n");
    }
    int rxData = ioread32(base + OFS_DATA) & 0xFF; //make sure to read only 8 bits
    return sprintf(buffer, "%d\n", rxData);
}
static struct kobj_attribute rxDataAttr = __ATTR(rx_data, 0444, rxDataShow, NULL);

// Attributes
static struct attribute *attrs[] = {&modeAttr.attr, &byteCountAttr.attr, &registerAttr.attr,
    &addressAttr.attr, &useRepeatedStartAttr.attr, &startAttr.attr,
    &txDataAttr.attr, &rxDataAttr.attr, NULL};

static struct attribute_group group = 
{
    //.name = "i2c", removing to avoid having i2c/i2c in path
    .attrs = attrs
};

static struct kobject *kobj;

//-----------------------------------------------------------------------------
// Initialization and Exit
//-----------------------------------------------------------------------------

static int __init i2cDriverInit(void)
{


    printk(KERN_INFO "I2C driver: starting\n");


    // Create directory under /sys/kernel
    kobj = kobject_create_and_add("i2c", kernel_kobj);
    if (!kobj)
    {
        printk(KERN_ALERT "I2C driver: failed to create and add kobj\n");
        return -ENOMEM;
    }

    // Create group
    int result = sysfs_create_group(kobj, &group);
    if (result)
    {
        return result;
    }

    // Map I2C IP core into virtual address space
    base = (unsigned int *)ioremap(AXI4_LITE_BASE + I2C_BASE_OFFSET,
                                          SPAN_IN_BYTES);
    if (base == NULL)
    {
        return -ENOMEM;
    }

    printk(KERN_INFO "i2c driver: initialized\n");
    return 0;
}

static void __exit exit_module(void)
{
    kobject_put(kobj);
    printk(KERN_INFO "I2C driver: exit\n");
}

module_init(i2cDriverInit);
module_exit(exit_module);

