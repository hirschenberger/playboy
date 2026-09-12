.global _reset_handler, _trap_handler

.section .reset, "ax"             # Kept at the boot address by the linker script.
.align 2                          # Instructions and word accesses require 4-byte alignment.
.type _reset_handler, @function
_reset_handler:
        csrr t0, mhartid              # 0 = core 0, 1 = core 1.
        bnez t0, .Lcore1              # Core 1 parks on its own stack below.

        la sp, __stack_top            # The stack grows downward from the top of SRAM.

        # Copy initialized writable data from its flash load address into SRAM.
        la t0, __data_load_start
        la t1, __data_start
        la t2, __data_end
1:
        bgeu t1, t2, 2f
        lw t3, 0(t0)                  # Read one initialized word from XIP flash.
        sw t3, 0(t1)                  # Write it to the corresponding RAM address.
        addi t0, t0, 4
        addi t1, t1, 4
        j 1b

2:
        # Zero .bss so C-style uninitialized globals start with defined values.
        la t1, __bss_start
        la t2, __bss_end
3:
        bgeu t1, t2, 4f
        sw zero, 0(t1)
        addi t1, t1, 4
        j 3b

4:
        call main                     # Application code should not return.
5:
        wfi                           # If it does, sleep rather than falling into data.
        j 5b

# ------------------------------------------------------------------------------
# Core 1 does no work yet; it sleeps on its own stack with interrupts enabled
# only conceptually. Trap handlers and wake sources are added later.
.Lcore1:
        la sp, __stack_top_core1      # Each core needs its own stack.
.Lcore1_idle:
        wfi                           # Sleep until an interrupt, then stay asleep.
        j .Lcore1_idle

.type _trap_handler, @function
_trap_handler:
        # A trap is fatal in this minimal runtime. Halt here for SWD inspection.
        wfi
        j _trap_handler
