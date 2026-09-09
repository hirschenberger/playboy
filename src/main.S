#include "rp2350.h"
#include "macros.h"

.section .text
.align 2
.global main, delay_ms
.type main, @function

main:
    call lcd_init

    LOG_STRING console_boot_message

    li a0, 0xffbb                 # RGB565 dark grey
    call lcd_clear

    # li a0, 2000
    # call draw_title

    li a0, 0xffff                 # RGB565 dark grey
    call lcd_clear

    call gameloop

    LOG_STRING exit_game

    wfi




.section .rodata
console_boot_message:
    .ascii  "    **************************************\n"
    .ascii  "    * Pico 2 RISC-V LCD firmware started *\n"
    .asciz  "    **************************************"

exit_game:
    .ascii  "    **************************************\n"
    .ascii  "    *      Emergency exit firmware       *\n"
    .asciz  "    **************************************"
