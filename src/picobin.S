.global picobin_start

.section .picobin, "a"            # RP2350 Boot ROM metadata, placed first in flash.
.align 2
picobin_start:
        .word 0xffffded3              # Picobin block start marker.
        .byte 0x42                    # IMAGE_TYPE item tag.
        .byte 0x01                    # Payload is one 32-bit word.
        .hword 0x1101                 # Executable RP2350 RISC-V image.
        .byte 0x44                    # ENTRY_POINT item tag.
        .byte 0x03                    # Payload is three 32-bit words.
        .hword 0                      # Reserved field required by the item format.
        .word _reset_handler          # Initial program counter for the Boot ROM.
        .word __stack_top             # Initial stack pointer for the Boot ROM.
        .byte 0xff                    # LAST item: no more metadata follows.
        .hword (picobin_end - picobin_start - 16) / 4 # Block length in words.
        .byte 0                       # Single-block image; no chained metadata block.
        .word 0                       # Link to the next block (none).
        .word 0xab123579              # Picobin block end marker.
picobin_end:
