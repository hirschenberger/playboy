#include "math.h"

.section .text
.align 2

/* ============================================================
 * Q16.16 fixed-point math library
 *
 * Format:
 *
 *   31             16 15              0
 *   +----------------+----------------+
 *   | signed integer |   fraction     |
 *   +----------------+----------------+
 *
 *   value = raw / 65536
 *
 * Examples:
 *
 *   1.0  =  0x00010000
 *   0.5  =  0x00008000
 *  -1.0  =  0xFFFF0000
 *
 * Requires:
 *   RV32IM
 *
 * ABI:
 *   a0, a1 = arguments
 *   a0     = return value
 *
 * Clobbers:
 *   t0, t1
 * ============================================================ */


/* ============================================================
 * fp_mul
 *
 * Q16.16 × Q16.16 -> Q16.16
 *
 * mathematically:
 *
 *   result = (a * b) >> 16
 *
 * We calculate the full 64-bit product:
 *
 *   t1:t0 = a0 * a1
 *
 * then shift it right by 16.
 *
 * This correctly preserves the upper bits of the product.
 *
 * ============================================================ */
.globl fp_mul
fp_mul:
    mul     t0, a0, a1       # low 32 bits
    mulh    t1, a0, a1       # high 32 bits, signed

    # Arithmetic 64-bit >> 16
    slli    t1, t1, 16
    srai    t0, t0, 16

    or      a0, t0, t1

    ret

/* ============================================================
 * fp_div
 *
 * Q16.16 / Q16.16 -> Q16.16
 *
 * mathematically:
 *
 *   result = (a << 16) / b
 *
 * Problem:
 *
 *   RV32 div operates on 32-bit values, so we cannot simply
 *
 *       slli a0, a0, 16
 *       div  a0, a0, a1
 *
 * because the shifted numerator may overflow.
 *
 * We therefore use a 64-bit numerator and perform signed
 * division using unsigned division after handling the signs.
 *
 * ============================================================ */
.globl fp_div
fp_div:
    /*
     * Save result sign.
     *
     * t2 = 1 if signs differ
     */
    xor     t2, a0, a1
    srli    t2, t2, 31

    /*
     * Absolute numerator
     */
    mv      t0, a0
    bgez    t0, 1f
    neg     t0, t0

1:
    /*
     * Absolute denominator
     */
    mv      t1, a1
    bgez    t1, 2f
    neg     t1, t1

2:
    /*
     * We need:
     *
     *   (t0 << 16) / t1
     *
     * Since t0 is 32-bit, the numerator can be 48-bit.
     *
     * Perform restoring division bit-by-bit.
     *
     * t3 = quotient
     * t4 = remainder
     * t5 = bit counter
     */

    li      t3, 0
    li      t4, 0
    li      t5, 47

3:
    /*
     * Get next numerator bit.
     *
     * First 32 bits come from t0.
     * Last 16 bits are zero because of << 16.
     */

    li      t6, 16
    blt     t5, t6, 4f

    addi    t6, t5, -16
    srl     t6, t0, t6
    andi    t6, t6, 1
    j       5f

4:
    li      t6, 0

5:
    /*
     * remainder = (remainder << 1) | bit
     */
    slli    t4, t4, 1
    or      t4, t4, t6

    /*
     * if remainder >= divisor:
     *
     *     remainder -= divisor
     *     quotient bit = 1
     */
    bltu    t4, t1, 6f

    sub     t4, t4, t1

    slli    t3, t3, 1
    ori     t3, t3, 1
    j       7f

6:
    slli    t3, t3, 1

7:
    addi    t5, t5, -1
    bgez    t5, 3b

    /*
     * Apply sign.
     */
    mv      a0, t3

    beqz    t2, 8f
    neg     a0, a0

8:
    ret

/* ============================================================
 * fp_clamp
 *
 * Clamp a0 between a1 and a2.
 *
 * a0 = value
 * a1 = minimum
 * a2 = maximum
 *
 * return:
 *   a0 = clamped value
 * ============================================================ */

.globl fp_clamp
fp_clamp:
    blt     a0, a1, 1f
    bgt     a0, a2, 2f
    ret

1:
    mv      a0, a1
    ret

2:
    mv      a0, a2
    ret

    .section .text
    .align 2
    .globl sin_cos
    .type sin_cos, @function

