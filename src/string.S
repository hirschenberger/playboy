#include "macros.h"

.global itoa

.section .text
.align 2

.equ ITOA_BUFFER_SIZE, 12

# ------------------------------------------------------------------------------
# Convert an integer to a NUL-terminated ASCII string.
#
# In:
#   * a0: the integer to convert
#
# Out:
#   * a0: address of the internal buffer containing the string
itoa:
    la t0, itoa_buffer                   # buffer ptr
    addi t0, t0, ITOA_BUFFER_SIZE-1      # move to end of buffer
    li t1, 10                            # divider
    mv t2, a0                            # abs(a0)
    bgez t2, .Lnon_neg

    neg t2, t2

.Lnon_neg:
    # add terminator
    sb zero, 0(t0)
    addi t0, t0, -1

.Lnext_char:
    remu t3, t2, t1
    divu t2, t2, t1

    add t3, t3, '0'                       # to ascii
    sb t3, 0(t0)                          # store char
    beqz t2, .Lcheck_sign

    addi t0, t0, -1
    j .Lnext_char

.Lcheck_sign:
    bgez a0, .Lfini

    addi t0, t0, -1
    li t1, '-'
    sb t1, 0(t0)

.Lfini:
    mv a0, t0
    ret


.section .bss
.align 1
itoa_buffer: .space ITOA_BUFFER_SIZE
