#include "rp2350.h"
#include "lcd.h"

.global write_color, lcd_clear, fill_rect, draw_rainbow_string, draw_rainbow_char
.global rainbow_colors_end, rainbow_colors, draw_buffer, write_buffer

.section .text
# ------------------------------------------------------------------------------
# Write a solid RGB565 color for a pixel count.
#
# In:
#   * a0: RGB565 color
#   * a1: pixel count
#
# set_window must already have selected the LCD.
write_color:
    srli t2, a0, 8
    andi t3, a0, 0xff
    li t0, SPI1_BASE
.Lwc_batch_loop:
    beqz a1, .Lwc_done
    # The RP2350 SPI FIFO holds eight bytes. Send up to four pixels before
    # draining their matching RX bytes, keeping the transmitter full safely.
    li t4, 4
    bge a1, t4, .Lwc_size_ok
    mv t4, a1
.Lwc_size_ok:
    mv t5, t4
.Lwc_send_hi:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_TNF
    beqz t1, .Lwc_send_hi
    sh t2, SPI_DR(t0)
.Lwc_send_lo:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_TNF
    beqz t1, .Lwc_send_lo
    sh t3, SPI_DR(t0)
    addi t5, t5, -1
    bnez t5, .Lwc_send_hi

    slli t5, t4, 1
.Lwc_drain_loop:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_RNE
    beqz t1, .Lwc_drain_loop
    lw t1, SPI_DR(t0)
    addi t5, t5, -1
    bnez t5, .Lwc_drain_loop
    sub a1, a1, t4
    j .Lwc_batch_loop
.Lwc_done:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_BSY
    bnez t1, .Lwc_done
    li t0, SIO_BASE
    li t1, LCD_CS_MASK
    sw t1, SIO_GPIO_OUT_SET(t0)
    ret

# ------------------------------------------------------------------------------
# Stream the entire framebuffer to the panel in a single RAMWR pass
# instead of issuing set_window/write_color per pixel.
#
# In:
#   * a0: buffer address
draw_buffer:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)

    mv s0, a0                # save buffer address

    li a0, 0
    li a1, SCREEN_WIDTH-1
    li a2, 0
    li a3, SCREEN_HEIGHT-1
    call set_window

    mv a0, s0
    call write_buffer

    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    ret

# ------------------------------------------------------------------------------
# Write all SCREEN_WIDTH*SCREEN_HEIGHT pixels (BUFFER_BYTES bytes) row-major
# in one pass, byte at a time, batching into the 8-byte FIFO to stay within
# the RP2350 SPI's TX/RX depth, then raises CS.
#
# In:
#   * a0: buffer address
#
# set_window must already have selected the LCD and left CS low in data mode.
write_buffer:
    li t0, SPI1_BASE
    li t2, BUFFER_BYTES      # bytes remaining
.Lwb_batch_loop:
    beqz t2, .Lwb_done
    li t4, 4
    bge t2, t4, .Lwb_size_ok
    mv t4, t2
.Lwb_size_ok:
    mv t5, t4                # bytes to send this batch
.Lwb_send_loop:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_TNF
    beqz t1, .Lwb_send_loop
    lbu t6, 0(a0)
    sb t6, SPI_DR(t0)
    addi a0, a0, 1
    addi t5, t5, -1
    bnez t5, .Lwb_send_loop

    mv t5, t4                # drain matching RX bytes
.Lwb_drain_loop:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_RNE
    beqz t1, .Lwb_drain_loop
    lw t1, SPI_DR(t0)
    addi t5, t5, -1
    bnez t5, .Lwb_drain_loop

    sub t2, t2, t4
    j .Lwb_batch_loop
.Lwb_done:
    lw t1, SPI_SR(t0)
    andi t1, t1, SPI_SR_BSY
    bnez t1, .Lwb_done
    li t0, SIO_BASE
    li t1, LCD_CS_MASK
    sw t1, SIO_GPIO_OUT_SET(t0)
    ret

