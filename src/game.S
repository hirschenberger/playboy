#include "macros.h"
#include "math.h"

.section .text
.align 2
.global gameloop
.extern fp_div

.equ TARGET_FPS, 100
.equ FRAME_TIME_US, 1000 * 1000 / TARGET_FPS

.equ MAP_WIDTH, 32
.equ MAP_HEIGHT, 32
.equ SCREEN_WIDTH, 320
.equ SCREEN_HEIGHT, 200

# ***************************************************
# This starts the main gameloop performing the following steps
#   * handle input
#   * update game state
#   * render the frame
#   * wait till the frame's deadline is reached for constane fps
gameloop:
        LOG_STRING enter_gameloop_msg

.Lnext_frame:
        call set_frame_start
        call read_input
        call game_update
        call render_frame
        call wait_frame_time

        j .Lnext_frame



read_input:
        ret

game_update:
        ret

# Register map:
#   s0  = screen column x (integer)
#   s1  = side_dist_y (Q16.16)
#   s2  = camera_x (Q16.16)
#   s3  = ray_dir_x (Q16.16)
#   s4  = ray_dir_y (Q16.16)
#   s5  = map_x (integer)
#   s6  = map_y (integer)
#   s7  = delta_dist_x (Q16.16)
#   s8  = delta_dist_y (Q16.16)
#   s9  = step_x (integer, -1 or +1)
#   s10 = step_y (integer, -1 or +1)
#   s11 = side_dist_x (Q16.16)
#   t0-t6/a0-a1 = short-lived scratch and call arguments.
render_frame:
        addi sp, sp, -64
        .equ RENDER_FRAME_RA, 60
        .equ RENDER_FRAME_S0, 56
        .equ RENDER_FRAME_S1, 52
        .equ RENDER_FRAME_S2, 48
        .equ RENDER_FRAME_S3, 44
        .equ RENDER_FRAME_S4, 40
        .equ RENDER_FRAME_S5, 36
        .equ RENDER_FRAME_S6, 32
        .equ RENDER_FRAME_S7, 28
        .equ RENDER_FRAME_S8, 24
        .equ RENDER_FRAME_S9, 20
        .equ RENDER_FRAME_S10, 16
        .equ RENDER_FRAME_S11, 12
        sw ra, RENDER_FRAME_RA(sp)
        sw s0, RENDER_FRAME_S0(sp)
        sw s1, RENDER_FRAME_S1(sp)
        sw s2, RENDER_FRAME_S2(sp)
        sw s3, RENDER_FRAME_S3(sp)
        sw s4, RENDER_FRAME_S4(sp)
        sw s5, RENDER_FRAME_S5(sp)
        sw s6, RENDER_FRAME_S6(sp)
        sw s7, RENDER_FRAME_S7(sp)
        sw s8, RENDER_FRAME_S8(sp)
        sw s9, RENDER_FRAME_S9(sp)
        sw s10, RENDER_FRAME_S10(sp)
        sw s11, RENDER_FRAME_S11(sp)

        li s0, 0

.Lrender_column_loop:
        # camera_x = 2 * x / (SCREEN_WIDTH - 1) - 1.0
        slli s2, s0, 1
        slli s2, s2, FP_SHIFT
        li t0, SCREEN_WIDTH - 1
        div s2, s2, t0
        li t0, -FP_ONE
        add s2, s2, t0

        LOAD_WORD t0, plane_x
        FP_MUL_Q16 t1, t0, s2, t2
        LOAD_WORD s3, player_dir_x
        add s3, s3, t1

        LOAD_WORD t0, plane_y
        FP_MUL_Q16 t1, t0, s2, t2
        LOAD_WORD s4, player_dir_y
        add s4, s4, t1

        LOAD_WORD t0, player_pos_x
        FP_TO_INT s5, t0

        LOAD_WORD t0, player_pos_y
        FP_TO_INT s6, t0

        bnez s3, .Lray_dir_x_nonzero
        li s3, FP_EPSILON
.Lray_dir_x_nonzero:
        li a0, FP_ONE
        mv a1, s3
        call fp_div
        FP_ABS a0
        mv s7, a0

        bnez s4, .Lray_dir_y_nonzero
        li s4, FP_EPSILON
