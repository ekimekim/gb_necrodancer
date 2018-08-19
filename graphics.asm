
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


; placeholders
SPRITE_CADENCE EQU 0


SECTION "Graphics data", ROM0

MapTilePixels:
; placeholders
include "assets/tile_none.asm"
include "assets/tile_dirt_0.asm"
_EndMapTilePixels:
MAP_TILE_PIXELS_SIZE EQU _EndMapTilePixels - MapTilePixels

MapSpritePixels:
; placeholders
include "assets/cadence_0.asm"
_EndMapSpritePixels:
MAP_SPRITE_PIXELS_SIZE EQU _EndMapSpritePixels - MapSpritePixels

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


SECTION "Sprite Bounce LUT", ROM0, ALIGN[4]

; SpriteBounce lookup-table maps from AnimationTimer to change in Y position.
; This sequence approximates a parabolic arc with apex at 4 pixels
SpriteBounce:
	db 0, -1, -2, -2, -3, -3, -3, -3, -4, -3, -3, -3, -3, -2, -2, -1


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

	; Copy sprite data
	ld BC, MAP_SPRITE_PIXELS_SIZE
	ld HL, MapSpritePixels
	ld DE, BaseTileMap
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

	; Update sprites

	; Player sprite is always at (72, 64) + bounce and occupies sprite slots 0-1
	ld HL, SpriteTable
	ld D, 72 + 8
	ld E, 64 + 16
	ld B, SPRITE_CADENCE
	ld C, 0
	call WriteSprite

	ret


; Write sprite with tile numbers B to B+3 to (D-8, E-16) with flags C using pair of sprite slots,
; with HL pointing to first slot.
; Automatically includes sprite bounce.
; Clobbers A, E. Points HL to 2 sprite slots forward.
WriteSprite:
	ld A, [AnimationTimer]
	push HL
	LongAddToA SpriteBounce, HL
	ld A, [HL]
	pop HL
	add A, E
	ld [HL+], A ; first Y
	ld E, A
	ld A, D
	ld [HL+], A ; first X
	ld A, B
	ld [HL+], A ; first tile
	ld A, C
	ld [HL+], A ; first flags
	ld A, E
	ld [HL+], A ; second Y
	ld A, D
	add 8
	ld [HL+], A ; second X
	ld A, B
	add 2
	ld [HL+], A ; second tile
	ld A, C
	ld [HL+], A ; second flags
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
