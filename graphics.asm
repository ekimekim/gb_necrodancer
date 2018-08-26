
include "enemy.asm"
include "hram.asm"
include "ioregs.asm"
include "longcalc.asm"
include "macros.asm"
include "ring.asm"
include "sprites.asm"
include "vram.asm"

include "assets/flag_define_cadence_0.asm"
include "assets/flag_define_heart.asm"

; Screen is 20x18 hardware tiles = 10x9 map tiles
; We display with a half-tile offset to keep player tile centered,
; so 11x9 tiles are on screen at once.
; So we can see 5 non-player columns in each direction, and 4 non-player rows.
; The player is always at pixel location (72, 64), ie. size/2 - 8

; The map maps to the tilemap by (coord * 16) % 32


SECTION "Graphics data", ROM0

MapTilePixels:
include "assets/tile_none.asm" ; TILE_NONE
include "assets/tile_dirt.asm" ; TILE_FLOOR
include "assets/tile_dirt_wall.asm" ; TILE_DIRT_WALL
include "assets/tile_stone.asm" ; TILE_STONE_WALL
include "assets/tile_none_wall.asm" ; TILE_BOUNDARY
include "assets/stairs.asm" ; TILE_STAIRS
_EndMapTilePixels:
MAP_TILE_PIXELS_SIZE EQU _EndMapTilePixels - MapTilePixels

SpritePixels:
include "assets/cadence_0.asm" ; SPRITE_CADENCE
include "assets/heart.asm" ; SPRITE_HEART_FULL
include "assets/heart_half.asm" ; SPRITE_HEART_HALF
include "assets/heart_empty.asm" ; SPRITE_HEART_EMPTY
include "assets/slime_green_0.asm" ; SPRITE_SLIME_GREEN_0
include "assets/slime_blue_0.asm" ; SPRITE_SLIME_BLUE_0
include "assets/slime_blue_1.asm" ; SPRITE_SLIME_BLUE_1
include "assets/bat_1.asm" ; SPRITE_BAT_0
include "assets/bat_red_1.asm" ; SPRITE_BAT_RED_0
include "assets/skeleton_0.asm" ; SPRITE_SKELETON_0
include "assets/skeleton_1.asm" ; SPRITE_SKELETON_1
include "assets/skeleton_yellow_0.asm" ; SPRITE_SKELETON_YELLOW_0
include "assets/skeleton_yellow_1.asm" ; SPRITE_SKELETON_YELLOW_1
include "assets/skeleton_black_0.asm" ; SPRITE_SKELETON_BLACK_0
include "assets/skeleton_black_1.asm" ; SPRITE_SKELETON_BLACK_1
_EndSpritePixels:
SPRITE_PIXELS_SIZE EQU _EndSpritePixels - SpritePixels

; palette definitions, 128 bytes
include "palettes.asm"

SECTION "Sprite Bounce LUT", ROM0, ALIGN[4]

; SpriteBounce lookup-table maps from AnimationTimer to change in Y position.
; This sequence approximates a parabolic arc with apex at 4 pixels
SpriteBounce:
	db 0, -1, -2, -2, -3, -3, -3, -3, -4, -3, -3, -3, -3, -2, -2, -1


SECTION "Tile flags LUT", ROM0, ALIGN[4]
; Should be in same order as MapTilePixels
TileFlags:
	include "assets/flags_tile_none.asm"
	include "assets/flags_tile_dirt.asm"
	include "assets/flags_tile_dirt_wall.asm"
	include "assets/flags_tile_stone.asm"
	include "assets/flags_tile_none_wall.asm"
	include "assets/flags_stairs.asm"


SECTION "Shadow sprite table", WRAM0, ALIGN[8]
; A copy of the sprite table that gets DMA'd over during vblank
ShadowSpriteTable:
	ds 160


SECTION "Other graphics memory", WRAM0

; This queue contains up to 21 triples (x, y, new value) of tiles to update
TileRedrawQueue:
	RingDeclare 63

; Contains the values we're going to update ScrollX and ScrollY to next
ShadowScrollX:
	db
ShadowScrollY:
	db

; Caches amount of bounce for this frame
BounceAmount:
	db

; Scratch space for storing a pointer into shadow sprite table (which is aligned)
SpriteSlot:
	db


SECTION "DMA wait routine data", ROM0

