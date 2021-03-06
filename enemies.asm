
include "debug.asm"
include "enemy.asm"
include "hram.asm"
include "longcalc.asm"
include "macros.asm"
include "sprites.asm"
include "tile.asm"


SECTION "Enemy memory", WRAM0

EnemyList::
	ds ENEMY_SIZE * ENEMY_LIST_SIZE


SECTION "Enemy prototypes", ROM0

include "assets/flag_define_slime_green_0.asm"
include "assets/flag_define_slime_blue_0.asm"
include "assets/flag_define_slime_yellow_0.asm"
include "assets/flag_define_bat_0.asm"
include "assets/flag_define_bat_red_0.asm"
include "assets/flag_define_skeleton_0.asm"
include "assets/flag_define_skeleton_yellow_0.asm"
include "assets/flag_define_skeleton_black_0.asm"
include "assets/flag_define_wraith_0.asm"
include "assets/flag_define_direbat_small_0.asm"
include "assets/flag_define_direbat_grey_small_0.asm"

ProtoSlimeGreen::
	EnemyPrototype 1, 1, 50, NopFunc, 1, FLAG_SLIME_GREEN_0, SPRITE_SLIME_GREEN_0, SPRITE_SLIME_GREEN_0
ProtoSlimeBlue::
	EnemyPrototype 2, 2, 1, BehaviourBlueSlime, 1, FLAG_SLIME_BLUE_0, SPRITE_SLIME_BLUE_0, SPRITE_SLIME_BLUE_1
ProtoSlimeYellow::
	EnemyPrototype 1, 1, 1, BehaviourYellowSlime, 1, FLAG_SLIME_YELLOW_0, SPRITE_SLIME_YELLOW_0, SPRITE_SLIME_YELLOW_0
ProtoBat::
	EnemyPrototype 2, 1, 1, BehaviourBat, 1, FLAG_BAT_0, SPRITE_BAT_0, SPRITE_BAT_0
ProtoBatRed::
	EnemyPrototype 1, 1, 2, BehaviourBat, 1, FLAG_BAT_RED_0, SPRITE_BAT_RED_0, SPRITE_BAT_RED_0
ProtoSkeleton::
	EnemyPrototype 2, 1, 1, BehaviourSeek, 0, FLAG_SKELETON_0, SPRITE_SKELETON_0, SPRITE_SKELETON_1
ProtoSkeletonYellow::
	EnemyPrototype 2, 2, 2, BehaviourSkeleton, 0, FLAG_SKELETON_YELLOW_0, SPRITE_SKELETON_YELLOW_0, SPRITE_SKELETON_YELLOW_1
ProtoSkeletonBlack::
	EnemyPrototype 2, 3, 4, BehaviourSkeleton, 0, FLAG_SKELETON_BLACK_0, SPRITE_SKELETON_BLACK_0, SPRITE_SKELETON_BLACK_1
ProtoWraith::
	EnemyPrototype 1, 1, 1, BehaviourSeek, 0, FLAG_WRAITH_0, SPRITE_WRAITH_0, SPRITE_WRAITH_0
ProtoDirebat::
	EnemyPrototype 2, 2, 3, BehaviourBat, 1, FLAG_DIREBAT_SMALL_0, SPRITE_DIREBAT_0, SPRITE_DIREBAT_0
ProtoDirebatGrey::
	EnemyPrototype 2, 3, 4, BehaviourBat, 1, FLAG_DIREBAT_GREY_SMALL_0, SPRITE_DIREBAT_GREY_0, SPRITE_DIREBAT_GREY_0


SECTION "Enemy code", ROM0


; Clear enemy list and set up initial state
InitEnemies::
	ld HL, EnemyList
	ld B, ENEMY_LIST_SIZE
	ld A, $ff
.loop
	ld [HL+], A
	RepointStruct HL, 1, ENEMY_SIZE ; repoint to start of next
	dec B
	jr nz, .loop
	ret


; Add enemy with prototype BC to list with initial position DE
; Clobbers A, HL, D
AddEnemy::
	; find open slot
	ld HL, EnemyList
	jr .findloop
.findloopnext
	RepointStruct HL, 0, ENEMY_SIZE
