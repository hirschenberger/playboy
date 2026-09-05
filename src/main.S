#include "rp2350.inc"

.section .text
.align 2
.global main
.type main, @function
main:
    call clocks_init
    call lcd_gpio_init
    call spi1_init
    call st7789_init

    li a0, 01000                 # RGB565 navy background
    call lcd_clear

    li a0, 20
    li a1, 32
    la a2, title_text
    li a3, 0xffff                 # white
    li a4, 2                      # pixel scale
    call draw_string

    la s1, rainbow_colors         # colortable ptr
    la s2, rainbow_colors_end     # colortable end ptr

1:
    li a0, 20
    li a1, 104
    la a2, hello_text
    lhu a3, 0(s1)                  # current colortable color
    li a4, 3
    call draw_string

    li a0, 20
    li a1, 170
    li a2, 200
    li a3, 20
    lhu a4, 0(s1)
    call fill_rect

    li a0, 10
    call delay_ms

    addi s1, s1, 2
    bne s1, s2, 1b

    # start from the beginning
    la s1, rainbow_colors

    j 1b

# Configure control pins as SIO outputs and GP10--12 as SPI1.
lcd_gpio_init:
    li t0, PADS_BANK0_BASE
    li t1, PADS_OUTPUT_4MA
    li t2, 8
0:
    slli t3, t2, 2
    add t3, t3, t0
    addi t3, t3, PADS_GPIO_BASE
    sw t1, 0(t3)                  # remove pad isolation, use 3.3 V defaults
    addi t2, t2, 1
    li t4, 17
    blt t2, t4, 0b
    li t2, SD_CS_PIN
    slli t3, t2, 2
    add t3, t3, t0
    addi t3, t3, PADS_GPIO_BASE
    sw t1, 0(t3)

    li t0, IO_BANK0_BASE
    li t1, GPIO_FUNC_SIO
    li t2, LCD_DC_PIN
0:
    slli t3, t2, 3
    add t3, t3, t0
    addi t3, t3, GPIO_CTRL_BASE
    sw t1, 0(t3)
    addi t2, t2, 1
    li t4, 17
    blt t2, t4, 0b
    li t2, SD_CS_PIN
    slli t3, t2, 3
    add t3, t3, t0
    addi t3, t3, GPIO_CTRL_BASE
    sw t1, 0(t3)

    li t1, GPIO_FUNC_SPI1
    li t2, LCD_SCK_PIN
1:
    slli t3, t2, 3
    add t3, t3, t0
    addi t3, t3, GPIO_CTRL_BASE
    sw t1, 0(t3)
    addi t2, t2, 1
    li t4, 13
    blt t2, t4, 1b

    li t0, SIO_BASE
    li t1, LCD_GPIO_MASK
    sw t1, SIO_GPIO_OE_SET(t0)
    li t1, (LCD_CS_MASK | LCD_BL_MASK | LCD_RST_MASK | TOUCH_CS_MASK | SD_CS_MASK)
    sw t1, SIO_GPIO_OUT_SET(t0)   # deselect peripherals, turn on backlight
    li t1, LCD_DC_MASK
    sw t1, SIO_GPIO_OUT_CLR(t0)
    ret

# Configure the standard Pico 2 150 MHz clock tree: 12 MHz XOSC feeds
# PLL_SYS at 1.5 GHz, divided by 5 and 2 for CLK_SYS and CLK_PERI.
clocks_init:
    li t0, XOSC_BASE
    li t1, 3
    sw t1, XOSC_STARTUP(t0)
    li t1, XOSC_CTRL_ENABLE_12MHZ
    sw t1, XOSC_CTRL(t0)
0:
    lw t1, XOSC_STATUS(t0)
    li t2, XOSC_STATUS_STABLE
    and t1, t1, t2
    beqz t1, 0b

    li t0, CLOCKS_BASE
    li t1, CLOCKS_CLK_REF_XOSC
    sw t1, CLOCKS_CLK_REF_CTRL(t0)
1:
    lw t1, CLOCKS_CLK_REF_SELECTED(t0)
    li t2, CLOCKS_CLK_REF_XOSC_SELECTED
    and t1, t1, t2
    beqz t1, 1b

    li t0, RESETS_BASE
    lw t1, RESETS_RESET(t0)
    li t2, RESETS_PLL_SYS_BIT
    not t2, t2
    and t1, t1, t2
    sw t1, RESETS_RESET(t0)