# ------------------------------------------------------------------------------
# Clear all 320*240 pixels.
#
# In:
#   * a0: RGB565 fill color
lcd_clear:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)

    mv s0, a0                           # save color

    li a0, 0
    li a1, SCREEN_WIDTH - 1
    li a2, 0
    li a3, SCREEN_HEIGHT - 1
    call set_window

    mv a0, s0
    li a1, SCREEN_WIDTH * SCREEN_HEIGHT
    call write_color

    lw ra, 12(sp)
    lw s0, 8(sp)
    addi sp, sp, 16
    ret

# ------------------------------------------------------------------------------
# Fill a rectangle.
#
# In:
#   * a0: x
#   * a1: y
#   * a2: width
#   * a3: height
#   * a4: RGB565 color
fill_rect:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)

    mv s0, a2                  # rect width
    mv s1, a3                  # rect height
    mv s2, a4                  # color

    add t0, a0, a2
    addi t0, t0, -1
    add t1, a1, a3
    addi t1, t1, -1

    mv a2, a1
    mv a1, t0
    mv a3, t1
    call set_window

    mv a0, s2
    mul a1, s0, s1             # width * height
    call write_color

    lw ra, 28(sp)
    lw s0, 24(sp)
    lw s1, 20(sp)
    lw s2, 16(sp)
    addi sp, sp, 32
    ret


# ------------------------------------------------------------------------------
# Draw a string with per-column rainbow colors.
#
# In:
#   * a0: x
#   * a1: y
#   * a2: NUL-terminated ASCII
#   * a3: color table address
#   * a4: scale
#
# Out:
#   * a0: next color-table pointer
#
# Register map:
#   * s0: current x
#   * s1: y
#   * s2: text pointer
#   * s3: current color-table pointer
#   * s4: scale
#   * s5: glyph advance in pixels
#   * t0: current ASCII byte
draw_rainbow_string:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    sw s3, 12(sp)
    sw s4, 8(sp)
    sw s5, 4(sp)

    mv s0, a0
    mv s1, a1
    mv s2, a2
    mv s3, a3
    mv s4, a4
    li s5, 6
    mul s5, s5, s4             # five glyph columns plus one spacing column

.Lrainbow_string_loop:
    lbu t0, 0(s2)
    beqz t0, .Lrainbow_string_done

    mv a0, s0
    mv a1, s1
    mv a2, s3
    mv a3, s4
    mv a4, t0
    call draw_rainbow_char
    mv s3, a0

    add s0, s0, s5
    addi s2, s2, 1
    j .Lrainbow_string_loop

.Lrainbow_string_done:
    mv a0, s3
    lw ra, 28(sp)
    lw s0, 24(sp)
    lw s1, 20(sp)
    lw s2, 16(sp)
    lw s3, 12(sp)
    lw s4, 8(sp)
    lw s5, 4(sp)
    addi sp, sp, 32
    ret

# ------------------------------------------------------------------------------
# Draw a string in a single color.
#
# In:
#   * a0: x
#   * a1: y
#   * a2: NUL-terminated ASCII
#   * a3: color
#   * a4: scale
#
# Register map:
#   * s0: current x
#   * s1: y
#   * s2: text pointer
#   * s3: color
#   * s4: scale
#   * s5: glyph advance in pixels
#   * t0: current ASCII byte
draw_string:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    sw s3, 12(sp)
    sw s4, 8(sp)
    sw s5, 4(sp)

    mv s0, a0
    mv s1, a1
    mv s2, a2
    mv s3, a3
    mv s4, a4
    li s5, 6
    mul s5, s5, s4             # five glyph columns plus one spacing column

.Ldraw_string_loop:
    lbu t0, 0(s2)
    beqz t0, .Ldraw_string_done

    mv a0, s0
    mv a1, s1
    mv a2, s3
    mv a3, s4
    mv a4, t0
    call draw_char

    add s0, s0, s5
    addi s2, s2, 1
    j .Ldraw_string_loop