# a0: unsigned 16-bit turn angle
# a1: X (Q16.16)
# a2: Y (Q16.16)
# Returns rotated X in a0 and rotated Y in a1.
.global rotate_vec
rotate_vec:
        addi sp, sp, -32
        sw ra, 28(sp)
        sw s0, 24(sp)
        sw s1, 20(sp)
        sw s2, 16(sp)
        sw s3, 12(sp)

        mv s0, a1                 # original X
        mv s1, a2                 # original Y

        call sin_cos
        mv s2, a0                 # sin(angle)
        mv s3, a1                 # cos(angle)

        FP_MUL_Q16 t0, s0, s3, t1 # x' = x*cos - y*sin
        FP_MUL_Q16 t2, s1, s2, t3
        sub a0, t0, t2

        FP_MUL_Q16 t0, s0, s2, t1 # y' = x*sin + y*cos
        FP_MUL_Q16 t2, s1, s3, t3
        add a1, t0, t2

        lw s3, 12(sp)
        lw s2, 16(sp)
        lw s1, 20(sp)
        lw s0, 24(sp)
        lw ra, 28(sp)
        addi sp, sp, 32
        ret


# ------------------------------------------------------------
# sin_cos
#
# Input:
#   a0 = unsigned 16-bit turn angle
#
# Output:
#   a0 = sin(angle), Q16.16
#   a1 = cos(angle), Q16.16
#
# Clobbers:
#   t0-t6
#
# Angle representation:
#   0x0000 =   0°
#   0x4000 =  90°
#   0x8000 = 180°
#   0xC000 = 270°
#
# LUT:
#   65 entries
#   Q16.16
#   0° .. 90°
# ------------------------------------------------------------

.global sin_cos
sin_cos:
    # Keep only the 16-bit angle
    slli    a0, a0, 16
    srli    a0, a0, 16

    # q = angle >> 14
    srli    t0, a0, 14

    # idx = (angle >> 8) & 0x3f
    srli    t1, a0, 8
    andi    t1, t1, 0x3f
    mv      t6, t1

    # --------------------------------------------------------
    # Calculate sine index
    # --------------------------------------------------------

    # reflected = 64 - idx
    li      t2, 64
    sub     t2, t2, t1

    # q 0 or 2 -> idx
    # q 1 or 3 -> 64 - idx

    andi    t3, t0, 1
    beqz    t3, .L_sin_index_ready

    mv      t1, t2

.L_sin_index_ready:

    # Load sine LUT value
    slli    t3, t1, 2
    la      t4, sin_lut
    add     t4, t4, t3
    lw      t5, 0(t4)

    # q >= 2 -> sine negative
    srli    t3, t0, 1
    beqz    t3, .L_sin_positive

    neg     t5, t5

.L_sin_positive:
    mv      a0, t5


    # --------------------------------------------------------
    # Calculate cosine
    # --------------------------------------------------------

    # For cosine:
    #
    # q 0 -> 64 - idx
    # q 1 -> idx
    # q 2 -> 64 - idx
    # q 3 -> idx
    #
    # Therefore:
    #   cosine uses idx when q is odd
    #   cosine uses 64-idx when q is even

    andi    t3, t0, 1
    beqz    t3, .L_cos_reflect

    # odd quadrant -> idx
    mv      t1, t6
    j       .L_cos_load

.L_cos_reflect:

    # even quadrant -> 64 - original idx
    li      t2, 64
    sub     t1, t2, t6

.L_cos_load:

    slli    t3, t1, 2
    la      t4, sin_lut
    add     t4, t4, t3
    lw      t5, 0(t4)

    li      t6, 1
    beq     t0, t6, .L_cos_negative

    li      t6, 2
    beq     t0, t6, .L_cos_negative

    mv      a1, t5
    ret

.L_cos_negative:
    neg     t5, t5
    mv      a1, t5
    ret

# ************************************
.section .rodata
.align 2

sin_lut:
.word 0x00000000, 0x00000648, 0x00000C90, 0x000012D5
.word 0x00001918, 0x00001F56, 0x00002590, 0x00002BC4
.word 0x000031F1, 0x00003817, 0x00003E34, 0x00004447
.word 0x00004A50, 0x0000504D, 0x0000563E, 0x00005C22
.word 0x000061F8, 0x000067BE, 0x00006D74, 0x0000731A
.word 0x000078AD, 0x00007E2F, 0x0000839C, 0x000088F6
.word 0x00008E3A, 0x00009368, 0x00009880, 0x00009D80
.word 0x0000A268, 0x0000A736, 0x0000ABEB, 0x0000B086
.word 0x0000B505, 0x0000B968, 0x0000BDAF, 0x0000C1D8
.word 0x0000C5E4, 0x0000C9D1, 0x0000CD9F, 0x0000D14D
.word 0x0000D4DB, 0x0000D848, 0x0000DB94, 0x0000DEBE
.word 0x0000E1C6, 0x0000E4AA, 0x0000E76C, 0x0000EA0A
.word 0x0000EC83, 0x0000EED9, 0x0000F109, 0x0000F314
.word 0x0000F4FA, 0x0000F6BA, 0x0000F854, 0x0000F9C8
.word 0x0000FB15, 0x0000FC3B, 0x0000FD3B, 0x0000FE13
.word 0x0000FEC4, 0x0000FF4E, 0x0000FFB1, 0x0000FFEC
.word 0x00010000
