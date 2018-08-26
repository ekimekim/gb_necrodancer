IF !DEF(_G_HRAM)
_G_HRAM EQU "true"

RSSET $ff80

; Incremented on VBlank interrupt, set to 0 each frame.
; If ever > 1, indicates multiple vblanks per frame, ie. lag.
DetectLag rb 1

; Counts from 15 to 0 (1 per frame) tracking progress of taking a step,
; or 0 if no animation
AnimationTimer rb 1

; Counts frames that this beat will last, from beat-length down to 0
BeatTimer rb 1

; Counts beats since start of song
BeatCounter rb 2

; Flag that indicates whether the current beat has been run, so it can't run twice
BeatHasProcessed rb 1

; Number of frames per beat for this song, but minus 1 (eg. 0 means 1 frame, 59 means 60 frames)
BeatLength rb 1

; Either 0, 1 or -1 depending on direction of movement of current animation
MovingX rb 1
MovingY rb 1

; Player location within map. Is updated when animation moving to it *begins*.
PlayerX rb 1
PlayerY rb 1

; Player health, in half-hearts
PlayerHealth rb 1

; Flag, set to 1 on level end
HasWon rb 1

; Frames until next audio step
AudioTimer rb 1

; Pointer to next audio step, little-endian
AudioStep rb 2


HRAM_END rb 0
HRAM_SIZE EQU HRAM_END + (-$ff80)

ENDC
