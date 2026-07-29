main:
    ; performance / MMIO base = 0x00080000
    lui  x31, 0x80

    ; framebuffer end = 0x00038400
    lui  x10, 0x38
    addi x10, x10, 1024

    ; fill background black
    addi x5, x0, 0
    addi x6, x0, 0

fill_black:
    sw   x6, 0(x5)
    addi x5, x5, 4
    bltu x5, x10, fill_black

    ; sprite0 state
    ; Portrait mode assumes the monitor is rotated 90 degrees clockwise.
    ; x5  = sprite0_y (physical left/right position)
    ; x13 = Y limit = 180 - sprite height 16
    addi x5, x0, 82
    addi x13, x0, 164

    ; initialize sprite0 MMIO registers
    ; 0x00080020 : x
    ; 0x00080024 : y
    ; 0x00080028 : enable
    ; 0x0008002C : color
    ; Logical X=295 places the ship near the physical screen bottom.
    addi x6, x0, 295
    sw   x6, 32(x31)
    sw   x5, 36(x31)

    addi x6, x0, 1
    sw   x6, 40(x31)

    ; green = 0x0000FF00
    lui  x6, 0x10
    addi x6, x6, -256
    sw   x6, 44(x31)

    ; sprite1 (bullet) state
    ; x20 = active, x21 = X, x22 = Y, x23 = auto-fire cooldown
    addi x20, x0, 0
    addi x21, x0, 0
    addi x22, x0, 0
    addi x23, x0, 0

    ; initialize sprite1 MMIO registers
    ; 0x00080030 : x
    ; 0x00080034 : y
    ; 0x00080038 : enable
    sw   x21, 48(x31)
    sw   x22, 52(x31)
    sw   x20, 56(x31)

    ; enemy grid state
    ; x9  = enemy_base_x
    ; x10 = enemy_base_y
    ; x11 = enemy direction (1 = +Y, 0 = -Y)
    ; x24 = enemy_alive_lo, enemies 0..31
    ; x25 = enemy_alive_hi, enemies 32..54 in bits 0..22
    ; x26 = enemy move wait counter
    ; x27 = score ones digit
    ; x28 = score tens digit
    ; x29 = game_state: 0=playing, 1=gameover
    addi x9,  x0, 20
    addi x10, x0, 18 ; centered: (180 - 11*13) / 2
    addi x11, x0, 1
    addi x24, x0, -1
    lui  x25, 0x800
    addi x25, x25, -1
    addi x26, x0, 4
    addi x27, x0, 0
    addi x28, x0, 0
    addi x29, x0, 0

    ; enemy bullet (attack) state
    ; x7  = enemy_bullet_active
    ; x12 = enemy_bullet_x
    ; x30 = enemy_bullet_y
    ; x1  = enemy_bullet_cooldown
    ; x2  = shoot_col: which column (0..10) fires next, rotates every attempt
    ; x3  = shoot_col's Y offset, kept as x2*13 (no multiply instruction)
    addi x7,  x0, 0
    addi x12, x0, 0
    addi x30, x0, 0
    addi x1,  x0, 60
    addi x2,  x0, 0
    addi x3,  x0, 0

    ; initialize enemy MMIO registers
    ; 0x00080040 : enemy_base_x
    ; 0x00080044 : enemy_base_y
    ; 0x00080048 : enemy_alive_lo
    ; 0x0008004C : enemy_alive_hi
    ; 0x00080050 : enemy_enable
    sw   x9,  64(x31)
    sw   x10, 68(x31)
    sw   x24, 72(x31)
    sw   x25, 76(x31)
    addi x6, x0, 1
    sw   x6, 80(x31)

    ; initialize score MMIO register
    ; 0x00080054 : score_bcd = {tens, ones}
    sw   x0, 84(x31)

    ; initialize enemy_bullet MMIO registers
    ; 0x00080058 : enemy_bullet_x
    ; 0x0008005C : enemy_bullet_y
    ; 0x00080060 : enemy_bullet_enable
    sw   x12, 88(x31)
    sw   x30, 92(x31)
    sw   x7,  96(x31)

game_loop:
    ; measure start
    sw   x0, 0(x31)

    ; read KEY register
    ; 0x00080010
    ; bit0 = KEY0 pressed
    ; bit1 = KEY1 pressed
    lw   x14, 16(x31)

    ; KEY0 moves toward physical screen left (logical Y increases).
    addi x15, x0, 1
    beq  x14, x15, try_screen_left

    ; KEY1 moves toward physical screen right (logical Y decreases).
    addi x15, x0, 2
    beq  x14, x15, try_screen_right

    j update_bullet

