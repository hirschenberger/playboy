.include "macros.h"
.include "math.h"
.include "lcd.h"
.include "joypad.h"
.include "assets/assets.h"

.global gameloop

.equ TARGET_FPS, 60
.equ FRAME_TIME_US, 1000 * 1000 / TARGET_FPS
.equ MAP_WIDTH, 32
.equ MAP_HEIGHT, 32
.equ WALL_TEXTURE_WIDTH, ASSET_REDBRICK_WIDTH
.equ WALL_TEXTURE_HEIGHT, ASSET_REDBRICK_HEIGHT
.equ RENDER_HIT_RAY_DIR_X, 0
.equ RENDER_HIT_RAY_DIR_Y, 4
.equ RENDER_HIT_SIDE, 8
.equ RENDER_HIT_DISTANCE, 12
.equ RENDER_HIT_TEXTURE, 16
.equ RENDER_HIT_SIZE, 20

.if ASSET_MOSSY_WIDTH != WALL_TEXTURE_WIDTH || ASSET_MOSSY_HEIGHT != WALL_TEXTURE_HEIGHT
        .error "Wall textures must have identical dimensions"
.endif

# ------------------------------------------------------------------------------
.section .text

# ------------------------------------------------------------------------------
# Run the main game loop: handle input, update game state, render the
# frame, then wait until the frame deadline for a constant frame rate.
gameloop:
        LOG_STRING enter_gameloop_msg
        li a0, 0x0000
        call lcd_clear
        call init_joypad

.Lnext_frame:
        call set_frame_start
        call read_input
        call game_update
        call render_frame
        call wait_frame_time
        j .Lnext_frame

# ------------------------------------------------------------------------------
# Read and process player input for the current frame.
read_input:
        addi sp, sp, -16
        sw ra, 12(sp)

        call read_joypad
        beqz a1, .Ldone


        # check which button is pressed
        andi t0, a0, JOYPAD_LEFT
        bnez t0, .Lrotate_left
        andi t0, a0, JOYPAD_TOP
        bnez t0, .Lmove_forward
        andi t0, a0, JOYPAD_RIGHT
        bnez t0, .Lrotate_right
        andi t0, a0, JOYPAD_BOTTOM
        bnez t0, .Lmove_backward

        # no button pressed, reset movement
        STORE_WORD zero, player_rot, t0
        STORE_WORD zero, player_move, t0
        j .Ldone


.Lrotate_left:
        li a1, -1
        STORE_WORD a1, player_rot, t0
        j .Ldone
.Lmove_forward:
        li a1, FP_ONE
        STORE_WORD a1, player_move, t0
        j .Ldone
.Lrotate_right:
        li a1, 1
        STORE_WORD a1, player_rot, t0
        j .Ldone
.Lmove_backward:
        li a1, -FP_ONE
        STORE_WORD a1, player_move, t0
        j .Ldone


.Ldone:
        lw ra, 12(sp)
        addi sp, sp, 16
        ret

# ------------------------------------------------------------------------------
# Advance the game state by one frame.
game_update:
        addi sp, sp, -16
        sw ra, 12(sp)
        sw s0, 8(sp)
        sw s1, 4(sp)

        # move player
        LOAD_WORD t0 player_dir_x
        LOAD_WORD t1 player_dir_y
        LOAD_WORD t2 player_pos_x
        LOAD_WORD t3 player_pos_y
        LOAD_WORD t4 player_move
        LOAD_WORD t6 move_speed

        FP_MUL_FAST t4, t4, t6
        FP_MUL_Q16 t5, t0, t4, t6     # dir x * move
        add t2, t2, t5                 # pos x += dir x
        FP_MUL_Q16 t5, t1, t4, t6     # dir y * move
        add t3, t3, t5                 # pos y += dir y

        STORE_WORD t2 player_pos_x t5
        STORE_WORD t3 player_pos_y t5

        # calculate rotation
        LOAD_WORD s0 rot_speed
        LOAD_WORD a0 player_rot
        mul s0, s0, a0

        # rotate player dir
        mv a0, s0
        mv a1, t0                    # player_dir_x
        mv a2, t1                    # player_dir_y
        call rotate_vec              # a0=x', a1=y'
        STORE_WORD a0 player_dir_x t0
        STORE_WORD a1 player_dir_y t0

        # rotate render plane
        mv a0, s0
        LOAD_WORD a1 plane_x
        LOAD_WORD a2 plane_y
        call rotate_vec              # a0=x', a1=y'
        STORE_WORD a0 plane_x t0
        STORE_WORD a1 plane_y t0

        lw ra, 12(sp)
        lw s0, 8(sp)
        sw s1, 4(sp)
        addi sp, sp, 16
        ret

