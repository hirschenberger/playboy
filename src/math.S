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
 * fp_from_int
 *
 * int -> Q16.16
 *
 * a0 = integer
 * a0 = fixed point
 *
 * Example:
 *
 *   5 -> 0x00050000
 * ============================================================ */

.globl fp_from_int
fp_from_int:
    slli    a0, a0, 16
    ret


/* ============================================================
 * fp_to_int
 *
 * Q16.16 -> int
 *
 * a0 = fixed point
 * a0 = integer
 *
 * Truncates toward negative infinity because this is an
 * arithmetic right shift.
 * ============================================================ */

.globl fp_to_int
fp_to_int:
    srai    a0, a0, 16
    ret


/* ============================================================
 * fp_add
 *
 * a0 = a0 + a1
 *
 * Q16.16 addition is just integer addition.
 * ============================================================ */

.globl fp_add
fp_add:
    add     a0, a0, a1
    ret


/* ============================================================
 * fp_sub
 *
 * a0 = a0 - a1
 * ============================================================ */

.globl fp_sub
fp_sub:
    sub     a0, a0, a1
    ret


/* ============================================================
 * fp_neg
 *
 * a0 = -a0
 * ============================================================ */

.globl fp_neg
fp_neg:
    neg     a0, a0
    ret



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
    li      t5, 48

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
    bnez    t5, 3b

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