.Lray_dir_y_nonzero:
        li a0, FP_ONE
        mv a1, s4
        call fp_div
        FP_ABS a0
        mv s8, a0

        LOAD_WORD t0, player_pos_x
        bgez s3, .Lray_dir_x_positive

        li s9, -1
        slli t1, s5, FP_SHIFT
        sub t0, t0, t1
        j .Lhave_side_dist_x_base

.Lray_dir_x_positive:
        li s9, 1
        addi t1, s5, 1
        slli t1, t1, FP_SHIFT
        sub t0, t1, t0

.Lhave_side_dist_x_base:
        FP_MUL_Q16 s11, t0, s7, t1

        LOAD_WORD t0, player_pos_y
        bgez s4, .Lray_dir_y_positive

        li s10, -1
        slli t1, s6, FP_SHIFT
        sub t0, t0, t1
        j .Lhave_side_dist_y_base

.Lray_dir_y_positive:
        li s10, 1
        addi t1, s6, 1
        slli t1, t1, FP_SHIFT
        sub t0, t1, t0

.Lhave_side_dist_y_base:
        FP_MUL_Q16 s1, t0, s8, t1

        # DDA and wall projection will consume the s-register state above.

        addi s0, s0, 1
        li t0, SCREEN_WIDTH
        blt s0, t0, .Lrender_column_loop

        lw s11, RENDER_FRAME_S11(sp)
        lw s10, RENDER_FRAME_S10(sp)
        lw s9, RENDER_FRAME_S9(sp)
        lw s8, RENDER_FRAME_S8(sp)
        lw s7, RENDER_FRAME_S7(sp)
        lw s6, RENDER_FRAME_S6(sp)
        lw s5, RENDER_FRAME_S5(sp)
        lw s4, RENDER_FRAME_S4(sp)
        lw s3, RENDER_FRAME_S3(sp)
        lw s2, RENDER_FRAME_S2(sp)
        lw s1, RENDER_FRAME_S1(sp)
        lw s0, RENDER_FRAME_S0(sp)
        lw ra, RENDER_FRAME_RA(sp)
        addi sp, sp, 64
        ret

# ***************************************************
# Start a new frame timer
set_frame_start:
        addi sp, sp, -16
        .equ SET_FRAME_START_RA, 12
        sw ra, SET_FRAME_START_RA(sp)

        call timer0_read_us

        SAVE_WORD a0 frame_start_us t0

        lw ra, SET_FRAME_START_RA(sp)
        addi sp, sp, 16
        ret

# ***************************************************
# Wait till the frametime deadline is reached
wait_frame_time:
        addi sp, sp, -16
        sw ra, 12(sp)
        sw s0, 8(sp)
        sw s1, 4(sp)

        LOAD_WORD s0, frame_start_us       # Frame's start time
        li s1, FRAME_TIME_US               # Frame's allowed us

        # check if already expired and log that
        call timer0_read_us
        sub t0, a0, s0                     # us already spent
        ble t0, s1, .Lwait_next

        LOG_STRING framerate_delay_msg

.Lwait_next:
        call timer0_read_us
        sub t0, a0, s0                     # us already spent
        bltu t0, s1, .Lwait_next
        j .Lfini

.Lfini:
        lw ra, 12(sp)
        lw s0, 8(sp)
        lw s1, 4(sp)
        addi sp, sp, 16
        ret



# ***************************************************
.section .bss
.align 2
frame_start_us: .space 4

# ***************************************************
.section .data
.align 2
player_pos_x: .word 22 * FP_ONE
player_pos_y: .word 12 * FP_ONE
player_dir_x: .word -FP_ONE
player_dir_y: .word 0
plane_x:      .word 0
plane_y:      .word (66 * FP_ONE + 50) / 100

# ***************************************************
.section .rodata
.align 2
enter_gameloop_msg:
        .asciz "INFO: Enter gameloop"

framerate_delay_msg:
        .asciz "WARN: Framerate delay"

level1:
        .byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,1
        .byte 1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.if (. - level1) != MAP_WIDTH * MAP_HEIGHT
        .error "Incorrectly sized level map"
.endif