# ------------------------------------------------------------------------------
# Render the current frame: draw the roof and floor, then render one wall ray
# per screen column.
#
# Register map:
#   * s0: screen column x (integer)
#   * 0(sp)-19(sp): wall-ray hit record
render_frame:
        addi sp, sp, -48
        sw ra, 44(sp)
        sw s0, 40(sp)

        li s0, 0

        la a0, wood_texture
        la a1, greystone_texture
        call draw_ceil_and_floor

.Lrender_column_loop:
        mv a0, s0
        mv a1, sp
        call cast_wall_ray

        mv a0, s0
        mv a1, sp
        call draw_textured_wall_column

        addi s0, s0, 1
        li t0, SCREEN_WIDTH
        blt s0, t0, .Lrender_column_loop

        lw ra, 44(sp)
        lw s0, 40(sp)
        addi sp, sp, 48
        ret

# ------------------------------------------------------------------------------
# Cast one wall ray through the screen column and record its hit.
#
# In:
#   * a0: screen column x (integer)
#   * a1: address of a RENDER_HIT_SIZE-byte hit record
#
# Out:
#   * RENDER_HIT_RAY_DIR_X(a1): ray direction x (Q16.16)
#   * RENDER_HIT_RAY_DIR_Y(a1): ray direction y (Q16.16)
#   * RENDER_HIT_SIDE(a1): hit side (0 for x-side, 1 for y-side)
#   * RENDER_HIT_DISTANCE(a1): perpendicular wall distance (Q16.16)
#   * RENDER_HIT_TEXTURE(a1): wall texture address
#
# Register map:
#   * s0: hit record address
#   * s1: ray_dir_x, then side_dist_x (Q16.16)
#   * s2: ray_dir_y, then side_dist_y (Q16.16)
#   * s3: map_x (integer)
#   * s4: map_y (integer)
#   * s5: delta_dist_x (Q16.16)
#   * s6: delta_dist_y (Q16.16)
#   * s7: step_x (integer, -1 or +1)
#   * s8: step_y (integer, -1 or +1)
#   * t6: level map address
cast_wall_ray:
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
        sw s8, 8(sp)

        mv s0, a1

        # camera_x = 2 * x / (SCREEN_WIDTH - 1) - 1.0
        slli t1, a0, 1
        slli t1, t1, FP_SHIFT
        li t0, SCREEN_WIDTH - 1
        div t1, t1, t0
        li t0, -FP_ONE
        add t1, t1, t0

        LOAD_WORD t0, plane_x
        FP_MUL_Q16 t2, t0, t1, t3
        LOAD_WORD s1, player_dir_x
        add s1, s1, t2

        LOAD_WORD t0, plane_y
        FP_MUL_Q16 t2, t0, t1, t3
        LOAD_WORD s2, player_dir_y
        add s2, s2, t2
        sw s1, RENDER_HIT_RAY_DIR_X(s0)
        sw s2, RENDER_HIT_RAY_DIR_Y(s0)

        LOAD_WORD t0, player_pos_x
        FP_TO_INT s3, t0

        LOAD_WORD t0, player_pos_y
        FP_TO_INT s4, t0

        mv a0, s1
        FP_ABS a0
        li t0, 2
        bgeu t0, a0, .Lcast_ray_dir_x_near_zero

        li a0, FP_ONE
        mv a1, s1
        call fp_div
        FP_ABS a0
        mv s5, a0
        j .Lcast_have_delta_dist_x

