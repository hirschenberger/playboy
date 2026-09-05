.section .picobin, "a"
.align 2
.global picobin_start
picobin_start:
    .word 0xffffded3
    .byte 0x42                    # IMAGE_TYPE item
    .byte 0x01                    # one word
    .hword 0x1101                 # executable, RP2350, RISC-V
    .byte 0x44                    # ENTRY_POINT item
    .byte 0x03                    # three words
    .hword 0
    .word _reset_handler
    .word __stack_top
    .byte 0xff                    # LAST item
    .hword (picobin_end - picobin_start - 16) / 4
    .byte 0
    .word 0                       # single-block loop
    .word 0xab123579
picobin_end:
