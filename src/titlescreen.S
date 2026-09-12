.global draw_title

.section .text

# ------------------------------------------------------------------------------
# Draw the title screen for a given display time.
#
# In:
#   * a0: how many milliseconds to display
draw_title:
        addi sp, sp, -32
        sw ra, 28(sp)
        sw s1, 24(sp)
        sw s2, 20(sp)
        sw s3, 16(sp)
        sw s4, 12(sp)

        la s1, rainbow_colors         # colortable ptr
        la s2, rainbow_colors_end     # colortable end ptr
        mv s3, a0                     # display time in milliseconds
        li t0, 1000
        mul s3, s3, t0                # display time in microseconds

        call timer0_read_us
        mv s4, a0                     # start time, low word

.Lnext_cycle:
        li a0, 20
        li a1, 80
        li a2, 280
        li a3, 10
        lhu a4, 0(s1)
        call fill_rect

        li a0, 20
        li a1, 104
        la a2, hello_text
        mv a3, s1                  # current colortable pointer
        li a4, 3
        call draw_rainbow_string

        li a0, 20
        li a1, 140
        li a2, 280
        li a3, 10
        lhu a4, 0(s1)
        call fill_rect

        # Push the completed title frame to the panel.
        call flip_buffer

        li a0, 5
        call delay_ms

        # Move the rainbow phase backward by one RGB565 entry per frame.
        addi s1, s1, -2
        la t0, rainbow_colors
        bgeu s1, t0, .Lnext_cycle

        # The decrement passed the first entry; wrap to the final entry.
        addi s1, s2, -2

        # check timeout
        call timer0_read_us
        sub t0, a0, s4
        bltu t0, s3, .Lnext_cycle

        lw ra, 28(sp)
        lw s1, 24(sp)
        lw s2, 20(sp)
        lw s3, 16(sp)
        lw s4, 12(sp)
        addi sp, sp, 32
        ret

# ------------------------------------------------------------------------------
.section .rodata
hello_text:
        .asciz   "   TAKE FIVE    "