.Lcast_ray_dir_x_near_zero:
        li s5, 0x7fffffff
.Lcast_have_delta_dist_x:

        mv a0, s2
        FP_ABS a0
        li t0, 2
        bgeu t0, a0, .Lcast_ray_dir_y_near_zero

        li a0, FP_ONE
        mv a1, s2
        call fp_div
        FP_ABS a0
        mv s6, a0
        j .Lcast_have_delta_dist_y

.Lcast_ray_dir_y_near_zero:
        li s6, 0x7fffffff
.Lcast_have_delta_dist_y:

        LOAD_WORD t0, player_pos_x
        bgez s1, .Lcast_ray_dir_x_positive

        li s7, -1
        slli t1, s3, FP_SHIFT
        sub t0, t0, t1
        j .Lcast_have_side_dist_x_base

.Lcast_ray_dir_x_positive:
        li s7, 1
        addi t1, s3, 1
        slli t1, t1, FP_SHIFT
        sub t0, t1, t0

.Lcast_have_side_dist_x_base:
        FP_MUL_Q16 s1, t0, s5, t1

        LOAD_WORD t0, player_pos_y
        bgez s2, .Lcast_ray_dir_y_positive

        li s8, -1
        slli t1, s4, FP_SHIFT
        sub t0, t0, t1
        j .Lcast_have_side_dist_y_base

.Lcast_ray_dir_y_positive:
        li s8, 1
        addi t1, s4, 1
        slli t1, t1, FP_SHIFT
        sub t0, t1, t0

.Lcast_have_side_dist_y_base:
        FP_MUL_Q16 s2, t0, s6, t1

        la t6, level1
        la t0, redbrick_texture
        sw t0, RENDER_HIT_TEXTURE(s0)

.Lcast_dda_loop:
        bge s1, s2, .Lcast_step_y

        add s1, s1, s5
        add s3, s3, s7
        li a0, 0
        j .Lcast_check_wall

.Lcast_step_y:
        add s2, s2, s6
        add s4, s4, s8
        li a0, 1

.Lcast_check_wall:
        li t0, MAP_WIDTH
        bgeu s3, t0, .Lcast_wall_hit
        li t1, MAP_HEIGHT
        bgeu s4, t1, .Lcast_wall_hit

        mul t0, s4, t0
        add t0, t0, s3

        add t1, t6, t0
        lb t0, 0(t1)
        beqz t0, .Lcast_dda_loop

        la t1, level1_texture_map
        sh2add t1, t0, t1
        lw t1, 0(t1)
        sw t1, RENDER_HIT_TEXTURE(s0)

.Lcast_wall_hit:
        beqz a0, .Lcast_wall_x

        sub t0, s2, s6
        j .Lcast_have_wall_distance

.Lcast_wall_x:
        sub t0, s1, s5

.Lcast_have_wall_distance:
        sw a0, RENDER_HIT_SIDE(s0)
        sw t0, RENDER_HIT_DISTANCE(s0)

        lw ra, 44(sp)
        lw s0, 40(sp)
        lw s1, 36(sp)
        lw s2, 32(sp)
        lw s3, 28(sp)
        lw s4, 24(sp)
        lw s5, 20(sp)
        lw s6, 16(sp)
        lw s7, 12(sp)
        lw s8, 8(sp)
        addi sp, sp, 48
        ret

# ------------------------------------------------------------------------------
# Draw one textured wall column from a recorded ray hit.
#
# In:
#   * a0: screen column x (integer)
#   * a1: address of a populated wall-ray hit record
#
# Register map:
#   * s0: screen column x (integer)
#   * s1: hit record address
#   * a2: clipped draw start y
#   * a3: clipped draw end y
#   * a4: hit side
#   * a5: perpendicular wall distance (Q16.16)
#   * a6: texture x
#   * a7: texture y step (Q16.16)
#   * t0: texture y position (Q16.16)
#   * t1: framebuffer pixel address
#   * t2: texture address
#   * t3: current screen y
#   * t4-t6: scratch
draw_textured_wall_column:
        addi sp, sp, -16
        sw ra, 12(sp)
        sw s0, 8(sp)
        sw s1, 4(sp)

        mv s0, a0
        mv s1, a1
        lw t0, RENDER_HIT_DISTANCE(s1)

        li t1, 512                  # 1/128 in Q16.16
        ble t0, t1, .Ldraw_full_height_column

        li a0, SCREEN_HEIGHT
        slli a0, a0, FP_SHIFT
        mv a1, t0
        call fp_div
        FP_TO_INT t0, a0

        li t1, SCREEN_HEIGHT / 2
        srli t0, t0, 1
        sub a2, t1, t0
        max a2, a2, zero

        add a3, t1, t0
        li t2, SCREEN_HEIGHT - 1
        min a3, a3, t2
        j .Ldraw_have_column_span

