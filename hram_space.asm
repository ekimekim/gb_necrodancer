
include "hram.asm"

; This is a dummy section just to mark the HRAM variables' space as used for the linker

SECTION "HRAM Variables", HRAM

PRINTV HRAM_SIZE
	ds HRAM_SIZE
