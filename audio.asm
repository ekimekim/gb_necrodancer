
include "debug.asm"
include "hram.asm"
include "ioregs.asm"

SECTION "Audio data", ROMX, BANK[1]

LevelMusic::
include "music/1-1.asm"

SECTION "Audio methods", ROM0

SetReg: MACRO
	ld A, \2
	ld [\1], A
ENDM

InitAudio::
	SetReg SoundControl, $80 ; turn sound on
	SetReg SoundVolume, $77 ; full volume
	SetReg SoundMux, $ff ; all channels to stereo

	SetReg SoundCh1Sweep, 0 ; no sweep
	SetReg SoundCh1LengthDuty, %10000000 ; 50% duty, length doesn't matter

	SetReg SoundCh2LengthDuty, %10000000 ; 50% duty, length doesn't matter

	SetReg SoundCh3OnOff, %10000000 ; turn on

	; Set up a square wave such that frequency acts the same as ch1 and ch2
	ld C, LOW(SoundCh3Data)
REPT 2
REPT 4
	ld A, $ff
	ld [C], A
	inc C
ENDR
	xor A
REPT 4
	ld [C], A
	inc C
ENDR
ENDR

	SetReg SoundCh4Volume, $f0 ; full volume
	SetReg SoundCh4RNG, 0 ; max freq (purest white noise)

	ret

; Sets up to begin playing song pointed to by HL
LoadAudio::
	ld A, 1
	ld [AudioTimer], A
	ld A, H
	ld [AudioStep+1], A
	ld A, L
	ld [AudioStep], A
	ret


; Runs each frame. Decrement AudioTimer and play next step if 0.
; If song ends, for now we just repeat it.
UpdateAudio::

	ld A, [AudioTimer]
	dec A
	jr z, .newStep
	ld [AudioTimer], A
	ret

.newStep
	ld A, [AudioStep+1]
	ld H, A
	ld A, [AudioStep]
	ld L, A

	Debug "Beginning step %HL%"

.newStepAfterLoad
	ld A, [HL+]
	and A
	jr z, .loopSong
	ld [AudioTimer], A
	Debug "Set timer to %A%"

	ld A, [HL+]
	ld [SoundCh1FreqLo], A
	ld A, [HL]
	; need to enable/disable by setting volume
	; (volume is easiest way to control on/off when not using length)
	and A
	jr z, .ch1off
	ld A, $f0
	jr .ch1next
.ch1off
	xor A
.ch1next
	ld [SoundCh1Volume], A
	ld A, [HL+]
	ld [SoundCh1Control], A

	ld A, [HL+]
	ld [SoundCh2FreqLo], A
	ld A, [HL]
	and A
	jr z, .ch2off
	ld A, $f0
	jr .ch2next
.ch2off
	xor A
.ch2next
	ld [SoundCh2Volume], A
	ld A, [HL+]
	ld [SoundCh2Control], A

	ld A, [HL+]
	ld [SoundCh3FreqLo], A
	ld A, [HL+]
	ld [SoundCh3Control], A
	and A
	jr z, .ch3off
	ld A, %00100000
	jr .ch3next
.ch3off
	xor A
.ch3next
	ld [SoundCh3Volume], A

	; save new step
	ld A, H
	ld [AudioStep+1], A
	ld A, L
	ld [AudioStep], A

	ret

.loopSong
	; jump to step at next two bytes
	ld A, [HL+]
	ld H, [HL]
	ld L, A
	jr .newStepAfterLoad


; Play white noise for A 1/256ths of a second (A must be in 1-64)
; Clobbers A, B.
PlayNoise::
	ret ; TEMP TODO remove
	ld B, A
	ld A, 64
	sub B
	ld [SoundCh4Length], A
	ld A, %11000000
	ld [SoundCh4Control], A ; play now and stop after length
	ret