.findloop
	ld A, [HL]
	inc A ; set z if A == 255
	jr nz, .findloopnext

	; Now copy prototype and initial position
	; Assumes pos is at start of struct
	ld A, D
	ld [HL+], A
	ld A, E
	ld [HL+], A

	LongAddConst BC, 2 ; point to after pos
	ld D, ENEMY_SIZE - 2
.copyloop
	ld A, [BC]
	ld [HL+], A
	inc BC
	dec D
	jr nz, .copyloop
	ret


; Looks for an enemy in position DE, returning a pointer to its enemy_pos_y in HL if found.
; Sets z if found, unsets z if not found.
; Clobbers A, B, HL
LookForEnemy::
	ld HL, EnemyList
	ld B, ENEMY_LIST_SIZE
.loop
	ld A, [HL+]
	cp D
	Debug "Looking for enemy %B% at X=%D% and got %A%"
	jr nz, .next
	ld A, [HL]
	cp E
	Debug "Looking for enemy %B% at Y=%E% and got %A%"
	ret z

.next
	LongAdd HL, ENEMY_SIZE - 1, HL

	dec B
	jr nz, .loop

	inc B; unset z
	ret


; Called to enact the enemy turn.
; Note this only updates the enemy list, it doesn't affect graphics directly.
; Clobbers all.
ProcessEnemies::

	ld B, ENEMY_LIST_SIZE
	ld HL, EnemyList
	jr .for_each_enemy

.invalid_enemy

	LongAdd HL, ENEMY_SIZE, HL
	dec B
	jr z, .for_each_enemy_break

.for_each_enemy

	; HL points at enemy X
	ld A, [HL]
	inc A ; set z if A == $ff
	jr z, .invalid_enemy

	; check if it should become active
	AbsDiff [PlayerX], [HL]
	cp 5 ; set c if <= 4
	jr nc, .no_activate
	inc HL
	AbsDiff [PlayerY], [HL]
	dec HL
	cp 5 ; set c if <= 4
	jr c, .activate

.no_activate
	xor A
	jr .check_active

.activate
	ld A, 1

.check_active
	RepointStruct HL, 0, enemy_active

	or [HL] ; set z if still inactive, A = was already active | should become active
	jr z, .inactive
	ld [HL-], A ; save new active state

	RepointStruct HL, enemy_active + (-1), enemy_step
	xor A
	or [HL] ; set z if [HL] == 0
	jr nz, .no_reset_step

	; reset step
	RepointStruct HL, enemy_step, enemy_step_length
	ld A, [HL-]
	RepointStruct HL, enemy_step_length + (-1), enemy_step
	ld [HL], A

.no_reset_step

	dec [HL] ; update step, set z if now 0
	jr nz, .no_step

	; set moving flag
	RepointStruct HL, enemy_step, enemy_moving_flag
	ld A, 1
	ld [HL+], A

	; invoke behaviour handler
	RepointStruct HL, enemy_moving_flag + 1, enemy_behaviour
	ld A, [HL+]
	ld D, H
	ld E, L
	ld H, [HL]
	ld L, A
	push BC
	call CallHL ; call behaviour
	pop BC

	ld H, D
	ld L, E
	RepointStruct HL, enemy_behaviour + 1, ENEMY_SIZE
	jr .next

.no_step
	; unset moving flag
	RepointStruct HL, enemy_step, enemy_moving_flag
	xor A
	ld [HL+], A

	RepointStruct HL, enemy_moving_flag + 1, ENEMY_SIZE
	jr .next

.inactive
	RepointStruct HL, enemy_active, ENEMY_SIZE

.next
	dec B
	jr .for_each_enemy
.for_each_enemy_break

	ret


; Behaviour handlers
; They are called with DE = enemy_behaviour + 1 and must preserve DE. May clobber others.
; Should update enemy object to do whatever they need, but most commonly going to update
; position and moving.
; Responsible for validating enemy movement and performing attacks.

