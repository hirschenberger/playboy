#include "macros.h"
#include "math.h"

.section .text
.align 2
.global gameloop
.extern fp_div

.equ TARGET_FPS, 60
.equ FRAME_TIME_US, 1000 * 1000 / TARGET_FPS

.equ MAP_WIDTH, 32
.equ MAP_HEIGHT, 32
.equ SCREEN_WIDTH, 320
.equ SCREEN_HEIGHT, 240
.equ FLOOR_COLOR, 0xd618
.equ ROOF_COLOR, 0x5a08

# ***************************************************
# This starts the main gameloop performing the following steps
#   * handle input
#   * update game state
#   * render the frame
#   * wait till the frame's deadline is reached for constane fps
gameloop:
        LOG_STRING enter_gameloop_msg
        li a0, 0xff00
        call lcd_clear

.Lnext_frame:
        call set_frame_start
        call read_input
        call game_update
        call render_frame
        call wait_frame_time

        j .Lnext_frame



# ***************************************************
read_input:
        ret

# ***************************************************
game_update:
        addi sp, sp, -16
        sw ra, 12(sp)

        LOAD_WORD a0 rot_speed
        LOAD_WORD a1 player_dir_x
        LOAD_WORD a2 player_dir_y
        call rotate_vec              # a0=x', a1=y'
        SAVE_WORD a0 player_dir_x t0
        SAVE_WORD a1 player_dir_y t0

        LOAD_WORD a0 rot_speed
        LOAD_WORD a1 plane_x
        LOAD_WORD a2 plane_y
        call rotate_vec              # a0=x', a1=y'
        SAVE_WORD a0 plane_x t0
        SAVE_WORD a1 plane_y t0

        lw ra, 12(sp)
        addi sp, sp, 16
        ret

# Register map:
#   s0  = screen column x (integer)
#   s1  = side_dist_y (Q16.16)
#   s2  = camera_x (Q16.16), then rendered column pixel count
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
        sw ra, 60(sp)
        sw s0, 56(sp)
        sw s1, 52(sp)
        sw s2, 48(sp)
        sw s3, 44(sp)
        sw s4, 40(sp)
        sw s5, 36(sp)
        sw s6, 32(sp)
        sw s7, 28(sp)
        sw s8, 24(sp)
        sw s9, 20(sp)
        sw s10,16(sp)
        sw s11, 12(sp)

        li s0, 0

        # draw roof and floor
        li a0, 0
        li a1, 0
        li a2, SCREEN_WIDTH
        li a3, SCREEN_HEIGHT / 2
        li a4, ROOF_COLOR
        call fill_rect

        li a0, 0
        li a1, SCREEN_HEIGHT / 2
        li a2, SCREEN_WIDTH
        li a3, SCREEN_HEIGHT / 2
        li a4, FLOOR_COLOR
        call fill_rect

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

        mv a0, s3
        FP_ABS a0
        li t0, 2
        bgeu t0, a0, .Lray_dir_x_near_zero

        li a0, FP_ONE
        mv a1, s3
        call fp_div
        FP_ABS a0
        mv s7, a0
        j .Lhave_delta_dist_x

.Lray_dir_x_near_zero:
        li s7, 0x7fffffff
.Lhave_delta_dist_x:

        mv a0, s4
        FP_ABS a0
        li t0, 2
        bgeu t0, a0, .Lray_dir_y_near_zero

        li a0, FP_ONE
        mv a1, s4
        call fp_div
        FP_ABS a0
        mv s8, a0
        j .Lhave_delta_dist_y

.Lray_dir_y_near_zero:
        li s8, 0x7fffffff
.Lhave_delta_dist_y:

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

        # a0: hit side
.Ldda_loop:
        bge s11, s1, .Lstep_y

        add s11, s11, s7
        add s5, s5, s9
        li a0, 0
        j .Lcheck_wall

.Lstep_y:
        add s1, s1, s8
        add s6, s6, s10
        li a0, 1

.Lcheck_wall:
        # check ray wall hit
        li t0, MAP_WIDTH
        bgeu s5, t0, .Lwall_hit
        li t1, MAP_HEIGHT
        bgeu s6, t1, .Lwall_hit

        mul t0, s6, t0              # y * width
        add t0, t0, s5              # + x

        la t1, level1
        add t1, t1, t0              # advance to calculated map pos
        lb t0, 0(t1)                # map entry
        beqz t0, .Ldda_loop

