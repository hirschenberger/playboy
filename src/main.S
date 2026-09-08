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

    la s1, rainbow_colors         # colortable ptr
    la s2, rainbow_colors_end     # colortable end ptr
1:
    li a0, 20
    li a1, 80
    li a2, 280
    li a3, 10
    lhu a4, 0(s1)
    call fill_rect

    li a0, 20
    li a1, 104
    la a2, hello_text
    mv a3, s1                  # current colortable pointer
    li a4, 3
    call draw_rainbow_string

    li a0, 20
    li a1, 140
    li a2, 280
    li a3, 10
    lhu a4, 0(s1)
    call fill_rect

    li a0, 15
    call delay_ms

    # Move the rainbow phase backward by one RGB565 entry per frame.
    addi s1, s1, -2
    la t0, rainbow_colors
    bgeu s1, t0, 1b

    # The decrement passed the first entry; wrap to the final entry.
    addi s1, s2, -2

    j 1b



.section .rodata
console_boot_message:
    .ascii  "**************************************\n"
    .ascii  "* Pico 2 RISC-V LCD firmware started *\n"
    .asciz  "**************************************\n"

hello_text:
    # .asciz "KOPF HOCH VALLI!"
    .asciz   "   TAKE FIVE    "