; Helper for behaviour handlers. Reads enemy moving and tries to move enemy in that direction.
; Handles checking validity and attacking.
; Expects HL = enemy_moving_y
; Outputs a result in A:
;  0: Moved
;  1: Blocked by wall or enemy (cancels move and resets step counter to 1)
;  255: Attacked (cancels move)
; Clobbers B,C,H,L
MoveEnemy:
	; BC = moving
	ld A, [HL-]
	ld C, A
	ld A, [HL-]
	ld B, A

	RepointStruct HL, enemy_moving_x + (-1), enemy_pos_y

	; BC += pos, ie. BC = pos + moving = destination
	ld A, [HL-]
	add C
	ld C, A
	ld A, [HL+]
	add B
	ld B, A

	; check if BC == player pos, if so attack
	ld A, [PlayerX]
	cp B
	jr nz, .no_attack
	ld A, [PlayerY]
	cp C
	jr nz, .no_attack

	; dest pos is player pos, make an attack

	; clear move
	RepointStruct HL, enemy_pos_y, enemy_moving_x
	xor A
	ld [HL+], A
	ld [HL+], A

	; apply damage (unless player just stepped on stairs)
	ld A, [HasWon]
	and A
	jr nz, .has_won
	RepointStruct HL, enemy_moving_x + 2, enemy_damage
	ld B, [HL]
	ld A, [PlayerHealth]
	sub B
	ld [PlayerHealth], A

	; play noise
	ld A, 64
	call PlayNoise

.has_won

	; return ff
	ld A, $ff
	ret

.no_attack

	push DE
	push HL

	; Check if dest tile is floor
	ld D, B
	ld E, C
	call GetTileInBounds ; sets A = dest tile type

	cp TILE_FLOOR
	jr z, .tile_ok
	cp TILE_STAIRS
	jr nz, .blocked

.tile_ok
	; check if enemy is blocking
	push BC
	call LookForEnemy ; set z if found
	pop BC
	jr nz, .can_move

.blocked
	pop HL
	pop DE

	; blocked, cancel move and set step to 1
	; note moving flag is unchanged so we still bounce this turn
	RepointStruct HL, enemy_pos_y, enemy_moving_x
	xor A
	ld [HL+], A
	ld [HL+], A
	inc A ; A = 1
	RepointStruct HL, enemy_moving_y + 1, enemy_step
	ld [HL], A ; step = 1
	ret ; note A = 1

.can_move
	pop HL
	pop DE

	; update pos and return
	ld A, C
	ld [HL-], A
	ld A, B
	ld [HL], A
	xor A ; set A = 0 for return
	ret


; Moves up and down, up first. Stores 0/1 in enemy_state[0] to move up/down next.
BehaviourBlueSlime:
	ld H, D
	ld L, E
	RepointStruct HL, enemy_behaviour + 1, enemy_state
	ld A, [HL-] ; A = 0 for up, 1 for down
	add A ; A = 0 for up, 2 for down
	dec A ; A = -1 for up, 1 for down
	RepointStruct HL, enemy_state + (-1), enemy_moving_y
	ld [HL], A
	call MoveEnemy ; set A = 0 if actually moved
	and A ; set z if actually moved
	ret nz ; if we didn't move, we're done
	; we moved, flip state
	ld H, D
	ld L, E
	RepointStruct HL, enemy_behaviour + 1, enemy_state
	ld A, 1
	sub [HL] ; 0->1, 1->0
	ld [HL], A ; save new state
	ret

; Moves up/right/down/left, up first. Stores 0/1/2/3 in enemy_state[0] to move up/right/down/left next.
YellowSlimeMoveLUT:
	db 0, -1
	db 1, 0
	db 0, 1
	db -1, 0
BehaviourYellowSlime:
	ld H, D
	ld L, E
	RepointStruct HL, enemy_behaviour + 1, enemy_state
	ld A, [HL-] ; A = state
	add A ; A = 2 * A
	push HL
	LongAddToA YellowSlimeMoveLUT, HL ; HL = state as index into LUT
	ld A, [HL+]
	ld B, A
	ld C, [HL]
	pop HL ; BC = move vector
	RepointStruct HL, enemy_state + (-1), enemy_moving_x
	ld A, B
	ld [HL+], A
	ld [HL], C
	call MoveEnemy ; set A = 0 if actually moved
	and A ; set z if actually moved
	ret nz ; if we didn't move, we're done
	; we moved, inc state
	ld H, D
	ld L, E
	RepointStruct HL, enemy_behaviour + 1, enemy_state
	ld A, [HL]
	inc A
	and 3 ; % 4
	ld [HL], A ; save new state
	ret