2:
    lw t1, RESETS_RESET_DONE(t0)
    li t2, RESETS_PLL_SYS_BIT
    and t1, t1, t2
    beqz t1, 2b

    li t0, PLL_SYS_BASE
    li t1, PLL_SYS_REFDIV
    sw t1, PLL_CS(t0)
    li t1, PLL_SYS_FBDIV
    sw t1, PLL_FBDIV_INT(t0)
    lw t1, PLL_PWR(t0)
    li t2, (PLL_PWR_PD | PLL_PWR_VCOPD)
    not t2, t2
    and t1, t1, t2
    sw t1, PLL_PWR(t0)
3:
    lw t1, PLL_CS(t0)
    li t2, PLL_CS_LOCK
    and t1, t1, t2
    beqz t1, 3b
    li t1, PLL_SYS_POSTDIVS
    sw t1, PLL_PRIM(t0)
    lw t1, PLL_PWR(t0)
    li t2, PLL_PWR_POSTDIVPD
    not t2, t2
    and t1, t1, t2
    sw t1, PLL_PWR(t0)

    li t0, CLOCKS_BASE
    li t1, CLOCKS_CLK_SYS_AUX
    sw t1, CLOCKS_CLK_SYS_CTRL(t0)
4:
    lw t1, CLOCKS_CLK_SYS_SELECTED(t0)
    li t2, CLOCKS_CLK_SYS_AUX_SELECTED
    and t1, t1, t2
    beqz t1, 4b

    li t0, CLOCKS_BASE
    li t1, CLOCKS_CLK_PERI_ENABLE
    sw t1, CLOCKS_CLK_PERI_CTRL(t0)
5:
    lw t1, CLOCKS_CLK_PERI_CTRL(t0)
    li t2, CLOCKS_CLK_PERI_ENABLED
    and t1, t1, t2
    beqz t1, 5b
    ret

# CLK_PERI runs at 150 MHz; CPSR=4 produces a 37.5 MHz mode-0 SPI clock.
spi1_init:
    li t0, RESETS_BASE
    lw t1, RESETS_RESET(t0)
    li t2, RESETS_SPI1_BIT
    not t2, t2
    and t1, t1, t2
    sw t1, RESETS_RESET(t0)
0:
    lw t1, RESETS_RESET_DONE(t0)
    li t2, RESETS_SPI1_BIT
    and t1, t1, t2
    beqz t1, 0b

    li t0, SPI1_BASE
    sw zero, SPI_CR1(t0)
    li t1, SPI_CR0_8BIT_MODE0
    sw t1, SPI_CR0(t0)
    li t1, SPI_CPSR_37_5MHZ
    sw t1, SPI_CPSR(t0)
    li t1, SPI_CR1_ENABLE
    sw t1, SPI_CR1(t0)
    ret

st7789_init:
    addi sp, sp, -16
    sw ra, 12(sp)
    li t0, SIO_BASE
    li t1, LCD_RST_MASK
    sw t1, SIO_GPIO_OUT_SET(t0)
    li a0, 500
    call delay_ms
    li t0, SIO_BASE
    li t1, LCD_RST_MASK
    sw t1, SIO_GPIO_OUT_CLR(t0)
    li a0, 500
    call delay_ms
    li t0, SIO_BASE
    li t1, LCD_RST_MASK
    sw t1, SIO_GPIO_OUT_SET(t0)
    li a0, 500
    call delay_ms

    li a0, ST_SLPOUT
    call lcd_command
    li a0, 120
    call delay_ms

    # These values are the vendor initialization sequence for the 320x240
    # ST7789VW panel, not the similar but incompatible generic ST7789 defaults.
    li a0, ST_MADCTL
    la a1, st7789_madctl
    li a2, 1
    call lcd_command_data
    li a0, ST_COLMOD
    la a1, st7789_colmod
    li a2, 1
    call lcd_command_data
    li a0, 0xb2
    la a1, st7789_b2
    li a2, 5
    call lcd_command_data
    li a0, 0xb7
    la a1, st7789_b7
    li a2, 1
    call lcd_command_data
    li a0, 0xbb
    la a1, st7789_bb
    li a2, 1
    call lcd_command_data
    li a0, 0xc0
    la a1, st7789_c0
    li a2, 1
    call lcd_command_data
    li a0, 0xc2
    la a1, st7789_c2
    li a2, 1
    call lcd_command_data
    li a0, 0xc3
    la a1, st7789_c3
    li a2, 1
    call lcd_command_data
    li a0, 0xc4
    la a1, st7789_c4
    li a2, 1
    call lcd_command_data
    li a0, 0xc6
    la a1, st7789_c6
    li a2, 1
    call lcd_command_data
    li a0, 0xd0
    la a1, st7789_d0
    li a2, 2
    call lcd_command_data
    li a0, 0xe0
    la a1, st7789_e0
    li a2, 14
    call lcd_command_data
    li a0, 0xe1
    la a1, st7789_e1
    li a2, 14
    call lcd_command_data
    li a0, 0x55
    la a1, st7789_55
    li a2, 1
    call lcd_command_data
    li a0, ST_INVON
    call lcd_command
    li a0, ST_DISPON
    call lcd_command
    li a0, 100
    call delay_ms
    li t0, SIO_BASE
    li t1, LCD_BL_MASK
    sw t1, SIO_GPIO_OUT_SET(t0)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

