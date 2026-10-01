.include "rp2350.h"

.global core1_main, launch_core1

# ------------------------------------------------------------------------------
.section .text
.align 2

# ------------------------------------------------------------------------------
# Launch code on Processor Core 1 using the SIO inter-core FIFO and the ROM
# launch protocol (RP2350 datasheet, section 5.3).
#
# On the RP2350, core 1 is held in reset by the boot ROM and does NOT start
# from the reset vector on its own.  Core 0 must push a command sequence into
# the SIO inter-core FIFO; the boot ROM on core 1 consumes it and starts core 1
# at the supplied entry point with the supplied stack pointer.  Each command is
# echoed back through the FIFO and must match, otherwise the sequence restarts.
#
# This routine is non-blocking: if core 1 does not respond within a timeout it
# returns with a0 = 0 so the caller can continue without core 1.
#
# In:
#   * a0: vector table address for core 1
#   * a1: initial stack pointer for core 1
#   * a2: entry point address for core 1
#
# Out:
#   * a0: 1 if core 1 was launched, 0 on timeout
#
# Register map:
#   * s0: current command word / sequence pointer
#   * s1: end of command sequence
#   * s2: command word being sent
launch_core1:
        addi sp, sp, -16
        sw ra, 12(sp)
        sw s0, 8(sp)
        sw s1, 4(sp)
        sw s2, 0(sp)

        la s0, .Llaunch_cmd_seq
        sw a0, 12(s0)               # vector table
        sw a1, 16(s0)               # stack pointer
        sw a2, 20(s0)               # entry point
.Llaunch_restart:
        la s0, .Llaunch_cmd_seq
        la s1, .Llaunch_cmd_seq_end
.Llaunch_next:
        lw s2, 0(s0)                # read next command word
        bnez s2, .Llaunch_write     # skip FIFO drain unless it is a zero command
        call fifo_drain             # clear any stale queue before a zero command
        slt x0, x0, x1              # h3.unblock: core 1 may be waiting for FIFO
                                    # space via h3.block (matches the Pico SDK)
.Llaunch_write:
        mv a0, s2
        call fifo_write_blocking    # send the command to core 1
        call fifo_read_blocking     # read the echo back (result in a0)
        beqz a0, .Llaunch_timeout   # a0 == 0 means the read timed out
        bne s2, a0, .Llaunch_restart # restart the sequence if the echo mismatches
        addi s0, s0, 4
        blt s0, s1, .Llaunch_next

        li a0, 1                    # success
        j .Llaunch_done
.Llaunch_timeout:
        la t0, .Llaunch_cmd_seq
        sub a0, s0, t0              # byte offset into command sequence
        srli a0, a0, 2              # step index (0-5)
        call launch_diag_fail       # print the failing step
        li a0, 0                    # core 1 did not respond
.Llaunch_done:
        lw ra, 12(sp)
        lw s0, 8(sp)
        lw s1, 4(sp)
        lw s2, 0(sp)
        addi sp, sp, 16
        ret

# ------------------------------------------------------------------------------
# Diagnostic: print the step index (0-5) where launch failed, as a hex digit.
#
# In:
#   * a0: step index
launch_diag_fail:
        addi sp, sp, -4
        sw ra, 0(sp)
        call print_hex_digit
        li a0, 0x20                 # space
        call uart_write_byte
        lw ra, 0(sp)
        addi sp, sp, 4
        ret

# ------------------------------------------------------------------------------
# Write one word to the SIO inter-core FIFO, blocking until there is room.
#
# In:
#   * a0: word to write
#
# Register map:
#   * t0: SIO base
#   * t1: FIFO status
fifo_write_blocking:
        li t0, SIO_BASE
1:
        lw t1, SIO_FIFO_ST(t0)      # read FIFO status
        andi t1, t1, SIO_FIFO_ST_RDY # is there room to write?
        beqz t1, 1b
        sw a0, SIO_FIFO_WR(t0)      # write the word
        slt x0, x0, x1              # h3.unblock: wake the other core (it may be
                                    # halted in h3.block waiting for this data)
        ret

# ------------------------------------------------------------------------------
# Read one word from the SIO inter-core FIFO, busy-waiting until data is
# available or a timeout elapses.  A pure busy-wait (no h3.block) is used so
# the timeout is always honoured and the caller can never hang.
#
# Out:
#   * a0: word read from the FIFO, or 0 on timeout
#
# Register map:
#   * t0: SIO base / TIMER0 base
#   * t1: FIFO status / current time
#   * t2: timeout deadline (low word)
fifo_read_blocking:
        li t0, TIMER0_BASE
        lw t2, TIMER_TIMELR(t0)     # start time
        li t1, 100000               # 100 ms timeout
        add t2, t2, t1              # deadline
        li t0, SIO_BASE
1:
        lw t1, SIO_FIFO_ST(t0)      # read FIFO status
        andi t1, t1, SIO_FIFO_ST_VLD # is there data to read?
        bnez t1, 2f
        li t0, TIMER0_BASE
        lw t1, TIMER_TIMELR(t0)     # current time
        bltu t1, t2, 1b             # loop until deadline
        li a0, 0                    # timeout
        ret
2:
        li t0, SIO_BASE
        lw a0, SIO_FIFO_RD(t0)      # read the word
        ret

# ------------------------------------------------------------------------------
# Discard all pending words from the SIO inter-core FIFO.
#
# Register map:
#   * t0: SIO base
#   * t1: FIFO status
fifo_drain:
        li t0, SIO_BASE
1:
        lw t1, SIO_FIFO_ST(t0)      # read FIFO status
        andi t1, t1, SIO_FIFO_ST_VLD # is there data to read?
        beqz t1, 2f
        lw t1, SIO_FIFO_RD(t0)      # read and discard
        j 1b
2:
        ret

# ------------------------------------------------------------------------------
# Print a single hex digit (0-9, A-F) to UART.  Used for launch diagnostics.
#
# In:
#   * a0: value 0-15 to print
#
# Register map:
#   * t0: hex digit character
print_hex_digit:
        addi t0, a0, 0x30           # '0' + value
        li t1, 0x3a                 # ':' (just past '9')
        blt t0, t1, 1f
        addi t0, t0, 7              # shift to 'A'-'F'
1:
        mv a0, t0
        j uart_write_byte

# ------------------------------------------------------------------------------
# Core 1 entry point.  The boot ROM starts core 1 here after launch_core1.
core1_main:
        la a0, core1_start_msg
        call uart_write_string

.Lloop:
        li a0, 1000
        call delay_ms

        j .Lloop

# ------------------------------------------------------------------------------
.section .data
.Llaunch_cmd_seq:
        .word 0                     # drain marker
        .word 0                     # drain marker
        .word 1                     # launch command
        .word 0                     # vector table (patched by launch_core1)
        .word 0                     # stack pointer (patched by launch_core1)
        .word 0                     # entry point (patched by launch_core1)
.Llaunch_cmd_seq_end:

# ------------------------------------------------------------------------------
.section .rodata
core1_start_msg:
        .ascii  "    **************************************\n"
        .ascii  "    * Core 1 online                      *\n"
        .asciz  "    **************************************"
