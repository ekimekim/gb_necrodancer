
include "debug.asm"
include "longcalc.asm"
include "macros.asm"
include "tile.asm"

SECTION "Map memory", WRAMX, BANK[1], ALIGN[6]

; Map is a 64x64 2d array of tile types (1 byte)
; Note each row is aligned (has constant upper byte)
Map::
	ds 64*64
_MapEnd:

MAP_SIZE EQU _MapEnd - Map

SECTION "Map methods", ROM0


; Loads map data starting at HL into current map
; Clobbers A, HL, DE
LoadMap::
	ld DE, Map
	ld BC, MAP_SIZE
	LongCopy
	ret


; Fetch tile for coord (D, E), which may be out of bounds, returning in A
; Clobbers HL.
GetTile::
	; check bounds
	ld H, %11000000
	ld A, D
	and H ; set z if D in [0, 64)
	jr nz, _GetTileOOB ; return A=0 if D out of range
	ld A, E
	and H ; set z if e in [0, 64)
	jr nz, _GetTileOOB ; return A=0 if E out of range
_GetTile:
	; calculate offset
	ld L, E
	; note that we're shifting the top 2 bits of H away, so
	; its effective initial value is 0 (when coming from GetTile)
REPT 6
	LongShiftL HL
ENDR
	; now HL = 64 * E
	LongAdd HL, Map, HL ; HL = Map + 64*E
	ld A, D
	add L
	ld L, A ; HL += D (no carry since we know it's aligned)
	ld A, [HL] ; actual lookup
	Debug "Looked up tile (%D%:%E%) = %A%"
	ret

_GetTileOOB:
	xor A
	Debug "Looked up tile (%D%:%E%) = %A% (out of bounds)"
	ret

; As GetTile but skips bounds check. Result for out-of-bounds tiles undefined.
; Clobbers HL.
GetTileInBounds::
	ld H, 0
	jr _GetTile


; Update tile at coord (D, E) to C and schedules it for a graphics update
; Clobbers A, HL
SetTile::
	ld H, 0
	ld L, E
REPT 6
	LongShiftL HL
ENDR
	; now HL = 64 * E
	LongAdd HL, Map, HL ; HL = Map + 64*E
	ld A, D
	add L
	ld L, A ; HL += D (no carry since we know it's aligned)
	ld [HL], C ; actual update
	jp EnqueueTileRedraw