.Ldraw_string_done:
    lw ra, 28(sp)
    lw s0, 24(sp)
    lw s1, 20(sp)
    lw s2, 16(sp)
    lw s3, 12(sp)
    lw s4, 8(sp)
    lw s5, 4(sp)
    addi sp, sp, 32
    ret

# ------------------------------------------------------------------------------
# Draw one glyph with a transient color per column.
#
# In:
#   * a0: x
#   * a1: y
#   * a2: current color-table pointer
#   * a3: scale
#   * a4: ASCII character
#
# Out:
#   * a0: next color-table pointer
#
# Each glyph column uses one color-table entry.
#
# Register map:
#   * s0: base x
#   * s1: base y
#   * s2: current color-table pointer
#   * s3: scale
#   * s4: font pointer
#   * s5: glyph column
#   * s6: glyph row
#   * s7: current glyph column bitmap
#   * t0: scratch
#   * t1: scratch
draw_rainbow_char:
    addi sp, sp, -48
    sw ra, 44(sp)
    sw s0, 40(sp)
    sw s1, 36(sp)
    sw s2, 32(sp)
    sw s3, 28(sp)
    sw s4, 24(sp)
    sw s5, 20(sp)
    sw s6, 16(sp)
    sw s7, 12(sp)

    mv s0, a0
    mv s1, a1
    mv s2, a2
    mv s3, a3
    addi a4, a4, -32
    li t0, 5
    mul a4, a4, t0
    la s4, font5x7
    add s4, s4, a4
    li s5, 0

.Lrainbow_char_col_loop:
    li t0, 5
    bge s5, t0, .Lrainbow_char_done

    add t0, s4, s5
    lbu s7, 0(t0)
    li s6, 0

.Lrainbow_char_row_loop:
    li t0, 7
    bge s6, t0, .Lrainbow_char_next_col

    li t0, 1
    sll t0, t0, s6
    and t0, t0, s7
    beqz t0, .Lrainbow_char_next_row

    mul t0, s5, s3
    add a0, s0, t0
    mul t1, s6, s3
    add a1, s1, t1
    mv a2, s3
    mv a3, s3
    lhu a4, 0(s2)
    call fill_rect

.Lrainbow_char_next_row:
    addi s6, s6, 1
    j .Lrainbow_char_row_loop

.Lrainbow_char_next_col:
    addi s2, s2, 2
    la t0, rainbow_colors_end
    bltu s2, t0, .Lrainbow_char_color_ok
    la s2, rainbow_colors
.Lrainbow_char_color_ok:
    addi s5, s5, 1
    j .Lrainbow_char_col_loop

.Lrainbow_char_done:
    mv a0, s2
    lw ra, 44(sp)
    lw s0, 40(sp)
    lw s1, 36(sp)
    lw s2, 32(sp)
    lw s3, 28(sp)
    lw s4, 24(sp)
    lw s5, 20(sp)
    lw s6, 16(sp)
    lw s7, 12(sp)
    addi sp, sp, 48
    ret

# ------------------------------------------------------------------------------
# Draw one glyph in a single color. Font is 5 columns x 7 rows.
#
# In:
#   * a0: x
#   * a1: y
#   * a2: color
#   * a3: scale
#   * a4: ASCII character
#
# Register map:
#   * s0: base x
#   * s1: base y
#   * s2: color
#   * s3: scale
#   * s4: font pointer
#   * s5: glyph column
#   * s6: glyph row
#   * s7: current glyph column bitmap
#   * t0: scratch
#   * t1: scratch
draw_char:
    addi sp, sp, -48
    sw ra, 44(sp)
    sw s0, 40(sp)
    sw s1, 36(sp)
    sw s2, 32(sp)
    sw s3, 28(sp)
    sw s4, 24(sp)
    sw s5, 20(sp)
    sw s6, 16(sp)
    sw s7, 12(sp)

    mv s0, a0
    mv s1, a1
    mv s2, a2
    mv s3, a3
    addi a4, a4, -32
    li t0, 5
    mul a4, a4, t0
    la s4, font5x7
    add s4, s4, a4
    li s5, 0