; Copied to hram for sprite dma.
; Loads A to DMATransfer then waits until complete
_DMAWait:
	ld [DMATransfer], A
	ld A, 40 ; loop is 4 cycles, we need to wait 160 cycles, 160/4 = 40
.wait
	dec a
	jr nz, .wait
	ret
DMA_WAIT_SIZE EQU @ - _DMAWait


SECTION "DMA wait routine", HRAM

DMAWait:
	ds DMA_WAIT_SIZE


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
	ld BC, SPRITE_PIXELS_SIZE
	ld HL, SpritePixels
	ld DE, BaseTileMap
	LongCopy

	; Set up DMA wait
	ld B, DMA_WAIT_SIZE
	ld HL, _DMAWait
	ld DE, DMAWait
	Copy

	; Zero sprite table
	xor A
	ld B, 160
	ld HL, ShadowSpriteTable
.zeroSprites
	ld [HL+], A
	dec B
	jr nz, .zeroSprites

	; Init redraw queue
	RingInit TileRedrawQueue

	ret


; Does work to prepare for UpdateGraphics. Cannot write to vram.
PrepareGraphics::

	; Calculate bounce
	call CalcBounce

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
	ld [ShadowScrollX], A
	ld A, E
	ld [ShadowScrollY], A

	; Draw player
	ld HL, ShadowSpriteTable
	; Skip drawing player sprite if dead
	ld A, [PlayerHealth]
	rla ; set c if < 0
	jr c, .player_dead
	; Player sprite is always at (72, 64) + bounce and occupies sprite slots 0-1
	ld D, 72 + 8
	ld A, [BounceAmount]
	add 64 + 16
	ld E, A
	ld B, SPRITE_CADENCE
	ld C, FLAG_CADENCE_0
	call WriteSprite
.player_dead

	; Draw player hearts
	ld B, 3
.player_hearts
	; determine position
	ld E, 16
	ld A, B
	rlca
	rlca
	rlca
	rlca ; A = 16*B
	add 96 + 8
	ld D, A
	; determine sprite number
	ld A, B
	add B
	dec A
	ld C, A ; C = 2*B-1
	ld A, [PlayerHealth]
	inc A ; player health is stored 0-based
	cp C ; set c if health < 2*B-1, z if health == 2*B-1
	; eg. if B == 3, 2*B-1 == 5, then:
	; if c then health < 5 (empty), if z then health == 5 (half), else health > 5 (full)
	push BC
	ld B, SPRITE_HEART_FULL
	jr nz, .no_half
	ld B, SPRITE_HEART_HALF
.no_half
	jr nc, .no_empty
	ld B, SPRITE_HEART_EMPTY
.no_empty
	ld C, FLAG_HEART
	call WriteSprite

	pop BC
	dec B
	jr nz, .player_hearts

	; Save sprite slot
	ld A, L
	ld [SpriteSlot], A

	; Iterate through and draw enemies
	ld DE, EnemyList
	ld B, ENEMY_LIST_SIZE
	jr .for_each_enemy

.invalid_enemy

	LongAdd DE, ENEMY_SIZE, DE
	dec B
	jp z, .for_each_enemy_break

.for_each_enemy

	; DE = enemy_pos_x
	ld A, [DE]
	inc A ; set z if A == $ff
	jr z, .invalid_enemy

	; check if on (or close to on) screen - within (6, 5)
	dec A ; A = X pos again
	ld H, A
	inc DE ; DE = enemy_pos_y
	ld A, [DE]
	ld L, A
	AbsDiff [PlayerX], H
	cp 7 ; set c if <= 6
	jr nc, .offscreen
	AbsDiff [PlayerY], L
	cp 6 ; set c if <= 5
	jr nc, .offscreen
	; note that HL now = position, and we know it's on screen.

	push BC

	; BC = Scroll X/Y
	ld A, [ShadowScrollX]
	ld B, A
	ld A, [ShadowScrollY]
	ld C, A

	; convert HL to background map coords by multiplying by 16 (mod 256),
	; then to screen coords by subtracting ScrollX/Y,
	; then to sprite coords by adding (8, 16)
	ld A, $0f
	and H
	swap A
	sub B
	add 8
	ld H, A
	ld A, $0f
	and L
	swap A
	sub C
	add 16
	ld L, A

	; is it moving?
	RepointStruct DE, 1, enemy_moving_flag
	ld A, [DE]
	RepointStruct DE, enemy_moving_flag, enemy_step
	and A ; set z if A == 0
	jr z, .not_moving

	; currently moving. subtract moving * animation timer
	push DE
	RepointStruct DE, enemy_step, enemy_moving_y
	ld A, [DE]
	ld C, A
	dec DE
	ld A, [DE]
	ld D, A
	ld E, C ; DE = moving

	ld A, [AnimationTimer]
	ld B, A
