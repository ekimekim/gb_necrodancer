
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

ProtoSlimeGreen::
	EnemyPrototype 1, NopFunc, 1, FLAG_SLIME_GREEN_0, SPRITE_SLIME_GREEN_0, SPRITE_SLIME_GREEN_0
ProtoSlimeBlue::
	EnemyPrototype 2, BehaviourBlueSlime, 1, FLAG_SLIME_BLUE_0, SPRITE_SLIME_BLUE_0, SPRITE_SLIME_BLUE_0


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

	RepointStruct HL, enemy_step, enemy_behaviour
	ld A, [HL+]
	ld D, H
	ld E, L
	ld H, [HL]
	ld L, A
	call CallHL ; call behaviour

	ld H, D
	ld L, E
	RepointStruct HL, enemy_behaviour + 1, ENEMY_SIZE
	jr .next

.no_step
	RepointStruct HL, enemy_step, ENEMY_SIZE

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
;  1: Blocked by wall (cancels move and resets step counter to 1)
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
	ld B, A

	; TODO check if BC == player pos, if so attack

	; Check if dest tile is floor
	push DE
	push HL
	ld D, B
	ld E, C
	call GetTileInBounds ; sets A = dest tile type
	pop HL
	pop DE

	cp TILE_FLOOR
	jr z, .can_move
	cp TILE_STAIRS
	jr z, .can_move

	; blocked, cancel move and set step to 1
	RepointStruct HL, enemy_pos_y, enemy_moving_x
	xor A
	ld [HL+], A
	ld [HL+], A
	inc A ; A = 1
	RepointStruct HL, enemy_moving_y + 1, enemy_step
	ld [HL], A ; step = 1
	ret ; note A = 1

.can_move
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