.Ldraw_full_height_column:
        li a2, 0
        li a3, SCREEN_HEIGHT - 1

.Ldraw_have_column_span:
        lw a4, RENDER_HIT_SIDE(s1)
        lw a5, RENDER_HIT_DISTANCE(s1)

        bnez a4, .Ldraw_wall_hit_y_side
        lw t0, RENDER_HIT_RAY_DIR_Y(s1)
        FP_MUL_Q16 a6, a5, t0, t1
        LOAD_WORD t1, player_pos_y
        add a6, a6, t1
        j .Ldraw_have_wall_x

.Ldraw_wall_hit_y_side:
        lw t0, RENDER_HIT_RAY_DIR_X(s1)
        FP_MUL_Q16 a6, a5, t0, t1
        LOAD_WORD t1, player_pos_x
        add a6, a6, t1

.Ldraw_have_wall_x:
        li t0, 0xffff
        and a6, a6, t0
        li t0, WALL_TEXTURE_WIDTH
        mul a6, a6, t0
        srli a6, a6, FP_SHIFT

        bnez a4, .Ldraw_check_y_side_flip
        lw t0, RENDER_HIT_RAY_DIR_X(s1)
        blez t0, .Ldraw_have_texture_x
        j .Ldraw_flip_texture_x

.Ldraw_check_y_side_flip:
        lw t0, RENDER_HIT_RAY_DIR_Y(s1)
        bgez t0, .Ldraw_have_texture_x

.Ldraw_flip_texture_x:
        li t0, WALL_TEXTURE_WIDTH - 1
        sub a6, t0, a6

.Ldraw_have_texture_x:
        li t0, WALL_TEXTURE_HEIGHT
        mul t0, a5, t0
        li t1, SCREEN_HEIGHT
        div a7, t0, t1

        li t0, SCREEN_HEIGHT / 2
        sub t0, a2, t0
        mul t0, t0, a7
        li t1, WALL_TEXTURE_HEIGHT / 2
        slli t1, t1, FP_SHIFT
        add t0, t0, t1

        la t1, draw_buffer_ptr
        li t4, SCREEN_WIDTH
        mul t4, a2, t4
        add t4, t4, s0
        sh1add t1, t4, t1

        lw t2, RENDER_HIT_TEXTURE(s1)
        mv t3, a2

.Ldraw_textured_wall_pixel:
        srai t4, t0, FP_SHIFT
        andi t4, t4, WALL_TEXTURE_HEIGHT - 1
        li t5, WALL_TEXTURE_WIDTH
        mul t4, t4, t5
        add t4, t4, a6
        sh1add t4, t4, t2
        lhu t4, 0(t4)
        srl t4, t4, a4
        beqz a4, .Ldraw_store_wall_pixel
        li t5, 0x7bef
        and t4, t4, t5

