# -*- mode: Assembly -*-
.include "rp2350.h"

.global gpio_read, gpio_set, gpio_clear
.global gpio_set_output, gpio_set_input, gpio_set_function, gpio_set_pad

# ------------------------------------------------------------------------------
.section .text
.align 2

# GPIO helpers for the RP2350 SIO block.
#
# These routines drive or sample the low 32 GPIO pins (0-31) through the
# SIO GPIO registers.  A pin must first be switched to the SIO function
# (GPIO_FUNC_SIO in its IO_BANK0 GPIO_CTRL register) and, for outputs, have
# its output enable set (gpio_set_output) before gpio_set/gpio_clear will
# drive the pad.  gpio_read samples the pad regardless of direction.
#
# All routines are leaf functions: they use only caller-saved registers and
# do not touch the stack, so no frame is needed.



# ------------------------------------------------------------------------------
# Read the current input level of GPIO n.
#
# In:
#   * a0: GPIO number (0-31)
#
# Out:
#   * a0: 1 if the pin is high, 0 if low
#
# Register map:
#   * t0: SIO base / input bitmask
gpio_read:
        li t0, SIO_BASE
        lw t0, SIO_GPIO_IN(t0)      # read all 32 input levels
        srl t0, t0, a0              # move bit n to bit 0
        andi a0, t0, 1              # isolate it
        ret

# ------------------------------------------------------------------------------
# Drive GPIO n high (set its output value to 1).
#
# In:
#   * a0: GPIO number (0-31)
#
# Register map:
#   * t0: bitmask for GPIO n
#   * t1: SIO base
gpio_set:
        li t0, 1
        sll t0, t0, a0              # t0 = 1 << n
        li t1, SIO_BASE
        sw t0, SIO_GPIO_OUT_SET(t1) # set only bit n, leave others alone
        ret

# ------------------------------------------------------------------------------
# Drive GPIO n low (set its output value to 0).
#
# In:
#   * a0: GPIO number (0-31)
#
# Register map:
#   * t0: bitmask for GPIO n
#   * t1: SIO base
gpio_clear:
        li t0, 1
        sll t0, t0, a0              # t0 = 1 << n
        li t1, SIO_BASE
        sw t0, SIO_GPIO_OUT_CLR(t1) # clear only bit n, leave others alone
        ret

# ------------------------------------------------------------------------------
# Enable the output driver for GPIO n (set its output-enable bit).
#
# In:
#   * a0: GPIO number (0-31)
#
# Register map:
#   * t0: bitmask for GPIO n
#   * t1: SIO base
gpio_set_output:
        li t0, 1
        sll t0, t0, a0              # t0 = 1 << n
        li t1, SIO_BASE
        sw t0, SIO_GPIO_OE_SET(t1)  # enable output only for bit n
        ret

# ------------------------------------------------------------------------------
# Disable the output driver for GPIO n (clear its output-enable bit), leaving
# the pin as an input.
#
# In:
#   * a0: GPIO number (0-31)
#
# Register map:
#   * t0: bitmask for GPIO n
#   * t1: SIO base
gpio_set_input:
        li t0, 1
        sll t0, t0, a0              # t0 = 1 << n
        li t1, SIO_BASE
        sw t0, SIO_GPIO_OE_CLR(t1)  # disable output only for bit n
        ret

# ------------------------------------------------------------------------------
# Select the pad function for GPIO n in its IO_BANK0 GPIO_CTRL register.
#
# A pin is not connected to the SIO block until its function is set to
# GPIO_FUNC_SIO; until then gpio_set/gpio_clear have no effect on the pad.
# Call this before gpio_set_output for any pin driven through the SIO block.
#
# In:
#   * a0: GPIO number (0-31)
#   * a1: function select value (e.g. GPIO_FUNC_SIO)
#
# Register map:
#   * t0: IO_BANK0 base
#   * t1: GPIO_CTRL address for GPIO n
gpio_set_function:
        li t0, IO_BANK0_BASE
        sh3add t1, a0, t0           # each GPIO_CTRL is 8 bytes apart
        addi t1, t1, GPIO_CTRL_BASE
        sw a1, 0(t1)                # select the pad function
        ret

# ------------------------------------------------------------------------------
# Configure the pad control for GPIO n in PADS_BANK0.
#
# RP2350 pads come out of reset with isolation enabled, so the pad drives
# nothing until this register is written (clearing the ISO bit).  Pass
# PADS_OUTPUT_4MA for a normal 3.3 V push-pull output.  Call this before
# gpio_set_output for any pin driven through the SIO block.
#
# In:
#   * a0: GPIO number (0-31)
#   * a1: pad control value (e.g. PADS_OUTPUT_4MA)
#
# Register map:
#   * t0: PADS_BANK0 base
#   * t1: pad control address for GPIO n
gpio_set_pad:
        li t0, PADS_BANK0_BASE
        sh2add t1, a0, t0           # each pad control is 4 bytes apart
        addi t1, t1, PADS_GPIO_BASE
        sw a1, 0(t1)                # de-isolate and configure the pad
        ret
