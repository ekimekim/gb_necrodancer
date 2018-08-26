
include "enemy.asm"
include "hram.asm"
include "ioregs.asm"
include "longcalc.asm"
include "tile.asm"

SECTION "Player logic", ROM0

; List of handlers for each tile type, saying what to do when you attempt to move into them.
; Each handler is called with DE = (x,y), and may clobber all regs
MoveIntoTileHandlers:
	dw PreventMove ; TILE_NONE, shouldn't ever happen
	dw NopFunc ; TILE_FLOOR
	dw DigWall ; TILE_DIRT_WALL
	dw PreventMove ; TILE_STONE_WALL
	dw PreventMove ; TILE_BOUNDARY
	dw EndLevel ; TILE_STAIRS

ProcessInput::

	; Can't move if we're mid-animation (but it's not a missed beat)
	ld A, [AnimationTimer]
	and A
	ret nz

	; If player is dead, do nothing except wait for button press
	ld A, [PlayerHealth]
	rla ; move top bit into c, setting c if health is negative
	jp c, PlayerDead

	xor A
	ld [MovingX], A
	ld [MovingY], A

	call GatherInput
	and A
	ld C, A
	jr z, .noinput

	; Can't move if we've already moved this beat (missed beat)
	ld A, [BeatHasProcessed]
	and A
	jp nz, MissedBeat
	jr .doTurn

.noinput
	; If it's the end of the beat and we haven't moved, process turn with nothing pressed
	; and trigger a missed beat.
	; otherwise, either:
	;   no input and beat's not over, do nothing
	;   no input and beat's over but we did something this beat, do nothing
	ld A, [BeatTimer]
	ld B, A
	ld A, [BeatHasProcessed]
	or B ; set z if BeatTimer == 0 and BeatHasProcessed == 0
	ret nz
	call MissedBeat

.doTurn
	ld A, C
	rla ; rotate left through carry, so top bit goes into carry
	jr nc, .nodown
	ld A, 1
	ld [MovingY], A
	jr .afterinput
.nodown
	rla
	jr nc, .noup
	ld A, -1
	ld [MovingY], A
	jr .afterinput
.noup
	rla
	jr nc, .noleft
	ld A, -1
	ld [MovingX], A
	jr .afterinput
.noleft
	rla
	jr nc, .noright
	ld A, 1
	ld [MovingX], A
	jr .afterinput
.noright
	; TODO button parsing here
.afterinput

	ld A, 1
	ld [BeatHasProcessed], A

	; Check dest square
	; NOTE we rely on movement validity to prevent player going out of bounds
	ld A, [PlayerX]
	ld B, A
	ld A, [MovingX]
	add B
	ld D, A

	ld A, [PlayerY]
	ld B, A
	ld A, [MovingY]
	add B
	ld E, A

	push DE ; DE = dest pos

	call GetTile ; set A = tile we're moving to
	rrca ; halve A (top bit = 0 since tile values are multiples of 4)
	LongAddToA MoveIntoTileHandlers, HL
	ld A, [HL+]
	ld H, [HL]
	ld L, A ; HL = [HL], little endian
	call CallHL ; call tile handler, clobbers all and may mutate hram / call MissedBeat

	pop DE ; DE = dest pos

	; check if enemy is in dest tile
	call LookForEnemy ; sets z if enemy found
	jr nz, .no_enemy

	; Enemy found. HL = enemy's pos_y
	RepointStruct HL, enemy_pos_y, enemy_health
	dec [HL] ; reduce enemy health, set z if now zero
	jr nz, .no_kill

	; invalidate sprite by setting x pos = ff
	RepointStruct HL, enemy_health, enemy_pos_x
	ld A, $ff
	ld [HL], A

.no_kill
	call CancelMove
	; play "hit" sound
	ld A, 32
	call PlayNoise

.no_enemy
	; Finally, update new player pos with final result of MovingX/MovingY
	ld A, [PlayerX]
	ld B, A
	ld A, [MovingX]
	add B
	ld [PlayerX], A

	ld A, [PlayerY]
	ld B, A
	ld A, [MovingY]
	add B
	ld [PlayerY], A

	ld A, 16
	ld [AnimationTimer], A

	; Now process enemies
	jp ProcessEnemies


PlayerDead:
	; for now just do nothing. TODO press key to reset
	ret


; Clobbers A, B
MissedBeat:
	ret


; Check joypad state and return it in A, with top half being dpad
; Clobbers B
GatherInput:
	ld A, JoySelectDPad
	ld [JoyIO], A
REPT 6
	nop
ENDR
	ld A, [JoyIO]
	cpl
	and $0f
	swap A
	ld B, A
	ld A, JoySelectButtons
	ld [JoyIO], A
REPT 6
	nop
ENDR
	ld A, [JoyIO]
	cpl
	and $0f
	or B
	ret


; Zeroes out Moving vars. Clobbers A.
CancelMove:
	xor A
	ld [MovingX], A
	ld [MovingY], A
	ret

; Tile handlers

; Cancels movement and triggers missed beat
PreventMove:
	call CancelMove
	ld A, 16
	call PlayNoise
	jp MissedBeat

; Cancels movement, digs out a wall by replacing it with a floor
DigWall:
	call CancelMove
	ld C, TILE_FLOOR
	jp SetTile

; Called when we step on stairs. Does nothing for now.
EndLevel:
	ret
