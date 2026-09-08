#include "rp2350.h"

.section .text
.align 2
.global timer0_init, timer0_read_us, delay_ms

# Configure TIMER0 to count the dedicated TIMER0 tick, with one tick per µs.
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

# Returns TIMER0 microseconds since timer0_init as a 64-bit value: a1:a0.
timer0_read_us:
    li t0, TIMER0_BASE
    lw a0, TIMER_TIMELR(t0)
    lw a1, TIMER_TIMEHR(t0)
    ret

# a0=milliseconds. Uses the 1 tick / us TIMER0.
# This can be used for delays < ~71min.
delay_ms:
    li t0, 1000
    mul t1, a0, t0

    # start time
    li t0, TIMER0_BASE
    lw t2, TIMER_TIMELR(t0)
1:
    lw t3, TIMER_TIMELR(t0)
    sub t3, t3, t2
    bltu t3, t1, 1b
    ret
    
