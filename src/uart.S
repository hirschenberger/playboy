#include "rp2350.h"

.global uart_init, uart_write_byte, uart_write_string

.section .text

# Configure UART0 at 115200 8-N-1. GP0 is the Pico TX pin connected to the
# Debug Probe's UART RX pin; GP1 is configured for optional future input.
uart_init:
    li t0, PADS_BANK0_BASE
    li t1, PADS_OUTPUT_4MA
    sw t1, PADS_GPIO_BASE + UART_TX_PIN * PADS_GPIO_STRIDE(t0)
    sw t1, PADS_GPIO_BASE + UART_RX_PIN * PADS_GPIO_STRIDE(t0)

    li t0, IO_BANK0_BASE
    li t1, GPIO_FUNC_UART
    sw t1, GPIO_CTRL_BASE + UART_TX_PIN * GPIO_CTRL_STRIDE(t0)
    sw t1, GPIO_CTRL_BASE + UART_RX_PIN * GPIO_CTRL_STRIDE(t0)

    li t0, RESETS_BASE
    lw t1, RESETS_RESET(t0)
    li t2, RESETS_UART0_BIT
    not t2, t2
    and t1, t1, t2
    sw t1, RESETS_RESET(t0)
1:
    lw t1, RESETS_RESET_DONE(t0)
    li t2, RESETS_UART0_BIT
    and t1, t1, t2
    beqz t1, 1b

    li t0, UART0_BASE
    sw zero, UART_CR(t0)
    li t1, UART0_IBRD_115200
    sw t1, UART_IBRD(t0)
    li t1, UART0_FBRD_115200
    sw t1, UART_FBRD(t0)
    li t1, UART_LCR_H_WLEN_8
    sw t1, UART_LCR_H(t0)
    li t1, UART_CR_ENABLE_TX
    sw t1, UART_CR(t0)
    ret

# a0=byte. Blocks until the UART0 TX FIFO can accept it.
uart_write_byte:
    li t0, UART0_BASE
1:
    lw t1, UART_FR(t0)
    andi t1, t1, UART_FR_TXFF
    bnez t1, 1b
    sw a0, UART_DR(t0)
    ret

# a0=NUL-terminated string address.
uart_write_string:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)

    mv s0, a0
.Lnext_char:
    lbu a0, 0(s0)
    beqz a0, .Lfini
    call uart_write_byte
    addi s0, s0, 1
    j .Lnext_char

.Lfini:
    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    ret
