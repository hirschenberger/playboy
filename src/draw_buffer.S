#include "lcd.h"
.global draw_rect, flip_buffer

.section .text
.align 2

# ------------------------------------------------------------------------------
# Draw an axis-aligned rectangle into the framebuffer.
#
# In:
#   * a0: x
#   * a1: y
#   * a2: width
#   * a3: height
#   * a4: RGB565 color
draw_rect:
        # t0 = framebuffer address
        la      t0, .Ldraw_buffer

        # Calculate offset of (x, y)
        #
        # pixel_index = y * SCREEN_WIDTH + x
        # byte_offset = pixel_index * 2

        li      t1, SCREEN_WIDTH
        mul     t1, a1, t1          # y * SCREEN_WIDTH
        add     t1, t1, a0          # + x
        slli    t1, t1, 1           # * 2 bytes/pixel

        add     t0, t0, t1          # t0 = address of first pixel

        # t2 = rows remaining
        mv      t2, a3

row_loop:
        beqz    t2, done

        # t3 = pixels remaining
        mv      t3, a2

pixel_loop:
        beqz    t3, row_done

        rev8    t4, a4              # convert RGB565 to little-endian
        srli    t4, t4, 16
        sh      t4, 0(t0)           # write 16-bit RGB565 pixel

        addi    t0, t0, 2           # next pixel
        addi    t3, t3, -1
        j       pixel_loop

row_done:
        # We've advanced width pixels.
        # Skip the rest of the framebuffer row.
        #
        # (SCREEN_WIDTH - width) * 2

        li      t4, SCREEN_WIDTH
        sub     t4, t4, a2
        slli    t4, t4, 1
        add     t0, t0, t4

        addi    t2, t2, -1
        j       row_loop

done:
        ret

# ------------------------------------------------------------------------------
# Copy the framebuffer to the LCD panel.
flip_buffer:
        addi sp, sp, -16
        sw ra, 12(sp)

        la a0, .Ldraw_buffer
        call draw_buffer

        lw ra, 12(sp)
        addi sp, sp, 16
        ret

# ------------------------------------------------------------------------------
.section .bss
.align 2
.Ldraw_buffer:
        .space BUFFER_BYTES