.mul_loop
	ld A, H
	sub D
	ld H, A
	ld A, L
	sub E
	ld L, A
	dec B
	jr nz, .mul_loop

	pop DE ; DE = enemy_step

	; add bounce
	ld A, [BounceAmount]
	add L
	ld L, A

.not_moving
	; DE = enemy_step and HL = screen coords

	; look up flag and sprite
	ld A, [DE]
	ld B, A ; B = step
	RepointStruct DE, enemy_step, enemy_sprite_flag
	ld A, [DE]
	ld C, A ; C = flag
	RepointStruct DE, enemy_sprite_flag, enemy_sprites
	push DE ; save enemy_sprites
	ld A, B
	LongAddToA DE, DE ; DE = enemy_sprites + step
	ld A, [DE]
	ld B, A ; B = sprite number

	; final setup
	ld D, H
	ld E, L ; DE = HL = coords
	ld H, HIGH(ShadowSpriteTable)
	ld A, [SpriteSlot]
	ld L, A

	call WriteSprite
	ld A, L
	ld [SpriteSlot], A

	pop DE ; DE = enemy_sprites
	pop BC
	RepointStruct DE, enemy_sprites, ENEMY_SIZE
	jr .next

.offscreen
	LongAdd DE, ENEMY_SIZE - 1, DE

.next
	dec B
	jp nz, .for_each_enemy
.for_each_enemy_break

	; zero remaining sprite slots
	; note: will break if all sprite slots are used, or it goes over
	ld H, HIGH(ShadowSpriteTable)
	ld A, [SpriteSlot]
	ld L, A
.zeroloop
	xor A
	ld [HL+], A
	ld [HL+], A
	ld [HL+], A
	ld [HL+], A
	ld A, L
	cp 160
	jr nz, .zeroloop

	ret


; Runs during vblank
UpdateGraphics::

	; If animation timer == 15, we need to write a new row or column
	ld A, [AnimationTimer]
	cp 15 ; set z if == 15
	jr nz, .noNewRowCol

	; When we move, we need to write the new row or column that's entering visual range,
	; which is 5 or 4 away from the player's _new_ position in the direction of MovingX or Y.

	ld A, [PlayerX]
	ld B, A
	ld A, [MovingX]
	and A
	jr z, .noMoveX
	ld C, A
	add A
	add A ; A = 4*A
	add C ; A = 4*A + C = 5 * MovingX
	add B ; A = 5*MovingX + PlayerX = target column
	call WriteColumn
.noMoveX

	ld A, [PlayerY]
	ld B, A
	ld A, [MovingY]
	and A
	jr z, .noMoveY
	ld C, A
	add A
	add A ; A = 4*A
	add B ; A = 4*MovingY + PlayerX = target column
	call WriteRow
.noMoveY

	jp .afterRedraw