lcd_command:
    li t0, SIO_BASE
    li t1, LCD_DC_MASK
    sw t1, SIO_GPIO_OUT_CLR(t0)
    j lcd_write_byte

lcd_data_byte:
    li t0, SIO_BASE
    li t1, LCD_DC_MASK
    sw t1, SIO_GPIO_OUT_SET(t0)
    j lcd_write_byte

# a0=command, a1=data address, a2=data byte count.
lcd_command_data:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw a1, 8(sp)
    sw a2, 4(sp)
    call lcd_command
0:
    lw t0, 4(sp)
    beqz t0, 1f
    lw t1, 8(sp)
    lbu a0, 0(t1)
    call lcd_data_byte
    lw t1, 8(sp)
    addi t1, t1, 1
    sw t1, 8(sp)
    lw t0, 4(sp)
    addi t0, t0, -1
    sw t0, 4(sp)
    j 0b
1:
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

lcd_write_byte:
    li t0, SIO_BASE
    li t1, LCD_CS_MASK
    sw t1, SIO_GPIO_OUT_CLR(t0)
    li t0, SPI1_BASE
0:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_TNF
    beqz t1, 0b
    sw a0, SPI_DR(t0)
1:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_RNE
    beqz t1, 1b
    lw t1, SPI_DR(t0)           # drain RX FIFO after each write
2:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_BSY
    bnez t1, 2b
    li t0, SIO_BASE
    li t1, LCD_CS_MASK
    sw t1, SIO_GPIO_OUT_SET(t0)
    ret

# a0=x0, a1=x1, a2=y0, a3=y1. Leave LCD selected and in data mode for RAMWR.
set_window:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw a0, 24(sp)
    sw a1, 20(sp)
    sw a2, 16(sp)
    sw a3, 12(sp)
    li a0, ST_CASET
    call lcd_command
    lw t0, 24(sp)
    lw t1, 20(sp)
    srli a0, t0, 8
    call lcd_data_byte
    lw t0, 24(sp)
    andi a0, t0, 0xff
    call lcd_data_byte
    lw t1, 20(sp)
    srli a0, t1, 8
    call lcd_data_byte
    lw t1, 20(sp)
    andi a0, t1, 0xff
    call lcd_data_byte
    li a0, ST_RASET
    call lcd_command
    lw t0, 16(sp)
    lw t1, 12(sp)
    srli a0, t0, 8
    call lcd_data_byte
    lw t0, 16(sp)
    andi a0, t0, 0xff
    call lcd_data_byte
    lw t1, 12(sp)
    srli a0, t1, 8
    call lcd_data_byte
    lw t1, 12(sp)
    andi a0, t1, 0xff
    call lcd_data_byte
    li a0, ST_RAMWR
    call lcd_command
    li t0, SIO_BASE
    li t1, LCD_DC_MASK
    sw t1, SIO_GPIO_OUT_SET(t0)
    li t1, LCD_CS_MASK
    sw t1, SIO_GPIO_OUT_CLR(t0)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

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
6:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_BSY
    bnez t1, 6b
    li t0, SIO_BASE
    li t1, LCD_CS_MASK
    sw t1, SIO_GPIO_OUT_SET(t0)
    ret

# a0=color. Clear all 320*240 pixels.
lcd_clear:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw a0, 8(sp)
    li a0, 0
    li a1, SCREEN_WIDTH - 1
    li a2, 0
    li a3, SCREEN_HEIGHT - 1
    call set_window
    lw a0, 8(sp)
    li a1, SCREEN_WIDTH * SCREEN_HEIGHT
    call write_color
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

