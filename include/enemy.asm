IF !DEF(_G_ENEMY)
_G_ENEMY EQU "true"


ENEMY_LIST_SIZE EQU 32

RSRESET

; displayed enemy position =
;   if step == 0 then pos - moving * animation timer + bounce
;   else pos

enemy_pos_x rb 1 ; X position, 255 to indicate entire struct is invalid
enemy_pos_y rb 1 ; Y position
enemy_moving_x rb 1 ;
enemy_moving_y rb 1 ; direction enemy is moving
enemy_step rb 1 ; number of beats until enemy will move. 0 means moving this beat.
enemy_step_length rb 1 ; number that step is reset to if 0. eg. 1 means moves every beat.
enemy_sprite_flag rb 1 ; flag entry to display sprite with, most notably including palette
enemy_sprites rb 2 ; 2x sprite numbers, multiples of 4, indicating sprite to show for each step number
                   ; eg. skeletons have [hands down, hands up]
enemy_active rb 1 ; flag that indicates if enemy is active and moving yet
enemy_behaviour rw 1 ; little-endian pointer to behaviour handler for this enemy
ENEMY_SIZE rb 0

; Enemy prototypes are a copy of this struct with initial values.
; The following macro is used to more easily define them.
; Args are: step length, behaviour, initially active, sprite flag, sprites (2 args)
EnemyPrototype: MACRO
	db 0, 0 ; position
	db 0, 0 ; movement
	db \1, \1 ; step and step length
	db \4 ; sprite flag
	db \5, \6 ; sprites
	db \3 ; active
	dw \2 ; behaviour
ENDM

ENDC