try_screen_left:
    bltu x5, x13, move_screen_left
    j update_bullet

move_screen_left:
    addi x5, x5, 1
    j update_bullet

try_screen_right:
    beq  x5, x0, update_bullet
    addi x5, x5, -1

update_bullet:
    ; An active bullet moves toward logical -X.
    bne  x20, x0, move_bullet

    ; Once a bullet disappears, wait about 0.2 seconds before firing
    ; the next one automatically.
    beq  x23, x0, spawn_bullet
    addi x23, x23, -1
    j check_collision

spawn_bullet:
    ; Spawn 8 pixels in front of the ship and centered on its Y axis.
    addi x21, x0, 287
    addi x22, x5, 7
    addi x20, x0, 1
    j check_collision

move_bullet:
    ; Move toward logical -X. Test before subtracting to avoid unsigned
    ; coordinate underflow when fewer than 3 pixels remain.
    addi x15, x0, 4
    bltu x21, x15, deactivate_bullet
    addi x21, x21, -3
    j check_collision

deactivate_bullet:
    addi x21, x0, 0
    addi x20, x0, 0
    addi x23, x0, 20
    j update_enemy

check_collision:
    ; Collision is software-side game logic.
    ; Use the bullet head point against the 5x11 enemy grid.
    beq  x20, x0, update_enemy

    ; local_x = bullet_x - enemy_base_x, valid when 0 <= local_x < 65 (5 rows x 13px cell).
    bltu x21, x9, update_enemy
    sub  x15, x21, x9
    addi x16, x0, 65
    bgeu x15, x16, update_enemy

    ; local_y = bullet_y - enemy_base_y, valid when 0 <= local_y < 143 (11 cols x 13px cell).
    bltu x22, x10, update_enemy
    sub  x16, x22, x10
    addi x17, x0, 143
    bgeu x16, x17, update_enemy

    ; No divide instruction: row = local_x / 13 by repeated subtraction.
    ; x15 ends up holding the remainder (cell_x position within the cell).
    addi x18, x0, 0
row_div_loop:
    addi x19, x0, 13
    bltu x15, x19, row_div_done
    sub  x15, x15, x19
    addi x18, x18, 1
    j    row_div_loop
row_div_done:

    ; Collision keeps the first 12x12 area of each 13x13 cell. The visual
    ; sprite is smaller, but this stable hit box avoids changing game logic.
    addi x19, x0, 12
    bgeu x15, x19, update_enemy

    ; col = local_y / 13; x16 ends up holding the remainder (cell_y).
    addi x17, x0, 0
col_div_loop:
    addi x19, x0, 13
    bltu x16, x19, col_div_done
    sub  x16, x16, x19
    addi x17, x17, 1
    j    col_div_loop
col_div_done:
    addi x19, x0, 12
    bgeu x16, x19, update_enemy

    ; enemy_idx = row * 11 + col = row * 8 + row * 2 + row + col.
    ; row is in x18, col is in x17.
    slli x15, x18, 3
    slli x16, x18, 1
    add  x15, x15, x16
    add  x15, x15, x18
    add  x17, x15, x17

    ; Split 55 alive bits into lo(0..31) and hi(32..54).
    addi x18, x0, 32
    bltu x17, x18, hit_enemy_lo

hit_enemy_hi:
    addi x17, x17, -32
    addi x18, x0, 1
    sll  x18, x18, x17
    and  x19, x25, x18
    beq  x19, x0, update_enemy
    xori x18, x18, -1
    and  x25, x25, x18
    j bullet_hit

hit_enemy_lo:
    addi x18, x0, 1
    sll  x18, x18, x17
    and  x19, x24, x18
    beq  x19, x0, update_enemy
    xori x18, x18, -1
    and  x24, x24, x18

bullet_hit:
    ; Hit: enemy bit cleared, score incremented.
    addi x27, x27, 1
    addi x18, x0, 10
    bltu x27, x18, score_inc_done
    addi x27, x0, 0
    addi x28, x28, 1

score_inc_done:
    addi x21, x0, 0
    addi x20, x0, 0
    addi x23, x0, 20
    ; --- clear check: all 55 enemies defeated? ---
    bne  x24, x0, update_enemy
    bne  x25, x0, update_enemy
    j start_new_wave

