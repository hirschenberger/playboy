.section .text
.global draw_title

# a0: how many milliseconds to display
draw_title:
        addi sp, sp, -16
        .equ DRAW_TITLE_RA, 12
        sw ra, DRAW_TITLE_RA(sp)
      
        la s1, rainbow_colors         # colortable ptr
        la s2, rainbow_colors_end     # colortable end ptr
        mv s3, a0                     # wait ms
        li t0, 1000
        mul s3, s3, t0               # wait us

        call timer0_read_us
        mv s4, a1                     # start time
        
1:
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

        li a0, 15
        call delay_ms

        # Move the rainbow phase backward by one RGB565 entry per frame.
        addi s1, s1, -2
        la t0, rainbow_colors
        bgeu s1, t0, 1b

        # The decrement passed the first entry; wrap to the final entry.
        addi s1, s2, -2

        # check timeout
        call timer0_read_us
        add a1, s4, s3
        blt a0, a1, 1b 
        
        lw ra, DRAW_TITLE_RA(sp)
        addi sp, sp, 16
        ret

.section .rodata
hello_text:
    .asciz   "   TAKE FIVE    "

