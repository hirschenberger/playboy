#include "rp2350.h"

.section .text
.align 2
.global main, delay_ms
.type main, @function

main:
    call lcd_init

    la a0, console_boot_message
    call uart_write_string

    li a0, 0xffbb                 # RGB565 dark grey
    call lcd_clear

    li a0, 2000
    call draw_title
1:
    li a0, 0xffff                 # RGB565 dark grey
    call lcd_clear
    j 1b



.section .rodata
console_boot_message:
    .ascii  "    **************************************\n"
    .ascii  "    * Pico 2 RISC-V LCD firmware started *\n"
    .asciz  "    **************************************\n"

