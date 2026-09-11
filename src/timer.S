#include "rp2350.h"

.global timer0_init, timer0_read_us, delay_ms

.section .text
.align 2

# ------------------------------------------------------------------------------
# Configure TIMER0 to count the dedicated TIMER0 tick, one tick per us.
timer0_init:
        li t0, RESETS_BASE
        lw t1, RESETS_RESET(t0)
        li t2, RESETS_TIMER0_BIT
        not t2, t2
        and t1, t1, t2
        sw t1, RESETS_RESET(t0)
0:
        lw t1, RESETS_RESET_DONE(t0)
        li t2, RESETS_TIMER0_BIT
        and t1, t1, t2
        beqz t1, 0b

        li t0, TIMER0_BASE
        li t1, TIMER_SOURCE_TICK
        sw t1, TIMER_SOURCE(t0)

        li t0, TICKS_BASE
        sw zero, TICKS_TIMER0_CTRL(t0)
        li t1, TICKS_TIMER0_1US
        sw t1, TICKS_TIMER0_CYCLES(t0)
        li t1, TICKS_TIMER0_ENABLE
        sw t1, TICKS_TIMER0_CTRL(t0)
        ret

# ------------------------------------------------------------------------------
# Read the TIMER0 microseconds counter.
#
# Out:
#   * a1:a0: microseconds since timer0_init (64-bit value)
timer0_read_us:
        li t0, TIMER0_BASE
        lw a0, TIMER_TIMELR(t0)
        lw a1, TIMER_TIMEHR(t0)
        ret

# ------------------------------------------------------------------------------
# Delay for a number of milliseconds using the 1 tick / us TIMER0.
#
# In:
#   * a0: milliseconds
#
# Usable for delays shorter than roughly 71 minutes.
delay_ms:
        li t0, 1000
        mul t1, a0, t0

        # start time
        li t0, TIMER0_BASE
        lw t2, TIMER_TIMELR(t0)
.Lloop:
        lw t3, TIMER_TIMELR(t0)
        sub t3, t3, t2
        bltu t3, t1, .Lloop
        ret