.Lwall_hit:
        # ****************************************
        # distance projected on camera direction
        li t0, FP_ZERO             # perpWallDist
        beqz a0, .Lwall_x

        sub t0, s1, s8
        j .Lhave_wall_distance
.Lwall_x:
        sub t0, s11, s7
.Lhave_wall_distance:

        mv s3, a0                   # store wall hit side

        # ****************************************
        #  height of line
        li t1, 512                  # 1/128 in Q16.16
        ble t0, t1, .Lfull_height_column

        li a0, SCREEN_HEIGHT
        slli a0, a0, FP_SHIFT
        mv a1, t0
        call fp_div
        FP_TO_INT t3, a0             # projected line height

        li t2, SCREEN_HEIGHT / 2
        srli t3, t3, 1               # projected half-height
        sub t4, t2, t3
        max t4, t4, zero             # line start >= 0

        add t5, t2, t3
        addi t6, zero, SCREEN_HEIGHT - 1
        min t5, t5, t6               # line end < screen height

        sub s2, t5, t4
        addi s2, s2, 1               # inclusive window pixel count
        j .Ldraw_wall_column

.Lfull_height_column:
        li t4, 0
        li t5, SCREEN_HEIGHT - 1
        li s2, SCREEN_HEIGHT

        # ****************************************
        # Draw column line
.Ldraw_wall_column:
        mv a0, s0                   # x0
        mv a1, s0                   # x1: one display column
        mv a2, t4                   # y0
        mv a3, t5                   # y1
        call set_window

        # different shade depending on side
        li a0, 0xe004
        # different shade depending on side
        srl a0, a0, s3
        mv a1, s2
        call write_color

        # next x pos
        addi s0, s0, 1
        li t0, SCREEN_WIDTH
        blt s0, t0, .Lrender_column_loop

        lw ra, 60(sp)
        lw s0, 56(sp)
        lw s1, 52(sp)
        lw s2, 48(sp)
        lw s3, 44(sp)
        lw s4, 40(sp)
        lw s5, 36(sp)
        lw s6, 32(sp)
        lw s7, 28(sp)
        lw s8, 24(sp)
        lw s9, 20(sp)
        lw s10,16(sp)
        lw s11, 12(sp)
        addi sp, sp, 64
        ret

# ***************************************************
# Start a new frame timer
set_frame_start:
        addi sp, sp, -16
        sw ra, 12(sp)

        call timer0_read_us

        SAVE_WORD a0 frame_start_us t0

        lw ra, 12(sp)
        addi sp, sp, 16
        ret

# ***************************************************
# Wait till the frametime deadline is reached
wait_frame_time:
        addi sp, sp, -16
        sw ra, 12(sp)
        sw s0, 8(sp)
        sw s1, 4(sp)
        sw s3, 0(sp)

        LOAD_WORD s0, frame_start_us       # Frame's start time
        li s1, FRAME_TIME_US               # Frame's allowed us

        # check if already expired and log that
        call timer0_read_us
        sub s2, a0, s0                     # us already spent
        ble s2, s1, .Lwait_next

        # LOG_STRING framerate_delay_msg
        # mv a0, s2
        # call itoa
        # LOG_STRING_PTR a0

.Lwait_next:
        call timer0_read_us
        sub t0, a0, s0                     # us already spent
        bltu t0, s1, .Lwait_next
        j .Lfini

.Lfini:
        lw ra, 12(sp)
        lw s0, 8(sp)
        lw s1, 4(sp)
        lw s2, 0(sp)
        addi sp, sp, 16
        ret


# ***************************************************




# ***************************************************
.section .bss
.align 2
frame_start_us: .space 4

# ***************************************************
.section .data
.align 2
player_pos_x: .word 22 * FP_ONE
player_pos_y: .word 6 * FP_ONE
player_dir_x: .word -FP_ONE
player_dir_y: .word 0
plane_x:      .word 0
plane_y:      .word (66 * FP_ONE + 50) / 100
rot_speed:    .word 50 * FP_ONE / 10000
move_speed:   .word (50 * FP_ONE + 50) / 100

# ***************************************************
.section .rodata
.align 2
enter_gameloop_msg:
        .asciz "INFO: Enter gameloop"

framerate_delay_msg:
        .asciz "WARN: Framerate delay by micosecs:"

level1:
        .byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1
        .byte 1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,1
        .byte 1,0,0,0,1,0,0,0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0,0,1,1,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.if (. - level1) != MAP_WIDTH * MAP_HEIGHT
        .error "Incorrectly sized level map"
.endif