.Ldraw_store_wall_pixel:
        rev8 t4, t4
        srli t4, t4, 16
        sh t4, 0(t1)

        add t0, t0, a7
        addi t3, t3, 1
        addi t1, t1, SCREEN_WIDTH * 2
        ble t3, a3, .Ldraw_textured_wall_pixel

        lw ra, 12(sp)
        lw s0, 8(sp)
        lw s1, 4(sp)
        addi sp, sp, 16
        ret

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# Draw textured ceiling and floor.
#
# In:
#   * a0: ceiling texture address
#   * a1: floor texture address
#
# Register map:
#   * s0: rayDirX0 (Q16.16)
#   * s1: rayDirY0 (Q16.16)
#   * s2: rayDirX1 (Q16.16)
#   * s3: rayDirY1 (Q16.16)
#   * s4: screen x (integer)
#   * s5: screen y (integer)
#   * s6: floorStepX (Q16.16)
#   * s7: floorStepY (Q16.16)
#   * s8: floorX (Q16.16)
#   * s9: floorY (Q16.16)
#   * s10: rowDistance (Q16.16)
#   * s11: texture base address
#   * 0(sp): player position x (Q16.16)
#   * 4(sp): player position y (Q16.16)
#   * t0: texture width (integer)
#   * t1: texture height (integer)
#   * t2: fractional mask (0xffff)
#   * t3-t6: scratch
draw_ceil_and_floor:
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
    sw s10, 16(sp)
    sw s11, 12(sp)

    LOAD_WORD t3, player_pos_x
    LOAD_WORD t4, player_pos_y
    sw t3, 0(sp)
    sw t4, 4(sp)

    LOAD_WORD t3, player_dir_x
    LOAD_WORD t4, player_dir_y
    LOAD_WORD t5, plane_x
    LOAD_WORD t6, plane_y

    sub s0, t3, t5           # rayDirX0 = dirX - planeX
    sub s1, t4, t6           # rayDirY0 = dirY - planeY
    add s2, t3, t5           # rayDirX1 = dirX + planeX
    add s3, t4, t6           # rayDirY1 = dirY + planeY

    li t0, ASSET_WOOD_WIDTH
    li t1, ASSET_WOOD_HEIGHT
    li t2, 0xffff            # fractional mask

    li s5, SCREEN_HEIGHT - 1 # y counter (top to bottom)

next_y:
    addi t3, s5, -(SCREEN_HEIGHT / 2)   # t3 = y - SCREEN_HEIGHT / 2
    beqz t3, .Lnext_y_continue          # skip horizon row (avoid div by zero)

    li t4, SCREEN_HEIGHT / 2
    FP_FROM_INT t4
    div s10, t4, t3                     # rowDistance = (H/2 << 16) / (y - H/2)

    sub t3, s2, s0
    FP_MUL_Q16 t4, t3, s10, t6          # rowDistance * (rayDirX1 - rayDirX0)
    li t5, SCREEN_WIDTH
    div s6, t4, t5                      # floorStepX = rowDistance * (rayDirX1 - rayDirX0) / W

    sub t3, s3, s1
    FP_MUL_Q16 t4, t3, s10, t6          # rowDistance * (rayDirY1 - rayDirY0)
    div s7, t4, t5                      # floorStepY = rowDistance * (rayDirY1 - rayDirY0) / W

    FP_MUL_Q16 s8, s10, s0, t6
    lw t3, 0(sp)
    add s8, s8, t3                      # floorX = posX + rowDistance * rayDirX0
    FP_MUL_Q16 s9, s10, s1, t6
    lw t3, 4(sp)
    add s9, s9, t3                      # floorY = posY + rowDistance * rayDirY0

    # ceiling (y < H/2) samples a0, floor samples a1
    li s4, 0                            # x counter (left to right)
    li t4, SCREEN_HEIGHT / 2
    blt s5, t4, .Luse_ceil
    mv s11, a1
    j .Lx_loop
.Luse_ceil:
    mv s11, a0