; Moves randomly. If hits a wall, retries up to 10 times (a hack; but easy)
BehaviourBat:
	ld H, D
	ld L, E
	RepointStruct HL, enemy_behaviour + 1, enemy_moving_y
	ld B, 10

.loop
	push BC
	push HL
	call GetRNG ; A = random
	rra ; set carry = random bit
	jr c, .move_x

.move_y
	and 2 ; A = random value 0 or 2
	dec A ; A = -1 or 1
	ld [HL-], A ; moving_y = -1 or 1
	xor A
	ld [HL+], A ; moving_x = 0
	jr .move

.move_x
	and 2 ; A = random value 0 or 2
	dec A ; A = -1 or 1
	dec HL
	ld [HL+], A ; moving_x = -1 or 1
	xor A
	ld [HL], A ; moving_y = 0

.move
	call MoveEnemy ; sets A = 1 if move failed
	pop HL
	pop BC
	dec A ; set z if A == 1
	jr nz, .finish
	dec B
	jr nz, .loop ; try again, up to 10 times

	; after 10th time, just accept lack of move this turn
	ret

.finish
	; blocked moves may have resulted in setting step to 1, reset it to 0
	RepointStruct HL, enemy_moving_y, enemy_step
	xor A
	ld [HL], A
	ret


; Seeks out the player. Most 'normal' enemies act like this.
; Will attempt to move closer in X coord, or in Y coord if X == 0 or blocked
BehaviourSeek:
	ld H, D
	ld L, E
	RepointStruct HL, enemy_behaviour + 1, enemy_pos_x

	ld A, [PlayerX]
	sub [HL] ; A = player x - enemy x, set z if equal, set c if player x < enemy x
	inc HL
	jr z, .no_x

	RepointStruct HL, enemy_pos_y, enemy_moving_x
	ld A, -1
	jr c, .move_x_neg
	ld A, 1
.move_x_neg
	ld [HL+], A
	xor A
	ld [HL], A

	push HL
	call MoveEnemy ; sets A = 1 if move failed
	pop HL
	dec A ; set z if A == 1
	ret nz ; if we moved or attacked, we're done

	RepointStruct HL, enemy_moving_y, enemy_pos_y

.no_x
	ld A, [PlayerY]
	sub [HL] ; A = player y - enemy y, set z if equal, set c if player y < enemy y
	ret z ; if y diff == 0, x must've been blocked. just let that stand.
	ld A, 0 ; can't xor, we want to preserve c flag

	; a blocked x move might've set step to 1, set it back to 0
	RepointStruct HL, enemy_pos_y, enemy_step
	ld [HL-], A

	RepointStruct HL, enemy_step + (-1), enemy_moving_x
	ld [HL+], A
	ld A, -1
	jr c, .move_y_neg
	ld A, 1
.move_y_neg
	ld [HL], A

	call MoveEnemy

	ret


; Like BehaviourSeek except when on 1 health, then switch to headless sprite, move every turn.
; Expects headless variant to be sprite0 + 2, sprite1 + 1
; Headless version doesn't move, and doesn't appear until next time skeleton would move,
; but good enough.
BehaviourSkeleton:
	ld H, D
	ld L, E
	RepointStruct HL, enemy_behaviour + 1, enemy_health
	ld A, [HL-]
	dec A ; set z if A == 1
	jp nz, BehaviourSeek

	; set behaviour = nopfunc
	RepointStruct HL, enemy_health + (-1), enemy_behaviour + 1
	ld A, HIGH(NopFunc)
	ld [HL-], A
	ld A, LOW(NopFunc)
	ld [HL-], A

	; set sprites to headless
	RepointStruct HL, enemy_behaviour + (-1), enemy_sprites + 1
	ld A, [HL]
	add 4
	ld [HL-], A
	ld A, [HL]
	add 8
	ld [HL-], A

	; set step length to 1
	RepointStruct HL, enemy_sprites + (-1), enemy_step_length
	ld A, 1
	ld [HL-], A

	; set moving to (0, 0)
	RepointStruct HL, enemy_step_length + (-1), enemy_moving_y
	xor A
	ld [HL-], A
	ld [HL], A

	ret
