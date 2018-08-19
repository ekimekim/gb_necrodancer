
include "hram.asm"
include "ioregs.asm"
include "longcalc.asm"
include "macros.asm"
include "vram.asm"

; Screen is 20x18 hardware tiles = 10x9 map tiles
; We display with a half-tile offset to keep player tile centered,
; so 11x9 tiles are on screen at once.
; So we can see 5 non-player columns in each direction, and 4 non-player rows.
; The player is always at pixel location (72, 64), ie. size/2 - 8

; The map maps to the tilemap by (coord * 16) % 32


SECTION "Graphics data", ROM0

MapTilePixels:
; placeholders
include "assets/tile_none.asm"
include "assets/tile_floor.asm"
_EndMapTilePixels:

MAP_TILE_PIXELS_SIZE EQU _EndMapTilePixels - MapTilePixels

; define a color word from rgb args
Color: MACRO
value = \3 << 10 + \2 << 5 + \1
	db LOW(value), HIGH(value)
ENDM

TilePalettes:
SpritePalettes:
	; placeholder palettes for now, greyscale
REPT 8
	Color 31, 31, 31
	Color 21, 21, 21
	Color 10, 10, 10
	Color 0, 0, 0
ENDR

SECTION "Graphics methods", ROM0


InitGraphics::
	; Set palettes
	ld A, %10000000
	ld [TileGridPaletteIndex], A
	ld [SpritePaletteIndex], A
	ld B, 64
	ld HL, TilePalettes
	ld DE, SpritePalettes
.paletteLoop
	ld A, [HL+]
	ld [TileGridPaletteData], A
	ld A, [DE]
	inc DE
	ld [SpritePaletteData], A
	dec B
	jr nz, .paletteLoop

	; Copy tile data
	ld BC, MAP_TILE_PIXELS_SIZE
	ld HL, MapTilePixels
	ld DE, AltTileMap
	LongCopy

	ret


UpdateGraphics::
	; Runs during vblank

	; If animation timer == 15, we need to write a new row or column
	ld A, [AnimationTimer]
	cp 15 ; set z if == 15
	jr nz, .noNewRowCol

	; When we move, we need to write the new row or column that's entering visual range,
	; which is 5 or 4 away from the player's _new_ position in the direction of MovingX or Y.

	ld A, [PlayerX]
	ld B, A
	ld A, [MovingX]
	ld C, A
	add A
	add A ; A = 4*A
	add C ; A = 4*A + C = 5 * MovingX
	add B ; A = 5*MovingX + PlayerX = target column
	call WriteColumn

	ld A, [PlayerY]
	ld B, A
	ld A, [MovingY]
	ld C, A
	add A
	add A ; A = 4*A
	add B ; A = 4*MovingY + PlayerX = target column
	call WriteRow

.noNewRowCol

	; Calcluate ScrollX and ScrollY
	ld A, [PlayerX]
	swap A
	and $f0 ; A = 16 * A % 256
	sub 72
	ld D, A ; D = (16 * A - 72) % 256
	ld A, [PlayerY]
	swap A
	sub 64
	and $f0 ; A = (16 * A - 64) % 256
	ld E, A
	ld A, [MovingX]
	ld H, A
	ld A, [MovingY]
	ld L, A
	ld A, [AnimationTimer]
	and A
	jr z, .skipCalcScroll
	ld B, A
.calcScroll
	ld A, D
	sub H
	ld D, A
	ld A, E
	sub L
	ld E, A
	dec B
	jr nz, .calcScroll
.skipCalcScroll
	; Now D and E = 16 * player pos - player sprite location on screen - AnimationTimer * moving vector
	ld A, D
	ld [ScrollX], A
	ld A, E
	ld [ScrollY], A

	; TODO sprites

	ret


; Write column A from map to background map.
WriteColumn:
	; set map coords
	ld D, A
	ld A, [PlayerY]
	sub 4
	ld E, A
	; calculate destination tile
	ld L, E
	ld H, 0
REPT 6
	LongShiftL HL
ENDR
	ld A, H
	and %00000011 ; AL = (E * 64) % 1024
	or $98 ; AL = TileGrid + ((E*64) % 1024) = start of target row in TileGrid
	ld H, A ; HL = AL
	ld A, D
	add A
	and %00011111 ; A = (2*D) % 32
	add L
	ld L, A ; HL += (2*D) % 32 = target position
	; run for 9 tiles
	ld B, 9
.loop
	push HL
	call GetTile ; A = tile
	pop HL
	ld [HL+], A ; set tile top-left
	inc A
	inc A
	ld [HL], A ; set tile top-right
	dec A
	ld C, A
	ld A, L
	add 31
	ld L, A ; HL = saved HL + 32. no carry because aligned for odd rows.
	ld [HL], C ; set tile bottom-left
	inc C
	inc C
	inc L
	ld [HL], C ; set tile bottom-right
	LongAdd HL, 31, HL ; Long add because even rows may not be aligned (every 8th row overflows)
	ld A, H
	and %00000011 ; HL % 1024
	or $98 ; loop HL back to start of TileGrid
	ld H, A
	inc E
	dec B
	jr nz, .loop
	ret


; Write row A from map to background map.
; Clobbers all
WriteRow:
	; set map coords
	ld E, A
	ld A, [PlayerX]
	sub 5
	ld D, A
	; calculate destination tile
	ld L, E
	ld H, 0
REPT 6
	LongShiftL HL
ENDR
	ld A, H
	and %00000011 ; AL = (E * 64) % 1024
	or $98 ; AL = TileGrid + ((E*64) % 1024) = start of target row in TileGrid
	ld H, A ; HL = AL
	; run for 11 tiles
	ld B, 11
.loop
	push HL
	call GetTile ; A = tile
	pop HL
	ld C, A
	ld A, D
	add A
	and %00011111 ; A = (2*D) % 32
	add L
	push HL
	ld L, A ; HL = saved HL + (2*D)%32 = target position
	ld [HL], C ; set tile top-left
	inc C
	inc C
	inc L
	ld [HL], C ; set tile top-right
	dec C
	add 32
	ld L, A ; HL = saved HL + (2*D)%32 + 32
	ld [HL], C ; set tile bottom-left
	inc C
	inc C
	inc L
	ld [HL], C ; set tile bottom-right
	pop HL ; HL = start of target row again
	inc D
	dec B
	jr nz, .loop
	ret


; Write entire screen centered on Player position.
; Takes long enough that screen must be off.
WriteScreen::
	ld A, [PlayerY]
	sub 4
	ld C, A
	ld B, 9
.loop
	push BC
	ld A, C
	call WriteRow
	pop BC
	inc C
	dec B
	jr nz, .loop
	ret