update_enemy:
    ; Move enemies once every several game loops.
    bne  x26, x0, enemy_wait

    ; --- dynamic move interval: 9 - 2*tens_digit, clamped to 3 ---
    ; This gives about half the former movement speed while preserving the
    ; gradual speed-up as the score rises.
    ; fewer enemies alive => higher tens digit => shorter interval => faster movement
    addi x26, x0, 9
    sub  x26, x26, x28
    sub  x26, x26, x28
    addi x15, x0, 3
    bge  x26, x15, enemy_prepare_columns
    addi x26, x0, 3

enemy_prepare_columns:
    ; Build an 11-bit column occupancy mask by ORing the five enemy rows.
    ; Bit N is 1 when at least one enemy in column N is still alive.
    addi x19, x0, 2047
    and  x15, x24, x19
    srli x16, x24, 11
    and  x16, x16, x19
    or   x15, x15, x16
    srli x16, x24, 22
    andi x17, x25, 1
    slli x17, x17, 10
    or   x16, x16, x17
    and  x16, x16, x19
    or   x15, x15, x16
    srli x16, x25, 1
    and  x16, x16, x19
    or   x15, x15, x16
    srli x16, x25, 12
    and  x16, x16, x19
    or   x15, x15, x16

    ; The video grid base is unsigned, so it cannot move below zero.
    ; When the leftmost column is empty, shift every row's alive bits one
    ; column toward zero and add 13 to the base. This keeps all visible enemy
    ; positions unchanged while making the next living column the new col 0.
    andi x16, x15, 1
    bne  x16, x0, enemy_dir_check

enemy_normalize_left:
    ; new row 0: old columns 1..10 -> new columns 0..9
    and  x15, x24, x19
    srli x15, x15, 1

    ; new row 1
    srli x17, x24, 11
    and  x17, x17, x19
    srli x17, x17, 1
    slli x17, x17, 11
    or   x15, x15, x17

    ; new row 2 crosses enemy_alive_lo / enemy_alive_hi.
    srli x17, x24, 22
    andi x18, x25, 1
    slli x18, x18, 10
    or   x17, x17, x18
    and  x17, x17, x19
    srli x17, x17, 1
    slli x17, x17, 22
    or   x15, x15, x17

    ; new rows 3 and 4 remain in enemy_alive_hi.
    addi x16, x0, 0
    srli x17, x25, 1
    and  x17, x17, x19
    srli x17, x17, 1
    slli x17, x17, 1
    or   x16, x16, x17
    srli x17, x25, 12
    and  x17, x17, x19
    srli x17, x17, 1
    slli x17, x17, 12
    or   x16, x16, x17

    add  x24, x15, x0
    add  x25, x16, x0
    addi x10, x10, 13
    j enemy_prepare_columns

enemy_dir_check:
    bne  x11, x0, enemy_move_pos

enemy_move_neg:
    beq  x10, x0, enemy_hit_left
    addi x10, x10, -1
    j check_gameover

enemy_hit_left:
    addi x11, x0, 1
    addi x9, x9, 13
    j check_gameover

enemy_move_pos:
    ; Find the highest occupied column in the mask prepared above.
    addi x16, x0, 10
enemy_find_right_col:
    addi x17, x0, 1
    sll  x17, x17, x16
    and  x18, x15, x17
    bne  x18, x0, enemy_right_col_found
    addi x16, x16, -1
    j enemy_find_right_col

enemy_right_col_found:
    ; right bound = 180 - ((rightmost_col + 1) * 13)
    addi x17, x16, 1
    slli x18, x17, 3
    slli x19, x17, 2
    add  x18, x18, x19
    add  x18, x18, x17
    addi x19, x0, 180
    sub  x15, x19, x18
    bltu x10, x15, enemy_step_pos
    addi x11, x0, 0
    addi x9, x9, 13
    j check_gameover

enemy_step_pos:
    addi x10, x10, 1
    j check_gameover

enemy_wait:
    addi x26, x26, -1

check_gameover:
    ; game over when enemy front (x9 + 65, 5 rows x 13px) reaches the player column (x=295)
    addi x15, x9, 65
    addi x16, x0, 295
    bltu x15, x16, update_enemy_bullet
    addi x29, x0, 1
    j game_over_screen

