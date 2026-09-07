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

    li a0, 10
    call delay_ms

    # Move the rainbow phase backward by one RGB565 entry per frame.
    addi s1, s1, -2
    la t0, rainbow_colors
    bgeu s1, t0, 1b

    # The decrement passed the first entry; wrap to the final entry.
    addi s1, s2, -2

    j 1b


# a0=RGB565 color, a1=pixel count. set_window must already have selected LCD.
write_color:
    srli t2, a0, 8
    andi t3, a0, 0xff
    li t0, SPI1_BASE
0:
    beqz a1, 4f
    # The RP2350 SPI FIFO holds eight bytes. Send up to four pixels before
    # draining their matching RX bytes, keeping the transmitter full safely.
    li t4, 4
    bge a1, t4, 1f
    mv t4, a1
1:
    mv t5, t4
2:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_TNF
    beqz t1, 2b
    sh t2, SPI_DR(t0)
3:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_TNF
    beqz t1, 3b
    sh t3, SPI_DR(t0)
    addi t5, t5, -1
    bnez t5, 2b

    slli t5, t4, 1
5:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_RNE
    beqz t1, 5b
    lw t1, SPI_DR(t0)
    addi t5, t5, -1
    bnez t5, 5b
    sub a1, a1, t4
    j 0b
4:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_BSY
    bnez t1, 4b
    li t0, SIO_BASE
    li t1, LCD_CS_MASK
    sw t1, SIO_GPIO_OUT_SET(t0)
    ret



# a0=color. Clear all 320*240 pixels.
lcd_clear:
    addi sp, sp, -16
    .equ LCD_CLEAR_RA, 12
    .equ LCD_CLEAR_COLOR, 8
    sw ra, LCD_CLEAR_RA(sp)
    sw a0, LCD_CLEAR_COLOR(sp)
    li a0, 0
    li a1, SCREEN_WIDTH - 1
    li a2, 0
    li a3, SCREEN_HEIGHT - 1
    call set_window

    lw a0, LCD_CLEAR_COLOR(sp)
    li a1, SCREEN_WIDTH * SCREEN_HEIGHT
    call write_color

    lw ra, LCD_CLEAR_RA(sp)
    addi sp, sp, 16
    ret

# a0=x, a1=y, a2=width, a3=height, a4=RGB565.
fill_rect:
    addi sp, sp, -32
    .equ FILL_RECT_RA, 28
    .equ FILL_RECT_WIDTH, 24
    .equ FILL_RECT_HEIGHT, 20
    .equ FILL_RECT_COLOR, 16
    sw ra, FILL_RECT_RA(sp)
    sw a2, FILL_RECT_WIDTH(sp)
    sw a3, FILL_RECT_HEIGHT(sp)
    sw a4, FILL_RECT_COLOR(sp)

    add t0, a0, a2
    addi t0, t0, -1
    add t1, a1, a3
    addi t1, t1, -1
    mv a2, a1
    mv a1, t0
    mv a3, t1
    call set_window
    lw a0, FILL_RECT_COLOR(sp)
    lw t0, FILL_RECT_WIDTH(sp)
    lw t1, FILL_RECT_HEIGHT(sp)
    mul a1, t0, t1
    call write_color

    lw ra, FILL_RECT_RA(sp)
    addi sp, sp, 32
    ret


# a0=x, a1=y, a2=NUL-terminated ASCII, a3=colortable, a4=scale.
# Each glyph uses the next RGB565 entry, wrapping at the end of the table.
draw_rainbow_string:
    addi sp, sp, -48
    .equ RAINBOW_STRING_RA, 44
    .equ RAINBOW_STRING_X, 40
    .equ RAINBOW_STRING_Y, 36
    .equ RAINBOW_STRING_TEXT, 32
    .equ RAINBOW_STRING_COLORS, 28
    .equ RAINBOW_STRING_SCALE, 24
    .equ RAINBOW_CURRENT_COLOR_PTR, 20
    sw ra, RAINBOW_STRING_RA(sp)
    sw a0, RAINBOW_STRING_X(sp)
    sw a1, RAINBOW_STRING_Y(sp)
    sw a2, RAINBOW_STRING_TEXT(sp)
    sw a3, RAINBOW_STRING_COLORS(sp)
    sw a4, RAINBOW_STRING_SCALE(sp)
    sw a3, RAINBOW_CURRENT_COLOR_PTR(sp)

