IF !DEF(_G_LEVEL)
_G_LEVEL SET "true"

RSRESET

level_map rw 1 ; pointer to map
level_enemy_count rw 1 ; pointer to length of enemy list
level_enemy_list rw 1 ; pointer to enemy list
level_start_x rb 1
level_start_y rb 1 ; start pos
level_beat_length rb 1 ; beat length
level_music rb 3 ; bank + pointer to music
_level_size rb 0
LEVEL_PAD_SIZE EQU 16 - _level_size
level_padding rb LEVEL_PAD_SIZE

; map, enemy count, enemy list, start x, start y, beat length, music
DefineLevel: MACRO
	dw \1, \2, \3
	db \4, \5, \6, BANK(\7)
	dw \7
	ds LEVEL_PAD_SIZE
ENDM

ENDC
