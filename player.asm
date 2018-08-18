
include "hram.asm"
include "ioregs.asm"

SECTION "Player logic", ROM0

ProcessInput::

	; Can't move if we're mid-animation (but it's not a missed beat)
	ld A, [AnimationTimer]
	and A
	ret nz

	xor A
	ld [MovingX], A
	ld [MovingY], A

	call GatherInput
	and A
	jr z, .noinput
	ld B, A

	; Can't move if we've already moved this beat (missed beat)
	ld A, [BeatHasProcessed]
	and A
	jr nz, .missedbeat

	ld A, B
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

	; TODO movement validity / attacking here based on MovingX/Y
	; NOTE we rely on movement validity to prevent player going out of bounds

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

	ret

.noinput
	; If it's the end of the beat and we haven't moved, missed beat
	; otherwise, no input and beat's not over, do nothing
	ld A, [BeatTimer]
	and A
	ret nz

.missedbeat

	; TODO do stuff
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
