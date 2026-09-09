# -*- mode: Assembly -*-
/* ============================================================
 * Q16.16 Constants
 * ============================================================ */

.equ FP_SHIFT, 16
.equ FP_ONE,   65536
.equ FP_HALF,  32768
.equ FP_ZERO,  0
.equ FP_EPSILON, 1

.macro FP_100 v
    .word ((v * FP_ONE + 50) / 100)
.endm



/* ============================================================
 * fp_mul_fast
 *
 * Faster version when overflow of the 32-bit multiplication
 * intermediate is known not to matter.
 *
 * result = (a * b) >> 16
 *
 * This is usually enough for game physics when values are
 * kept within reasonable ranges.
 * ============================================================ */

.macro FP_MUL_FAST a b c
    mul     \b, \b, \c
    srai    \a, \b, 16
.endm

.macro FP_MUL_Q16 dst lhs rhs scratch
    mul     \dst, \lhs, \rhs
    mulh    \scratch, \lhs, \rhs
    srli    \dst, \dst, 16
    slli    \scratch, \scratch, 16
    or      \dst, \dst, \scratch
.endm


.macro FP_RECIP a b
    li \a, 1
    sll \a, \a, 16
    div \a, \a, \b
.endm

/* ============================================================
 * fp_abs
 *
 * a0 = abs(a0)
 * ============================================================ */

.macro FP_ABS a
    bgez    \a, .Lfp_abs_done\@
    neg     \a, \a
.Lfp_abs_done\@:
.endm

/* ============================================================
 * fp_div_fast
 *
 * Faster but limited version.
 *
 * If:
 *
 *   abs(a) << 16
 *
 * fits in signed 32-bit range, this is sufficient.
 *
 * Useful for many small game values.
 *
 * ============================================================ */

.macro FP_DIV_FAST a b c
    slli    \b, \b, 16
    div     \a, \b, \c
.endm

/* ============================================================
 * fp_mul_int
 *
 * Q16.16 × integer -> Q16.16
 *
 * b = fixed point
 * c = integer
 *
 * No shift required.
 * ============================================================ */

.macro FP_MUL_INT a b c
    li      \a, \c
    mul     \a, \a, \b
.endm


/* ============================================================
 * fp_div_int
 *
 * Q16.16 / integer -> Q16.16
 *
 * No scaling required.
 * ============================================================ */

.macro FP_DIV_INT a b
    div     \a, \a, \b
.endm

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

.macro FP_TO_INT a b
    srai    \a, \b, 16
.endm