.Lx_loop:
    and t3, s8, t2                      # fracX = floorX & 0xffff
    mul t3, t3, t0                      # fracX * texWidth
    srai t3, t3, 16                     # tx = int(fracX * texWidth)
    andi t3, t3, 63                     # tx &= (texWidth - 1)

    and t4, s9, t2                      # fracY = floorY & 0xffff
    mul t4, t4, t1                      # fracY * texHeight
    srai t4, t4, 16                     # ty = int(fracY * texHeight)
    andi t4, t4, 63                     # ty &= (texHeight - 1)

    add s8, s8, s6                      # floorX += floorStepX
    add s9, s9, s7                      # floorY += floorStepY

    mul t4, t4, t0                      # ty * texWidth
    add t4, t4, t3                      # + tx
    sh1add t4, t4, s11                  # * 2 bytes/px + texture base
    lhu t4, 0(t4)                       # tex pixel color (RGB565, little-endian)
    rev8 t4, t4                         # byte-swap to big-endian (display order)
    srli t4, t4, 16

    la t5, draw_buffer_ptr
    li t6, SCREEN_WIDTH
    mul t6, t6, s5                      # y * SCREEN_WIDTH
    add t6, t6, s4                      # + x
    sh1add t6, t6, t5                   # * 2 bytes/px + texture base
    sh t4, 0(t6)                        # write RGB565 pixel

    addi s4, s4, 1
    li t4, SCREEN_WIDTH
    blt s4, t4, .Lx_loop

.Lnext_y_continue:
    addi s5, s5, -1
    bgez s5, next_y

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
    lw s10, 16(sp)
    lw s11, 12(sp)
    addi sp, sp, 64
    ret


# ------------------------------------------------------------------------------
# Record the start of the current frame's time window.
set_frame_start:
        addi sp, sp, -16
        sw ra, 12(sp)

        call timer0_read_us

        STORE_WORD a0 frame_start_us t0

        lw ra, 12(sp)
        addi sp, sp, 16
        ret

# ------------------------------------------------------------------------------
# Wait until the current frame's time deadline is reached.
wait_frame_time:
        addi sp, sp, -16
        sw ra, 12(sp)
        sw s0, 8(sp)
        sw s1, 4(sp)
        sw s2, 0(sp)

        LOAD_WORD s0, frame_start_us       # Frame's start time
        li s1, FRAME_TIME_US               # Frame's allowed us

        # check if already expired and log that
        call timer0_read_us
        sub s2, a0, s0                     # us already spent
        ble s2, s1, .Lflip_buffer

        # LOG_STRING framerate_delay_msg
        # mv a0, s2
        # call itoa
        # LOG_STRING_PTR a0

.Lflip_buffer:
        call flip_buffer

.Lwait_next:
        call timer0_read_us
        sub t0, a0, s0                     # us already spent
        bltu t0, s1, .Lwait_next

        lw ra, 12(sp)
        lw s0, 8(sp)
        lw s1, 4(sp)
        lw s2, 0(sp)
        addi sp, sp, 16
        ret

# ------------------------------------------------------------------------------
.section .bss
.balign 4

frame_start_us: .space 4

# ------------------------------------------------------------------------------
.section .data
.balign 4
player_pos_x: .word 22 * FP_ONE
player_pos_y: .word 6 * FP_ONE
player_dir_x: .word -FP_ONE
player_dir_y: .word FP_ZERO
player_rot:   .word 0                # attention, it's a 16bit turn angle, no Q16.16
player_move:  .word FP_ZERO
plane_x:      .word FP_ZERO
plane_y:      .word (66 * FP_ONE + 50) / 100
rot_speed:    .word 100 * FP_ONE / 10000
move_speed:   .word (30 * FP_ONE + 50) / 100

# ------------------------------------------------------------------------------
.section .rodata

enter_gameloop_msg:
        .asciz "INFO: Enter gameloop"

framerate_delay_msg:
        .asciz "WARN: Framerate delay by micosecs:"

joypad_press_msg:
        .asciz "Joypad button pressed"

level1:
        .byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,1
        .byte 1,0,0,0,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,0,0,0,0,0,1
        .byte 1,0,0,0,2,0,0,0,0,0,2,2,2,2,2,2,2,2,2,0,0,0,0,0,2,2,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
        .byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
.if (. - level1) != MAP_WIDTH * MAP_HEIGHT
        .error "Incorrectly sized level map"
.endif

.balign 4
level1_texture_map:
        .word 0x0, mossy_texture, redbrick_texture

greystone_texture:
        .incbin "assets/greystone.bin"
wood_texture:
        .incbin "assets/wood.bin"
redbrick_texture:
        .incbin "assets/redbrick.bin"
mossy_texture:
        .incbin "assets/mossy.bin"
