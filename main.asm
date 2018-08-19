
include "debug.asm"
include "hram.asm"
include "ioregs.asm"

Section "Core Stack", WRAM0

CoreStackBase:
	ds 64
CoreStack::


Section "Core Functions", ROM0


Start::

	; Disable LCD and audio.
	; Disabling LCD must be done in VBlank.
	; On hardware start, we have about half a normal vblank, but this may depend on the hardware variant.
	; So this has to be done quick!
	xor A
	ld [SoundControl], A
	ld [LCDControl], A

	Debug "Debug messages enabled"

	; Use core stack
	ld SP, CoreStack

	; Switch to double-speed mode
	ld A, 1
	ld [CGBSpeedSwitch], A
	stop

	; init things
	call InitGraphics
	call InitAudio

	; Load first level
	call LoadLevel

	; Set up LCD: Use main tilegrid, signed tilemap, tall sprites
	ld A, %10000110
	ld [LCDControl], A

	; Enable vblank only
	ld A, IntEnableVBlank
	ld [InterruptsEnabled], A
	ei

.mainloop

	call UpdateCounters
	call PrepareGraphics
	halt ; wait for vblank
	call UpdateAudio
	call UpdateGraphics
	call ProcessInput

	jp .mainloop


InitCounters:
	xor A
	ld [AnimationTimer], A
	ld [BeatCounter], A
	ld [BeatCounter+1], A
	ld [BeatHasProcessed], A
	ld A, [BeatLength]
	ld [BeatTimer], A
	ret


UpdateCounters:
	ld A, [AnimationTimer]
	sub 1 ; set c if A was 0
	jr c, .noanimation
	ld [AnimationTimer], A
.noanimation

	ld A, [BeatTimer]
	sub 1 ; set c if A was 0
	jr nc, .nonewbeat
	; new beat. increment BeatCounter and reset BeatHasProcessed
	ld A, [BeatCounter]
	ld D, A
	ld A, [BeatCounter+1]
	ld E, A
	inc DE
	ld A, D
	ld [BeatCounter], A
	ld A, E
	ld [BeatCounter+1], A
	xor A
	ld [BeatHasProcessed], A
	; and reset BeatTimer to BeatLength
	ld A, [BeatLength]
.nonewbeat
	ld [BeatTimer], A

	ret


; Load the level. Expects screen to be off.
LoadLevel::
	; Load map data
	ld HL, LevelMap
	call LoadMap
	; Set other level vars
	ld A, [LevelStartPos]
	ld [PlayerX], A
	ld A, [LevelStartPos+1]
	ld [PlayerY], A
	ld A, [LevelBeatLength]
	ld [BeatLength], A
	; reset all counters
	call InitCounters
	; init other things
	ld HL, PlaceholderMusic
	call LoadAudio
	; write initial set of tiles
	call WriteScreen
	ret