0:
    lw t0, RAINBOW_STRING_TEXT(sp)
    lbu t1, 0(t0)
    beqz t1, 2f
    lw a0, RAINBOW_STRING_X(sp)
    lw a1, RAINBOW_STRING_Y(sp)
    lw a2, RAINBOW_CURRENT_COLOR_PTR(sp)
    lw a3, RAINBOW_STRING_SCALE(sp)
    mv a4, t1
    call draw_rainbow_char
    sw a0, RAINBOW_CURRENT_COLOR_PTR(sp)

    lw t0, RAINBOW_STRING_SCALE(sp)
    li t1, 6
    mul t1, t1, t0             # five glyph columns plus one spacing column
    lw t2, RAINBOW_STRING_X(sp)
    add t2, t2, t1
    sw t2, RAINBOW_STRING_X(sp)
    lw t0, RAINBOW_STRING_TEXT(sp)
    addi t0, t0, 1
    sw t0, RAINBOW_STRING_TEXT(sp)
    j 0b
2:
    lw a0, RAINBOW_CURRENT_COLOR_PTR(sp)
    lw ra, RAINBOW_STRING_RA(sp)
    addi sp, sp, 48
    ret

# a0=x, a1=y, a2=NUL-terminated ASCII, a3=color, a4=scale.
draw_string:
    addi sp, sp, -48
    .equ DRAW_STRING_RA, 44
    .equ DRAW_STRING_X, 40
    .equ DRAW_STRING_Y, 36
    .equ DRAW_STRING_TEXT, 32
    .equ DRAW_STRING_COLOR, 28
    .equ DRAW_STRING_SCALE, 24
    sw ra, DRAW_STRING_RA(sp)
    sw a0, DRAW_STRING_X(sp)
    sw a1, DRAW_STRING_Y(sp)
    sw a2, DRAW_STRING_TEXT(sp)
    sw a3, DRAW_STRING_COLOR(sp)
    sw a4, DRAW_STRING_SCALE(sp)
0:
    lw t0, DRAW_STRING_TEXT(sp)
    lbu t1, 0(t0)
    beqz t1, 2f
    lw a0, DRAW_STRING_X(sp)
    lw a1, DRAW_STRING_Y(sp)
    lw a2, DRAW_STRING_COLOR(sp)
    lw a3, DRAW_STRING_SCALE(sp)
    mv a4, t1
    call draw_char
    lw t0, DRAW_STRING_SCALE(sp)
    li t1, 6
    mul t1, t1, t0             # five glyph columns plus one spacing column
    lw t2, DRAW_STRING_X(sp)
    add t2, t2, t1
    sw t2, DRAW_STRING_X(sp)
    lw t0, DRAW_STRING_TEXT(sp)
    addi t0, t0, 1
    sw t0, DRAW_STRING_TEXT(sp)
    j 0b
2:
    lw ra, DRAW_STRING_RA(sp)
    addi sp, sp, 48
    ret

# a0=x, a1=y, a2=current colortable pointer, a3=scale, a4=ASCII.
# Each glyph column uses one color-table entry. Returns the next entry in a0.
draw_rainbow_char:
    addi sp, sp, -64
    .equ RAINBOW_CHAR_RA, 60
    .equ RAINBOW_CHAR_X, 56
    .equ RAINBOW_CHAR_Y, 52
    .equ RAINBOW_CHAR_COLOR_PTR, 48
    .equ RAINBOW_CHAR_SCALE, 44
    .equ RAINBOW_CHAR_FONT_PTR, 40
    .equ RAINBOW_CHAR_COL_PTR, 36
    .equ RAINBOW_CHAR_ROW_PTR, 32
    .equ RAINBOW_CHAR_SRC_PTR, 28
    sw ra, RAINBOW_CHAR_RA(sp)
    sw a0, RAINBOW_CHAR_X(sp)
    sw a1, RAINBOW_CHAR_Y(sp)
    sw a2, RAINBOW_CHAR_COLOR_PTR(sp)
    sw a3, RAINBOW_CHAR_SCALE(sp)

    addi a4, a4, -32
    li t0, 5
    mul a4, a4, t0
    la t1, font5x7
    add t1, t1, a4
    sw t1, RAINBOW_CHAR_FONT_PTR(sp)
    li t0, 0
    sw t0, RAINBOW_CHAR_COL_PTR(sp)              # column
