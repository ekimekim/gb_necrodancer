
include "debug.asm"
include "hram.asm"
include "ioregs.asm"
include "level.asm"
include "longcalc.asm"

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
	call InitRNG ; should be first
	call InitGraphics
	call InitAudio

	xor A
	ld [LevelNumber], A

	; Load first level
	call LoadLevel

	; Set up LCD: Use main tilegrid, signed tilemap, tall sprites, window on and using alt tilegrid
	ld A, %11100110
	ld [LCDControl], A

	; Enable vblank only
	ld A, IntEnableVBlank
	ld [InterruptsEnabled], A
	ei

.mainloop

	call ProcessInput
	call UpdateCounters
	call PrepareGraphics
	halt ; wait for vblank
IF DEBUG > 0
	call CheckLag
ENDC
	call UpdateAudio
	call UpdateGraphics

	; make randomness more random by always consuming at least one value per frame
	call GetRNG

	jp .mainloop


CheckLag:
	ld A, [DetectLag]
	dec A ; set z if A == 1, which it should be
	DebugIfNot z, "Detected %A% lag frames"
	xor A
	ld [DetectLag], A
	ret


InitCounters:
	xor A
	ld [AnimationTimer], A
	ld [BeatCounter], A
	ld [BeatCounter+1], A
	ld [BeatHasProcessed], A
	ld A, [BeatLength]
	ld [BeatTimer], A
IF DEBUG > 0
	ld [DetectLag], A
ENDC
	ld A, 5
	ld [PlayerHealth], A
	xor A
	ld [HasWon], A
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


HLFromDE:
	ld A, [DE]
	ld L, A
	inc DE
	ld A, [DE]
	ld H, A
	inc DE
	ret

; Load the level. Expects screen to be off.
LoadLevel::
	ld A, [LevelNumber]
	add A
	add A
	add A
	add A ; A *= 16
	LongAddToA Levels, DE

	; Load map data
	RepointStruct DE, 0, level_map
	call HLFromDE
	push DE
	call LoadMap
	pop DE


	; Load enemies
	push DE
	call InitEnemies
	pop DE
	RepointStruct DE, level_map + 2, level_enemy_count
	call HLFromDE
	ld B, [HL]
	RepointStruct DE, level_enemy_count + 2, level_enemy_list
	call HLFromDE
	push DE
	ld A, B
.add_enemies
	push AF
	ld A, [HL+]
	ld C, A
	ld A, [HL+]
	ld B, A
	ld A, [HL+]
	ld D, A
	ld A, [HL+]
	ld E, A
	push HL
	call AddEnemy
	pop HL
	pop AF
	dec A
	jr nz, .add_enemies
	pop DE
	
	; Set other level vars
	RepointStruct DE, level_enemy_list + 2, level_start_x
	ld A, [DE]
	ld [PlayerX], A
	inc DE
	ld A, [DE]
	ld [PlayerY], A
	inc DE
	RepointStruct DE, level_start_x + 2, level_beat_length
	ld A, [DE]
	ld [BeatLength], A

	; reset all counters
	call InitCounters

	; init other things
	RepointStruct DE, level_beat_length, level_music
	call HLFromDE
	call LoadAudio

	; write initial set of tiles
	call WriteScreen

	ret


; Turn off screen and load next level
FinishLevel::
	halt ; wait for vblank again, just in case
	di
	ld A, [LCDControl]
	res 7, A
	ld [LCDControl], A ; turn off screen
	ei

	ld A, [LevelCount]
	ld B, A
	ld A, [LevelNumber]
	inc A
	cp B ; set z if equal
	jr nz, .no_reset
	; reset back to level 1
	xor A
.no_reset
	ld [LevelNumber], A

	call LoadLevel

	; turn screen back on
	ld A, [LCDControl]
	set 7, A
	ld [LCDControl], A

	ret
