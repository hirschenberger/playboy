#include "rp2350.h"

.global lcd_init, set_window
.extern uart_init
.extern timer0_init

lcd_init:
        addi sp, sp, -16
        sw ra, 12(sp)

        call clocks_init
        call timer0_init
        call uart_init
        call lcd_gpio_init
        call spi1_init
        call st7789_init

        lw ra, 12(sp)
        addi sp, sp, 16
        ret

# a0=x0, a1=x1, a2=y0, a3=y1. Leave LCD selected and in data mode for RAMWR.
set_window:
        addi sp, sp, -48
        sw ra, 44(sp)
        sw s0, 40(sp)
        sw s1, 36(sp)
        sw s2, 32(sp)
        sw s3, 28(sp)

        mv s0, a0
        mv s1, a1
        mv s2, a2
        mv s3, a3

        li a0, ST_CASET
        call lcd_command
        srli a0, s0, 8
        call lcd_data_byte
        andi a0, s0, 0xff
        call lcd_data_byte
        srli a0, s1, 8
        call lcd_data_byte
        andi a0, s1, 0xff
        call lcd_data_byte

        li a0, ST_RASET
        call lcd_command
        srli a0, s2, 8
        call lcd_data_byte
        andi a0, s2, 0xff
        call lcd_data_byte
        srli a0, s3, 8
        call lcd_data_byte
        andi a0, s3, 0xff
        call lcd_data_byte

        li a0, ST_RAMWR
        call lcd_command
        li t0, SIO_BASE
        li t1, LCD_DC_MASK
        sw t1, SIO_GPIO_OUT_SET(t0)
        li t1, LCD_CS_MASK
        sw t1, SIO_GPIO_OUT_CLR(t0)

        lw s3, 28(sp)
        lw s2, 32(sp)
        lw s1, 36(sp)
        lw s0, 40(sp)
        lw ra, 44(sp)
        addi sp, sp, 48
        ret


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

# Configure the standard 150 MHz clock tree: 12 MHz XOSC feeds PLL_SYS at 1.5 GHz,
# divided by 5 and 2 for CLK_SYS and CLK_PERI.
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
    .equ ST7789_INIT_RA, 12
        sw ra, ST7789_INIT_RA(sp)

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

        lw ra, ST7789_INIT_RA(sp)
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
        addi sp, sp, -32
        sw ra, 28(sp)
        sw s0, 24(sp)
        sw s1, 20(sp)

        mv s0, a1
        mv s1, a2

        call lcd_command
0:
        beqz s1, 1f
        lbu a0, 0(s0)
        call lcd_data_byte
        addi s0, s0, 1
        addi s1, s1, -1
        j 0b
1:
        lw s1, 20(sp)
        lw s0, 24(sp)
        lw ra, 28(sp)
        addi sp, sp, 32
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

.section .rodata

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