.Ldraw_char_col_loop:
    li t0, 5
    bge s5, t0, .Ldraw_char_done

    add t0, s4, s5
    lbu s7, 0(t0)
    li s6, 0

.Ldraw_char_row_loop:
    li t0, 7
    bge s6, t0, .Ldraw_char_next_col

    li t0, 1
    sll t0, t0, s6
    and t0, t0, s7
    beqz t0, .Ldraw_char_next_row

    mul t0, s5, s3
    add a0, s0, t0
    mul t1, s6, s3
    add a1, s1, t1
    mv a2, s3
    mv a3, s3
    mv a4, s2
    call fill_rect

.Ldraw_char_next_row:
    addi s6, s6, 1
    j .Ldraw_char_row_loop

.Ldraw_char_next_col:
    addi s5, s5, 1
    j .Ldraw_char_col_loop

.Ldraw_char_done:
    lw ra, 44(sp)
    lw s0, 40(sp)
    lw s1, 36(sp)
    lw s2, 32(sp)
    lw s3, 28(sp)
    lw s4, 24(sp)
    lw s5, 20(sp)
    lw s6, 16(sp)
    lw s7, 12(sp)
    addi sp, sp, 48
    ret

.section .rodata
# Printable ASCII 0x20 through 0x5a; columns are LSB-top bitmap data.
font5x7:
    .byte 0,0,0,0,0, 0,0,95,0,0, 0,7,0,7,0, 20,127,20,127,20
    .byte 36,42,127,42,18, 35,19,8,100,98, 54,73,85,34,80, 0,5,3,0,0
    .byte 0,28,34,65,0, 0,65,34,28,0, 20,8,62,8,20, 8,8,62,8,8
    .byte 0,80,48,0,0, 8,8,8,8,8, 0,96,96,0,0, 32,16,8,4,2
    .byte 62,81,73,69,62, 0,66,127,64,0, 66,97,81,73,70, 33,65,69,75,49
    .byte 24,20,18,127,16, 39,69,69,69,57, 60,74,73,73,48, 1,113,9,5,3
    .byte 54,73,73,73,54, 6,73,73,41,30, 0,54,54,0,0, 0,86,54,0,0
    .byte 8,20,34,65,0, 20,20,20,20,20, 0,65,34,20,8, 2,1,81,9,6
    .byte 50,73,121,65,62
    .byte 126,17,17,17,126, 127,73,73,73,54, 62,65,65,65,34, 127,65,65,34,28
    .byte 127,73,73,73,65, 127,9,9,9,1, 62,65,73,73,122, 127,8,8,8,127
    .byte 0,65,127,65,0, 32,64,65,63,1, 127,8,20,34,65, 127,64,64,64,64
    .byte 127,2,12,2,127, 127,4,8,16,127, 62,65,65,65,62, 127,9,9,9,6
    .byte 62,65,81,33,94, 127,9,25,41,70, 70,73,73,73,49, 1,1,127,1,1
    .byte 63,64,64,64,63, 31,32,64,32,31, 63,64,56,64,63, 99,20,8,20,99
    .byte 7,8,112,8,7, 97,81,73,69,67

