# -*- mode: Assembly -*-
.macro LOG_STRING string
    la a0, \string
    call uart_write_string

    ## append a newline to flush
    li a0, '\n'
    call uart_write_byte
.endm

.macro LOG_STRING_PTR reg
    mv a0, \reg
    call uart_write_string

    ## append a newline to flush
    li a0, '\n'
    call uart_write_byte
.endm

.macro LOAD_WORD reg addr
    la \reg, \addr
    lw \reg, 0(\reg)
.endm

.macro SAVE_WORD reg addr scratch
    la \scratch, \addr
    sw \reg, 0(\scratch)
.endm