.noNewRowCol

	; Since we're not drawing any new rows/cols, we have some time to update some existing
	; entries.
	; For simplicity / prevent overtime, we only do one per frame. This should be fine.
	RingPop TileRedrawQueue, 63, D ; set z if empty
	jp z, .afterRedraw
	; assume that no partial triplets can be written
	RingPopNoCheck TileRedrawQueue, 63, E
	RingPopNoCheck TileRedrawQueue, 63, C
	; now DE = coords and C = new value

	; check if coords are on screen: (D, E) in Player +/- (5, 4)
	AbsDiff [PlayerX], D ; A = |PlayerX - D|
	cp 6 ; set c if <= 5
	jr nc, .afterRedraw ; if c not set, out of range
	AbsDiff [PlayerY], E ; A = |PlayerY - E|
	cp 5 ; set c if <= 4
	jr nc, .afterRedraw ; if c not set, out of range

	; Look up flag
	ld A, C
	srl A
	srl A ; A = C/4
	add LOW(TileFlags)
	ld L, A
	ld H, HIGH(TileFlags)
	ld B, [HL]

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

	ld [HL], C ; set tile top-left
	inc C
	inc C
	inc L
	ld [HL], C ; set tile top-right
	dec C
	ld A, L
	add 31
	ld L, A ; HL = top-left + 32. no carry because aligned for odd rows.
	ld [HL], C ; set tile bottom-left
	inc C
	inc C
	inc L
	ld [HL], C ; set tile bottom-right

	; set flag on all 4 tiles
	ld A, 1
	ld [CGBVRAMBank], A ; set bank to 1
	ld [HL], B ; set flags bottom-right
	dec L
	ld [HL], B ; set flags bottom-left
	ld A, L
	sub 31
	ld L, A
	ld [HL], B ; set flags top-right
	dec L
	ld [HL], B ; set flags top-left
	xor A
	ld [CGBVRAMBank], A ; set bank back to 0

.afterRedraw

	; Copy sprite table
	ld A, HIGH(ShadowSpriteTable)
	call DMAWait

	; Copy ScrollX/Y
	ld A, [ShadowScrollX]
	ld [ScrollX], A
	ld A, [ShadowScrollY]
	ld [ScrollY], A

	ret

; Calculate bounce based on AnimationTimer and save in BounceAmount
; Clobbers A, HL
CalcBounce:
	ld A, [AnimationTimer]
	LongAddToA SpriteBounce, HL
	ld A, [HL]
	ld [BounceAmount], A
	ret

; Write sprite with tile numbers B to B+3 to (D-8, E-16) with flags C using pair of sprite slots,
; with HL pointing to first slot.
; Clobbers A, E. Points HL to 2 sprite slots forward.
WriteSprite:
	ld A, E
	ld [HL+], A ; first Y
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
	push BC
	push HL
	call GetTile ; A = tile
	ld C, A

	; look up flags
	rrca
	rrca ; A = A/4, safe as bottom 2 bits of A are 0
	add LOW(TileFlags)
	ld L, A
	ld H, HIGH(TileFlags)
	ld B, [HL]

	pop HL
	ld [HL], C ; set tile top-left
	inc L
	inc C
	inc C
	ld [HL], C ; set tile top-right
	dec C
	ld A, L
	add 31
	ld L, A ; HL = saved HL + 32. no carry because aligned for odd rows.
	ld [HL], C ; set tile bottom-left
	inc C
	inc C
	inc L
	ld [HL], C ; set tile bottom-right

	ld A, 1
	ld [CGBVRAMBank], A
	ld [HL], B ; set flags bottom-right
	dec L
	ld [HL], B ; set flags bottom-left
	ld A, L
	sub 31
	ld L, A
	ld [HL], B ; set flags top-right
	dec L
	ld [HL], B ; set flags top-left
	xor A
	ld [CGBVRAMBank], A

	LongAdd HL, 64, HL ; Long add because even rows may not be aligned (every 8th row overflows)
	ld A, H
	and %00000011 ; HL % 1024
	or $98 ; loop HL back to start of TileGrid
	ld H, A
	inc E
	pop BC
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
	push BC
	push HL
	call GetTile ; A = tile
	ld C, A

	; look up flags
	rrca
	rrca ; A = A/4, safe as bottom 2 bits of A are 0
	add LOW(TileFlags)
	ld L, A
	ld H, HIGH(TileFlags)
	ld B, [HL]

	pop HL
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

	ld A, 1
	ld [CGBVRAMBank], A
	ld [HL], B ; set flags bottom-right
	dec L
	ld [HL], B ; set flags bottom-left
	ld A, L
	sub 31
	ld L, A
	ld [HL], B ; set flags top-right
	dec L
	ld [HL], B ; set flags top-left
	xor A
	ld [CGBVRAMBank], A

	pop HL ; HL = start of target row again
	inc D

	pop BC
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


; Enqueue tile at (D,E) to be redrawn with value C
; Assumes ring will never fill!
; Clobbers A, HL
EnqueueTileRedraw::
	RingPushNoCheck TileRedrawQueue, 63, D
	RingPushNoCheck TileRedrawQueue, 63, E
	RingPushNoCheck TileRedrawQueue, 63, C
	ret