update_enemy_bullet:
    bne  x7, x0, move_enemy_bullet

    ; Not active: wait, then try to spawn from the front-row (row 4) enemy
    ; currently assigned to shoot_col.
    beq  x1, x0, try_spawn_enemy_bullet
    addi x1, x1, -1
    j update_sprite_mmio

try_spawn_enemy_bullet:
    ; Front-row enemy_idx = 44 + shoot_col, always >= 32 (hi word).
    ; bit position = idx - 32 = 12 + shoot_col.
    addi x4, x0, 12
    add  x4, x4, x2
    addi x6, x0, 1
    sll  x6, x6, x4
    and  x6, x25, x6
    beq  x6, x0, advance_shoot_col

    ; Alive: spawn at the bottom edge of that enemy's cell, moving toward the player.
    addi x12, x9, 64
    add  x30, x10, x3
    addi x30, x30, 5
    addi x7, x0, 1

advance_shoot_col:
    addi x2, x2, 1
    addi x3, x3, 13
    addi x4, x0, 11
    bltu x2, x4, enemy_bullet_cooldown_reset
    addi x2, x0, 0
    addi x3, x0, 0

enemy_bullet_cooldown_reset:
    addi x1, x0, 30
    j update_sprite_mmio

move_enemy_bullet:
    addi x12, x12, 3
    addi x4, x0, 295
    bltu x12, x4, update_sprite_mmio

    ; Reached the player's row: check Y overlap against sprite0 (x5, height 16).
    addi x6, x30, 2
    bltu x6, x5, enemy_bullet_miss
    addi x6, x5, 16
    bgeu x30, x6, enemy_bullet_miss

    ; Hit: game over.
    addi x29, x0, 1
    addi x7, x0, 0
    j game_over_screen

enemy_bullet_miss:
    addi x7, x0, 0

update_sprite_mmio:
    ; CPU updates only the sprite Y register for the player.
    sw   x5, 36(x31)

    ; Publish the complete bullet state every game-loop iteration.
    sw   x21, 48(x31)
    sw   x22, 52(x31)
    sw   x20, 56(x31)

    ; Publish enemy grid state.
    sw   x9,  64(x31)
    sw   x10, 68(x31)
    sw   x24, 72(x31)
    sw   x25, 76(x31)
    addi x6, x0, 1
    sw   x6, 80(x31)

    ; Publish enemy bullet state.
    sw   x12, 88(x31)
    sw   x30, 92(x31)
    sw   x7,  96(x31)

    ; Publish score in packed BCD: [7:4]=tens, [3:0]=ones.
    slli x6, x28, 4
    or   x6, x6, x27
    sw   x6, 84(x31)

    ; measure stop
    sw   x0, 4(x31)

    ; wait
    lui  x8, 0x40

wait_loop:
    addi x8, x8, -1
    bne  x8, x0, wait_loop

    j game_loop

; ── game over ──────────────────────────────────────────────────────────────
; Disable bullet and enemy display. Player sprite remains visible.
; Loop forever until hardware reset.

game_over_screen:
    addi x6, x0, 0
    sw   x6, 56(x31)    ; bullet_enable = 0
    sw   x6, 80(x31)    ; enemy_enable  = 0
    sw   x6, 96(x31)    ; enemy_bullet_enable = 0

game_over_loop:
    j game_over_loop

; ── wave clear: reset enemy grid and keep score-based speed ───────────────
; Score is kept. The same half-speed curve is used after a wave restart.

start_new_wave:
    addi x9,  x0, 20
    addi x10, x0, 18 ; centered: (180 - 11*13) / 2
    addi x11, x0, 1
    addi x24, x0, -1
    lui  x25, 0x800
    addi x25, x25, -1
    ; initial interval = 9 - 2*tens_digit, clamped to 3
    addi x26, x0, 9
    sub  x26, x26, x28
    sub  x26, x26, x28
    addi x15, x0, 3
    bge  x26, x15, new_wave_speed_ok
    addi x26, x0, 3

new_wave_speed_ok:
    ; reset bullet
    addi x20, x0, 0
    addi x21, x0, 0
    addi x22, x0, 0
    addi x23, x0, 0
    ; reset enemy bullet / attack rotation
    addi x7,  x0, 0
    addi x12, x0, 0
    addi x30, x0, 0
    addi x1,  x0, 60
    addi x2,  x0, 0
    addi x3,  x0, 0
    j update_sprite_mmio