0:
    lw t0, RAINBOW_CHAR_COL_PTR(sp)
    li t1, 5
    bge t0, t1, 4f
    lw t1, RAINBOW_CHAR_FONT_PTR(sp)
    add t1, t1, t0
    lbu t1, 0(t1)
    sw t1, RAINBOW_CHAR_SRC_PTR(sp)
    li t2, 0
    sw t2, RAINBOW_CHAR_ROW_PTR(sp)              # row
1:
    lw t2, RAINBOW_CHAR_ROW_PTR(sp)
    li t3, 7
    bge t2, t3, 3f
    lw t1, RAINBOW_CHAR_SRC_PTR(sp)
    li t3, 1
    sll t3, t3, t2
    and t3, t3, t1
    beqz t3, 2f
    lw t3, RAINBOW_CHAR_X(sp)
    lw t4, RAINBOW_CHAR_COL_PTR(sp)
    lw t5, RAINBOW_CHAR_SCALE(sp)
    mul t4, t4, t5
    add a0, t3, t4
    lw t3, RAINBOW_CHAR_Y(sp)
    lw t4, RAINBOW_CHAR_ROW_PTR(sp)
    mul t4, t4, t5
    add a1, t3, t4
    mv a2, t5
    mv a3, t5
    lw t6, RAINBOW_CHAR_COLOR_PTR(sp)
    lhu a4, 0(t6)
    call fill_rect

2:
    lw t2, RAINBOW_CHAR_ROW_PTR(sp)
    addi t2, t2, 1
    sw t2, RAINBOW_CHAR_ROW_PTR(sp)
    j 1b
3:
    lw t6, RAINBOW_CHAR_COLOR_PTR(sp)
    addi t6, t6, 2
    la t0, rainbow_colors_end
    bltu t6, t0, 5f
    la t6, rainbow_colors
5:
    sw t6, RAINBOW_CHAR_COLOR_PTR(sp)
    lw t0, RAINBOW_CHAR_COL_PTR(sp)
    addi t0, t0, 1
    sw t0, RAINBOW_CHAR_COL_PTR(sp)
    j 0b
4:
    lw a0, RAINBOW_CHAR_COLOR_PTR(sp)
    lw ra, RAINBOW_CHAR_RA(sp)
    addi sp, sp, 64
    ret

# a0=x, a1=y, a2=color, a3=scale, a4=ASCII. Font is 5 columns x 7 rows.
draw_char:
    addi sp, sp, -64
    .equ DRAW_CHAR_RA, 60
    .equ DRAW_CHAR_X, 56
    .equ DRAW_CHAR_Y, 52
    .equ DRAW_CHAR_COLOR, 48
    .equ DRAW_CHAR_SCALE, 44
    .equ DRAW_CHAR_FONT_PTR, 40
    .equ DRAW_CHAR_COL_PTR, 36
    .equ DRAW_CHAR_ROW_PTR, 32
    .equ DRAW_CHAR_SRC_PTR, 28
    sw ra, DRAW_CHAR_RA(sp)
    sw a0, DRAW_CHAR_X(sp)
    sw a1, DRAW_CHAR_Y(sp)
    sw a2, DRAW_CHAR_COLOR(sp)
    sw a3, DRAW_CHAR_SCALE(sp)

    addi a4, a4, -32
    li t0, 5
    mul a4, a4, t0
    la t1, font5x7
    add t1, t1, a4
    sw t1, DRAW_CHAR_FONT_PTR(sp)
    li t0, 0
    sw t0, DRAW_CHAR_COL_PTR(sp)              # column
0:
    lw t0, DRAW_CHAR_COL_PTR(sp)
    li t1, 5
    bge t0, t1, 4f
    lw t1, DRAW_CHAR_FONT_PTR(sp)
    add t1, t1, t0
    lbu t1, 0(t1)
    sw t1, DRAW_CHAR_SRC_PTR(sp)
    li t2, 0
    sw t2, DRAW_CHAR_ROW_PTR(sp)              # row
