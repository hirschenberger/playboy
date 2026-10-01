.include "rp2350.h"
.include "joypad.h"
.include "macros.h"

.global init_joypad, read_joypad

.equ SHIFTREG_LOAD_GPIO, 28
.equ SHIFTREG_CLOCK_GPIO, 27
.equ SHIFTREG_DATA_GPIO, 26

# ------------------------------------------------------------------------------
.section .text
.align 2

# ------------------------------------------------------------------------------
# Initialize the joypad GPIOs to use a 74HC165 shift register to readout the
# button state
init_joypad:
        addi sp, sp, -16
        sw ra, 12(sp)

        li a0, SHIFTREG_LOAD_GPIO
        li a1, PADS_OUTPUT_4MA
        call gpio_set_pad
        li a1, GPIO_FUNC_SIO
        call gpio_set_function
        call gpio_set_output

        li a0, SHIFTREG_CLOCK_GPIO
        li a1, PADS_OUTPUT_4MA
        call gpio_set_pad
        li a1, GPIO_FUNC_SIO
        call gpio_set_function
        call gpio_set_output

        li a0, SHIFTREG_DATA_GPIO
        li a1, PADS_INPUT_4MA
        call gpio_set_pad
        li a1, GPIO_FUNC_SIO
        call gpio_set_function
        call gpio_set_input

        la t0, joypad_state
        sb zero, 0(t0)    # init initial state

        lw ra, 12(sp)
        addi sp, sp, 16
        ret


# ------------------------------------------------------------------------------
# Read the current joypad state . It returns two values:
#
# Out:
#   * a0: The current button state
#   * a1: A mask with the buttons that changed since the last poll
read_joypad:
        addi sp, sp, -16
        sw ra, 12(sp)
        sw s0, 8(sp)
        sw s1, 4(sp)
        sw s2, 0(sp)

        LOAD_BYTE s2, joypad_state   # previous byte, force first print

        # Latch parallel data: SH/LD LOW loads inputs, HIGH enables shifting.
        # The 74HC165 needs a minimum SH/LD LOW pulse (~6ns at 3.3V);
        # The function calls take longer than this, so it should be safe without
        # explicit delay
        li a0, SHIFTREG_LOAD_GPIO
        call gpio_clear            # SH/LD = LOW (load)

        li a0, SHIFTREG_LOAD_GPIO
        call gpio_set              # SH/LD = HIGH (shift mode, bit 0 at Q7)

        li s0, 0                  # accumulated byte
        li s1, 8                  # bit counter
.Lread_cycle:
        # Read Q7 before clocking: the first bit is ready at the SH/LD
        # rising edge, each later bit after the CLK rising edge.
        li a0, SHIFTREG_DATA_GPIO
        call gpio_read
        slli s0, s0, 1            # make room for the new bit
        or s0, s0, a0             # insert bit, MSB first

        # Pulse CLK to shift the next bit to Q7.
        li a0, SHIFTREG_CLOCK_GPIO
        # no delay needed here, the function calls take longer to make the
        # clock cycle reliable.
        call gpio_set             # CLK rising edge
        call gpio_clear           # CLK low again

        addi s1, s1, -1
        bnez s1, .Lread_cycle

        STORE_BYTE s0, joypad_state, t0
        mv a0, s0
        xor a1, s0, s2

        lw ra, 12(sp)
        lw s0, 8(sp)
        lw s1, 4(sp)
        lw s2, 0(sp)
        addi sp, sp, 16
        ret

# ------------------------------------------------------------------------------
.section .bss
.align 1

joypad_state: .space 1
