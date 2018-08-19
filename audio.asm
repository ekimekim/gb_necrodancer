
include "hram.asm"
include "ioregs.asm"

SECTION "Audio data", ROM0

include "placeholder_music.asm"

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
	SetReg SoundCh1Volume, $f0 ; full volume, no envelope

	SetReg SoundCh2LengthDuty, %10000000 ; 50% duty, length doesn't matter
	SetReg SoundCh2Volume, $f0 ; full volume, no envelope

	SetReg SoundCh3OnOff, %10000000 ; turn on
	SetReg SoundCh3Volume, %00100000 ; full volume

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

.newStepAfterLoad
	ld A, [HL+]
	and A
	jr z, .loopSong
	ld [AudioTimer], A

	ld A, [HL+]
	ld [SoundCh1FreqLo], A
	ld A, [HL+]
	ld [SoundCh1Control], A
	ld A, [HL+]
	ld [SoundCh2FreqLo], A
	ld A, [HL+]
	ld [SoundCh2Control], A
	ld A, [HL+]
	ld [SoundCh3FreqLo], A
	ld A, [HL+]
	ld [SoundCh3Control], A

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
	ld B, A
	ld A, 64
	sub B
	ld [SoundCh4Length], A
	ld A, %11000000
	ld [SoundCh4Control], A ; play now and stop after length
	ret
