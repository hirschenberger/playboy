.include "rp2350.h"
.include "macros.h"

.global main, delay_ms

# ------------------------------------------------------------------------------
.section .text
.align 2
.type main, @function

main:
        call lcd_init

        LOG_STRING console_boot_message

        li a0, 0xffbb                 # RGB565 dark grey
        call lcd_clear

        li a0, 20
        call draw_title

        li a0, 28
        li a1, PADS_OUTPUT_4MA
        call gpio_set_pad
        li a1, GPIO_FUNC_SIO
        call gpio_set_function
        call gpio_set_output

        li a0, 27
        li a1, PADS_OUTPUT_4MA
        call gpio_set_pad
        li a1, GPIO_FUNC_SIO
        call gpio_set_function
        call gpio_set_output

        li a0, 26
        li a1, PADS_INPUT_4MA
        call gpio_set_pad
        li a1, GPIO_FUNC_SIO
        call gpio_set_function
        call gpio_set_input

        li s2, -1                  # previous byte, force first print

block:
        # Latch parallel data: SH/LD LOW loads inputs, HIGH enables shifting.
        # The 74HC165 needs a minimum SH/LD LOW pulse (~30-40ns at 3.3V);
        # at 150 MHz a couple of nops is too short, so use a real delay.
        li a0, 28
        call gpio_clear            # SH/LD = LOW (load)
        li a0, 28
        call gpio_set              # SH/LD = HIGH (shift mode, bit 0 at Q7)

        li s0, 0                  # accumulated byte
        li s1, 8                  # bit counter
read_cycle:
        # Read Q7 before clocking: the first bit is ready at the SH/LD
        # rising edge, each later bit after the CLK rising edge.
        li a0, 26
        call gpio_read
        slli s0, s0, 1            # make room for the new bit
        or s0, s0, a0             # insert bit, MSB first

        # Pulse CLK to shift the next bit to Q7.
        li a0, 27
        call gpio_set             # CLK rising edge
        nop
        nop
        call gpio_clear           # CLK low again

        addi s1, s1, -1
        bnez s1, read_cycle

        # Print the byte only when it changes, so the console stays quiet
        # until a button is pressed or released.
        beq s0, s2, no_change
        mv s2, s0
        mv a0, s0
        call itoa
        call uart_write_string
        li a0, '\n'
        call uart_write_byte
no_change:

        li a0, 500
        call delay_ms
        j block


        call gameloop

        LOG_STRING exit_game

        wfi




# ------------------------------------------------------------------------------
.section .rodata
console_boot_message:
        .ascii  "    **************************************\n"
        .ascii  "    * Pico 2 RISC-V LCD firmware started *\n"
        .asciz  "    **************************************"

exit_game:
        .ascii  "    **************************************\n"
        .ascii  "    *      Emergency exit firmware       *\n"
        .asciz  "    **************************************"
