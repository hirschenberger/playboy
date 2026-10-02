.include "rp2350.h"
.include "macros.h"

.global main, delay_ms

# ------------------------------------------------------------------------------
.section .text

main:
        call lcd_init

        LOG_STRING console_boot_message

        li a0, 0x0000                 # RGB565 black
        call lcd_clear

        li a0, 20
        call draw_title

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