# a0=x, a1=y, a2=width, a3=height, a4=RGB565.
fill_rect:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw a4, 24(sp)
    sw a2, 20(sp)
    sw a3, 16(sp)
    add t0, a0, a2
    addi t0, t0, -1
    add t1, a1, a3
    addi t1, t1, -1
    mv a2, a1
    mv a1, t0
    mv a3, t1
    call set_window
    lw a0, 24(sp)
    lw t0, 20(sp)
    lw t1, 16(sp)
    mul a1, t0, t1
    call write_color
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

# a0=x, a1=y, a2=NUL-terminated ASCII, a3=color, a4=scale.
draw_string:
    addi sp, sp, -48
    sw ra, 44(sp)
    sw a0, 40(sp)
    sw a1, 36(sp)
    sw a2, 32(sp)
    sw a3, 28(sp)
    sw a4, 24(sp)
0:
    lw t0, 32(sp)
    lbu t1, 0(t0)
    beqz t1, 2f
    lw a0, 40(sp)
    lw a1, 36(sp)
    lw a2, 28(sp)
    lw a3, 24(sp)
    mv a4, t1
    call draw_char
    lw t0, 24(sp)
    li t1, 6
    mul t1, t1, t0             # five glyph columns plus one spacing column
    lw t2, 40(sp)
    add t2, t2, t1
    sw t2, 40(sp)
    lw t0, 32(sp)
    addi t0, t0, 1
    sw t0, 32(sp)
    j 0b
2:
    lw ra, 44(sp)
    addi sp, sp, 48
    ret

# a0=x, a1=y, a2=color, a3=scale, a4=ASCII. Font is 5 columns x 7 rows.
draw_char:
    addi sp, sp, -64
    sw ra, 60(sp)
    sw a0, 56(sp)
    sw a1, 52(sp)
    sw a2, 48(sp)
    sw a3, 44(sp)
    addi a4, a4, -32
    li t0, 5
    mul a4, a4, t0
    la t1, font5x7
    add t1, t1, a4
    sw t1, 40(sp)
    li t0, 0
    sw t0, 36(sp)              # column
0:
    lw t0, 36(sp)
    li t1, 5
    bge t0, t1, 4f
    lw t1, 40(sp)
    add t1, t1, t0
    lbu t1, 0(t1)
    sw t1, 28(sp)
    li t2, 0
    sw t2, 32(sp)              # row
1:
    lw t2, 32(sp)
    li t3, 7
    bge t2, t3, 3f
    lw t1, 28(sp)
    li t3, 1
    sll t3, t3, t2
    and t3, t3, t1
    beqz t3, 2f
    lw t3, 56(sp)
    lw t4, 36(sp)
    lw t5, 44(sp)
    mul t4, t4, t5
    add a0, t3, t4
    lw t3, 52(sp)
    lw t4, 32(sp)
    mul t4, t4, t5
    add a1, t3, t4
    mv a2, t5
    mv a3, t5
    lw a4, 48(sp)
    call fill_rect
2:
    lw t2, 32(sp)
    addi t2, t2, 1
    sw t2, 32(sp)
    j 1b
3:
    lw t0, 36(sp)
    addi t0, t0, 1
    sw t0, 36(sp)
    j 0b
4:
    lw ra, 60(sp)
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
title_text:
    .asciz "RP2350 HAZARD3"
hello_text:
    .asciz "HALLO VALLI!"

st7789_madctl: .byte 0x60
st7789_colmod: .byte 0x55
st7789_b2:     .byte 0x0c, 0x0c, 0x00, 0x33, 0x33
st7789_b7:     .byte 0x35
st7789_bb:     .byte 0x28
st7789_c0:     .byte 0x3c
st7789_c2:     .byte 0x01
st7789_c3:     .byte 0x0b
st7789_c4:     .byte 0x20
st7789_c6:     .byte 0x0f
st7789_d0:     .byte 0xa4, 0xa1
st7789_e0:     .byte 0xd0, 0x01, 0x08, 0x0f, 0x11, 0x2a, 0x36, 0x55, 0x44, 0x3a, 0x0b, 0x06, 0x11, 0x20
st7789_e1:     .byte 0xd0, 0x02, 0x07, 0x0a, 0x0b, 0x18, 0x34, 0x43, 0x4a, 0x2b, 0x1b, 0x1c, 0x22, 0x1f
st7789_55:     .byte 0xb0

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
