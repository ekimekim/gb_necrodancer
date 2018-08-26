

; Implements a fibonacci LFSR. Gets initial seed from uninitialized memory.


SECTION "RNG State", WRAM0

RNGState:
	dw


SECTION "RNG Code", ROM0


; Init RNG based on initial state of $c000-$c200
; For best results, this should be done before other inits.
; Leaks initial value of A for additional "randomness"
; Clobbers A, HL
InitRNG::
	ld HL, $c000
.firstloop
	xor [HL]
	inc L
	jr nz, .firstloop
	ld [RNGState], A
.secondloop
	xor [HL]
	inc L
	jr nz, .secondloop
	and A ; set z if A == 0
	jr nz, .noadjust
	inc A ; prevent state being all-zeroes
.noadjust
	ld [RNGState+1], A
	ret


; Returns a random value in A.
; Clobbers C.
GetRNG::
	ld A, [RNGState] ; A[0] = state[0]
	ld C, A ; C[0] = state[0]
	rrc C ; C[0] = state[1]
	rrc C ; C[0] = state[2]
	xor C ; A[0] = state[0] ^ state[2]
	rrc C ; C[0] = state[3]
	xor C ; A[0] = state[0] ^ state[2] ^ state[3]
	rrc C ; C[0] = state[4]
	rrc C ; C[0] = state[5]
	xor C ; A[0] = state[0] ^ state[2] ^ state[3] ^ state[5] = new bit
	rra ; carry = new bit
	ld A, [RNGState+1]
	rra ; rotate new bit into top of RNGState, rotate bottom bit of this half into carry
	ld [RNGState+1], A
	ld A, [RNGState]
	rra ; rotate the bottom bit from top half into top of bottom half, shift rest down
	ld [RNGState], A
	; A == new bottom half of state, which is random
	ret