.align 1
rainbow_colors:
    .hword 0xF800, 0xF820, 0xF860, 0xF880, 0xF8C0, 0xF8E0, 0xF920, 0xF940
    .hword 0xF980, 0xF9A0, 0xF9E0, 0xFA00, 0xFA40, 0xFA60, 0xFAA0, 0xFAC0
    .hword 0xFB00, 0xFB20, 0xFB60, 0xFB80, 0xFBC0, 0xFBE0, 0xFC00, 0xFC40
    .hword 0xFC60, 0xFCA0, 0xFCC0, 0xFD00, 0xFD20, 0xFD60, 0xFD80, 0xFDC0
    .hword 0xFDE0, 0xFE20, 0xFE40, 0xFE80, 0xFEA0, 0xFEE0, 0xFF00, 0xFF40
    .hword 0xFF60, 0xFFA0, 0xFFC0, 0xFFE0, 0xF7E0, 0xF7E0, 0xEFE0, 0xE7E0
    .hword 0xDFE0, 0xDFE0, 0xD7E0, 0xCFE0, 0xC7E0, 0xC7E0, 0xBFE0, 0xB7E0
    .hword 0xAFE0, 0xAFE0, 0xA7E0, 0x9FE0, 0x97E0, 0x97E0, 0x8FE0, 0x87E0
    .hword 0x87E0, 0x7FE0, 0x77E0, 0x6FE0, 0x6FE0, 0x67E0, 0x5FE0, 0x57E0
    .hword 0x57E0, 0x4FE0, 0x47E0, 0x3FE0, 0x3FE0, 0x37E0, 0x2FE0, 0x27E0
    .hword 0x27E0, 0x1FE0, 0x17E0, 0x0FE0, 0x0FE0, 0x07E0, 0x07E0, 0x07E1
    .hword 0x07E2, 0x07E2, 0x07E3, 0x07E4, 0x07E5, 0x07E5, 0x07E6, 0x07E7
    .hword 0x07E8, 0x07E8, 0x07E9, 0x07EA, 0x07EB, 0x07EB, 0x07EC, 0x07ED
    .hword 0x07EE, 0x07EE, 0x07EF, 0x07F0, 0x07F0, 0x07F1, 0x07F2, 0x07F3
    .hword 0x07F3, 0x07F4, 0x07F5, 0x07F6, 0x07F6, 0x07F7, 0x07F8, 0x07F9
    .hword 0x07F9, 0x07FA, 0x07FB, 0x07FC, 0x07FC, 0x07FD, 0x07FE, 0x07FF
    .hword 0x07FF, 0x07DF, 0x079F, 0x077F, 0x073F, 0x071F, 0x06DF, 0x06BF
    .hword 0x067F, 0x065F, 0x061F, 0x05FF, 0x05BF, 0x059F, 0x055F, 0x053F
    .hword 0x04FF, 0x04DF, 0x049F, 0x047F, 0x043F, 0x041F, 0x03FF, 0x03BF
    .hword 0x039F, 0x035F, 0x033F, 0x02FF, 0x02DF, 0x029F, 0x027F, 0x023F
    .hword 0x021F, 0x01DF, 0x01BF, 0x017F, 0x015F, 0x011F, 0x00FF, 0x00BF
    .hword 0x009F, 0x005F, 0x003F, 0x001F, 0x081F, 0x081F, 0x101F, 0x181F
    .hword 0x201F, 0x201F, 0x281F, 0x301F, 0x381F, 0x381F, 0x401F, 0x481F
    .hword 0x501F, 0x501F, 0x581F, 0x601F, 0x681F, 0x681F, 0x701F, 0x781F
    .hword 0x801F, 0x801F, 0x881F, 0x901F, 0x901F, 0x981F, 0xA01F, 0xA81F
    .hword 0xA81F, 0xB01F, 0xB81F, 0xC01F, 0xC01F, 0xC81F, 0xD01F, 0xD81F
    .hword 0xD81F, 0xE01F, 0xE81F, 0xF01F, 0xF01F, 0xF81F, 0xF81F, 0xF81E
    .hword 0xF81D, 0xF81D, 0xF81C, 0xF81B, 0xF81A, 0xF81A, 0xF819, 0xF818
    .hword 0xF817, 0xF817, 0xF816, 0xF815, 0xF814, 0xF814, 0xF813, 0xF812
    .hword 0xF811, 0xF811, 0xF810, 0xF80F, 0xF80F, 0xF80E, 0xF80D, 0xF80C
    .hword 0xF80C, 0xF80B, 0xF80A, 0xF809, 0xF809, 0xF808, 0xF807, 0xF806
    .hword 0xF806, 0xF805, 0xF804, 0xF803, 0xF803, 0xF802, 0xF801, 0xF800
rainbow_colors_end:
