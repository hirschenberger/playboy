#include "macros.h"

.section .text
.align 2

.global itoa

.equ ITOA_BUFFER_SIZE, 12

# Convert unsigned integer to null-terminated ascii string
#
# In:
#   a0: the integer to convert
# Out:
#   a0: address of internal buffer with string
itoa:
    la t0, itoa_buffer                   # buffer ptr
    addi t0, t0, ITOA_BUFFER_SIZE-1      # move to end of buffer
    li t1, 10                            # divider

    # add terminator
    sb zero, 0(t0)
    addi t0, t0, -1

.Lnext_char:
    remu t3, a0, t1
    divu a0, a0, t1

    add t3, t3, '0'                       # to ascii
    sb t3, 0(t0)                          # store char
    beqz a0, .Lfini

    addi t0, t0, -1
    j .Lnext_char

.Lfini:
    mv a0, t0
    ret


.section .bss
itoa_buffer: .space ITOA_BUFFER_SIZE