1:
    lw t2, DRAW_CHAR_ROW_PTR(sp)
    li t3, 7
    bge t2, t3, 3f
    lw t1, DRAW_CHAR_SRC_PTR(sp)
    li t3, 1
    sll t3, t3, t2
    and t3, t3, t1
    beqz t3, 2f
    lw t3, DRAW_CHAR_X(sp)
    lw t4, DRAW_CHAR_COL_PTR(sp)
    lw t5, DRAW_CHAR_SCALE(sp)
    mul t4, t4, t5
    add a0, t3, t4
    lw t3, DRAW_CHAR_Y(sp)
    lw t4, DRAW_CHAR_ROW_PTR(sp)
    mul t4, t4, t5
    add a1, t3, t4
    mv a2, t5
    mv a3, t5
    lw a4, DRAW_CHAR_COLOR(sp)
    call fill_rect
2:
    lw t2, DRAW_CHAR_ROW_PTR(sp)
    addi t2, t2, 1
    sw t2, DRAW_CHAR_ROW_PTR(sp)
    j 1b
3:
    lw t0, DRAW_CHAR_COL_PTR(sp)
    addi t0, t0, 1
    sw t0, DRAW_CHAR_COL_PTR(sp)
    j 0b
4:
    lw ra, DRAW_CHAR_RA(sp)
    addi sp, sp, 64
    ret

# a0=milliseconds. CLK_SYS is configured to 150 MHz by clocks_init.
delay_ms:
    # The decrement/branch inner loop costs approximately two core cycles.
    li t0, 75000
0:
    mv t1, t0
1:
    addi t1, t1, -1
    bnez t1, 1b
    addi a0, a0, -1
    bnez a0, 0b
    ret

.section .rodata
console_boot_message:
    .ascii  "**************************************\n"
    .ascii  "* Pico 2 RISC-V LCD firmware started *\n"
    .asciz  "**************************************\n"

hello_text:
    # .asciz "KOPF HOCH VALLI!"
    .asciz "  HALLO JANNIS  "

# Printable ASCII 0x20 through 0x5a; columns are LSB-top bitmap data.
font5x7:
    .byte 0,0,0,0,0, 0,0,95,0,0, 0,7,0,7,0, 20,127,20,127,20
    .byte 36,42,127,42,18, 35,19,8,100,98, 54,73,85,34,80, 0,5,3,0,0
    .byte 0,28,34,65,0, 0,65,34,28,0, 20,8,62,8,20, 8,8,62,8,8
    .byte 0,80,48,0,0, 8,8,8,8,8, 0,96,96,0,0, 32,16,8,4,2
    .byte 62,81,73,69,62, 0,66,127,64,0, 66,97,81,73,70, 33,65,69,75,49
    .byte 24,20,18,127,16, 39,69,69,69,57, 60,74,73,73,48, 1,113,9,5,3
    .byte 54,73,73,73,54, 6,73,73,41,30, 0,54,54,0,0, 0,86,54,0,0
    .byte 8,20,34,65,0, 20,20,20,20,20, 0,65,34,20,8, 2,1,81,9,6
    .byte 50,73,121,65,62
    .byte 126,17,17,17,126, 127,73,73,73,54, 62,65,65,65,34, 127,65,65,34,28
    .byte 127,73,73,73,65, 127,9,9,9,1, 62,65,73,73,122, 127,8,8,8,127
    .byte 0,65,127,65,0, 32,64,65,63,1, 127,8,20,34,65, 127,64,64,64,64
    .byte 127,2,12,2,127, 127,4,8,16,127, 62,65,65,65,62, 127,9,9,9,6
    .byte 62,65,81,33,94, 127,9,25,41,70, 70,73,73,73,49, 1,1,127,1,1
    .byte 63,64,64,64,63, 31,32,64,32,31, 63,64,56,64,63, 99,20,8,20,99
    .byte 7,8,112,8,7, 97,81,73,69,67

.align 1
rainbow_colors:
    .hword 0xF800, 0xF820, 0xF860, 0xF880, 0xF8C0, 0xF8E0, 0xF920, 0xF940
    .hword 0xF980, 0xF9A0, 0xF9E0, 0xFA00, 0xFA40, 0xFA60, 0xFAA0, 0xFAC0
    .hword 0xFB00, 0xFB20, 0xFB60, 0xFB80, 0xFBC0, 0xFBE0, 0xFC00, 0xFC40
    .hword 0xFC60, 0xFCA0, 0xFCC0, 0xFD00, 0xFD20, 0xFD60, 0xFD80, 0xFDC0
    .hword 0xFDE0, 0xFE20, 0xFE40, 0xFE80, 0xFEA0, 0xFEE0, 0xFF00, 0xFF40
    .hword 0xFF60, 0xFFA0, 0xFFC0, 0xFFE0, 0xF7E0, 0xF7E0, 0xEFE0, 0xE7E0
    .hword 0xDFE0, 0xDFE0, 0xD7E0, 0xCFE0, 0xC7E0, 0xC7E0, 0xBFE0, 0xB7E0
    .hword 0xAFE0, 0xAFE0, 0xA7E0, 0x9FE0, 0x97E0, 0x97E0, 0x8FE0, 0x87E0
    .hword 0x87E0, 0x7FE0, 0x77E0, 0x6FE0, 0x6FE0, 0x67E0, 0x5FE0, 0x57E0
    .hword 0x57E0, 0x4FE0, 0x47E0, 0x3FE0, 0x3FE0, 0x37E0, 0x2FE0, 0x27E0
    .hword 0x27E0, 0x1FE0, 0x17E0, 0x0FE0, 0x0FE0, 0x07E0, 0x07E0, 0x07E1
    .hword 0x07E2, 0x07E2, 0x07E3, 0x07E4, 0x07E5, 0x07E5, 0x07E6, 0x07E7
    .hword 0x07E8, 0x07E8, 0x07E9, 0x07EA, 0x07EB, 0x07EB, 0x07EC, 0x07ED
    .hword 0x07EE, 0x07EE, 0x07EF, 0x07F0, 0x07F0, 0x07F1, 0x07F2, 0x07F3
    .hword 0x07F3, 0x07F4, 0x07F5, 0x07F6, 0x07F6, 0x07F7, 0x07F8, 0x07F9
    .hword 0x07F9, 0x07FA, 0x07FB, 0x07FC, 0x07FC, 0x07FD, 0x07FE, 0x07FF
    .hword 0x07FF, 0x07DF, 0x079F, 0x077F, 0x073F, 0x071F, 0x06DF, 0x06BF
    .hword 0x067F, 0x065F, 0x061F, 0x05FF, 0x05BF, 0x059F, 0x055F, 0x053F
    .hword 0x04FF, 0x04DF, 0x049F, 0x047F, 0x043F, 0x041F, 0x03FF, 0x03BF
    .hword 0x039F, 0x035F, 0x033F, 0x02FF, 0x02DF, 0x029F, 0x027F, 0x023F
    .hword 0x021F, 0x01DF, 0x01BF, 0x017F, 0x015F, 0x011F, 0x00FF, 0x00BF
    .hword 0x009F, 0x005F, 0x003F, 0x001F, 0x081F, 0x081F, 0x101F, 0x181F
    .hword 0x201F, 0x201F, 0x281F, 0x301F, 0x381F, 0x381F, 0x401F, 0x481F
    .hword 0x501F, 0x501F, 0x581F, 0x601F, 0x681F, 0x681F, 0x701F, 0x781F
    .hword 0x801F, 0x801F, 0x881F, 0x901F, 0x901F, 0x981F, 0xA01F, 0xA81F
    .hword 0xA81F, 0xB01F, 0xB81F, 0xC01F, 0xC01F, 0xC81F, 0xD01F, 0xD81F
    .hword 0xD81F, 0xE01F, 0xE81F, 0xF01F, 0xF01F, 0xF81F, 0xF81F, 0xF81E
    .hword 0xF81D, 0xF81D, 0xF81C, 0xF81B, 0xF81A, 0xF81A, 0xF819, 0xF818
    .hword 0xF817, 0xF817, 0xF816, 0xF815, 0xF814, 0xF814, 0xF813, 0xF812
    .hword 0xF811, 0xF811, 0xF810, 0xF80F, 0xF80F, 0xF80E, 0xF80D, 0xF80C
    .hword 0xF80C, 0xF80B, 0xF80A, 0xF809, 0xF809, 0xF808, 0xF807, 0xF806
    .hword 0xF806, 0xF805, 0xF804, 0xF803, 0xF803, 0xF802, 0xF801, 0xF800
rainbow_colors_end:
