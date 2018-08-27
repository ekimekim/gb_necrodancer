IF !DEF(_G_FREQ)
_G_FREQ EQU "true"

; Steps are defined as (length in frames, ch1 freq, ch2 freq, ch3 freq)
; Length must be 1-255, freqs are a constant NOTE below or 0 for no note
Step: MACRO
	db \1
	StepPart \2
	StepPart \3
	StepPart \4
ENDM

StepPart: MACRO
IF \1 > 0
	dw \1 | $8000
ELSE
	dw 0
ENDC
ENDM

; Marks the end of a song. \1 should be start of the song in order to loop.
; Can also be used to jump in memory to continue song data elsewhere.
SongJump: MACRO
	db 0
	db BANK(\1)
	dw \1
ENDM


; Takes a 16.16-bit fixed point value as \1.
; Will set var RESULT to the frequency value needed for that frequency.
CalcFreq: MACRO
; Note we implicitly multiply by 8 by shifting 3 less, offsetting the smaller numerator.
; Note we round by adding 1/2 (actually 1/16 since we're working with 1/8 of actual value)
; We do this because rgbasm floats are 16.16 signed fixed point, so anything >= 2^15 overflows
RESULT SET 2048 - ((DIV(16384.0, (\1)) + 0.125) >> 13)
ENDM


; These define the standard note frequencies for the middle octave (ie. FREQ_C = C4 = Middle C).
; You can change the octave by shifting left or right, eg. FREQ_C << 2 = C6.
FREQ_A  SET 220.00
FREQ_As SET 233.08
FREQ_Bb SET FREQ_As
FREQ_B  SET 246.94
FREQ_Cb SET FREQ_B
FREQ_C  SET 261.63
FREQ_Bs SET FREQ_C
FREQ_Cs SET 277.18
FREQ_Db SET FREQ_Cs
FREQ_D  SET 293.66
FREQ_Ds SET 311.13
FREQ_Eb SET FREQ_Ds
FREQ_E  SET 329.63
FREQ_Fb SET FREQ_E
FREQ_F  SET 349.23
FREQ_Es SET FREQ_F
FREQ_Fs SET 369.99
FREQ_Gb SET FREQ_Fs
FREQ_G  SET 392.00
FREQ_Gs SET 415.30
FREQ_Ab SET FREQ_Gs >> 1


; We define register frequency settings for all notes as above, in octaves 1 to 7 (C4 is middle C)
	CalcFreq FREQ_Ab >> 3
NOTE_Ab0 SET RESULT
	CalcFreq FREQ_A >> 3
NOTE_A0 SET RESULT
	CalcFreq FREQ_As >> 3
NOTE_As0 SET RESULT
	CalcFreq FREQ_Bb >> 3
NOTE_Bb0 SET RESULT
	CalcFreq FREQ_B >> 3
NOTE_B0 SET RESULT
	CalcFreq FREQ_Cb >> 3
NOTE_Cb1 SET RESULT
	CalcFreq FREQ_C >> 3
NOTE_C1 SET RESULT
	CalcFreq FREQ_Bs >> 3
NOTE_Bs0 SET RESULT
	CalcFreq FREQ_Cs >> 3
NOTE_Cs1 SET RESULT
	CalcFreq FREQ_Db >> 3
NOTE_Db1 SET RESULT
	CalcFreq FREQ_D >> 3
NOTE_D1 SET RESULT
	CalcFreq FREQ_Ds >> 3
NOTE_Ds1 SET RESULT
	CalcFreq FREQ_Eb >> 3
NOTE_Eb1 SET RESULT
	CalcFreq FREQ_E >> 3
NOTE_E1 SET RESULT
	CalcFreq FREQ_Fb >> 3
NOTE_Fb1 SET RESULT
	CalcFreq FREQ_F >> 3
NOTE_F1 SET RESULT
	CalcFreq FREQ_Es >> 3
NOTE_Es1 SET RESULT
	CalcFreq FREQ_Fs >> 3
NOTE_Fs1 SET RESULT
	CalcFreq FREQ_Gb >> 3
NOTE_Gb1 SET RESULT
	CalcFreq FREQ_G >> 3
NOTE_G1 SET RESULT
	CalcFreq FREQ_Gs >> 3
NOTE_Gs1 SET RESULT
	CalcFreq FREQ_Ab >> 2
NOTE_Ab1 SET RESULT
	CalcFreq FREQ_A >> 2
NOTE_A1 SET RESULT
	CalcFreq FREQ_As >> 2
NOTE_As1 SET RESULT
	CalcFreq FREQ_Bb >> 2
NOTE_Bb1 SET RESULT
	CalcFreq FREQ_B >> 2
NOTE_B1 SET RESULT
	CalcFreq FREQ_Cb >> 2
NOTE_Cb2 SET RESULT
	CalcFreq FREQ_C >> 2
NOTE_C2 SET RESULT
	CalcFreq FREQ_Bs >> 2
NOTE_Bs1 SET RESULT
	CalcFreq FREQ_Cs >> 2
NOTE_Cs2 SET RESULT
	CalcFreq FREQ_Db >> 2
NOTE_Db2 SET RESULT
	CalcFreq FREQ_D >> 2
NOTE_D2 SET RESULT
	CalcFreq FREQ_Ds >> 2
NOTE_Ds2 SET RESULT
	CalcFreq FREQ_Eb >> 2
NOTE_Eb2 SET RESULT
	CalcFreq FREQ_E >> 2
NOTE_E2 SET RESULT
	CalcFreq FREQ_Fb >> 2
NOTE_Fb2 SET RESULT
	CalcFreq FREQ_F >> 2
NOTE_F2 SET RESULT
	CalcFreq FREQ_Es >> 2
NOTE_Es2 SET RESULT
	CalcFreq FREQ_Fs >> 2
NOTE_Fs2 SET RESULT
	CalcFreq FREQ_Gb >> 2
NOTE_Gb2 SET RESULT
	CalcFreq FREQ_G >> 2
NOTE_G2 SET RESULT
	CalcFreq FREQ_Gs >> 2
NOTE_Gs2 SET RESULT
	CalcFreq FREQ_Ab >> 1
NOTE_Ab2 SET RESULT
	CalcFreq FREQ_A >> 1
NOTE_A2 SET RESULT
	CalcFreq FREQ_As >> 1
NOTE_As2 SET RESULT
	CalcFreq FREQ_Bb >> 1
NOTE_Bb2 SET RESULT
	CalcFreq FREQ_B >> 1
NOTE_B2 SET RESULT
	CalcFreq FREQ_Cb >> 1
NOTE_Cb3 SET RESULT
	CalcFreq FREQ_C >> 1
NOTE_C3 SET RESULT
	CalcFreq FREQ_Bs >> 1
NOTE_Bs2 SET RESULT
	CalcFreq FREQ_Cs >> 1
NOTE_Cs3 SET RESULT
	CalcFreq FREQ_Db >> 1
NOTE_Db3 SET RESULT
	CalcFreq FREQ_D >> 1
NOTE_D3 SET RESULT
	CalcFreq FREQ_Ds >> 1
NOTE_Ds3 SET RESULT
	CalcFreq FREQ_Eb >> 1
NOTE_Eb3 SET RESULT
	CalcFreq FREQ_E >> 1
NOTE_E3 SET RESULT
	CalcFreq FREQ_Fb >> 1
NOTE_Fb3 SET RESULT
	CalcFreq FREQ_F >> 1
NOTE_F3 SET RESULT
	CalcFreq FREQ_Es >> 1
NOTE_Es3 SET RESULT
	CalcFreq FREQ_Fs >> 1
NOTE_Fs3 SET RESULT
	CalcFreq FREQ_Gb >> 1
NOTE_Gb3 SET RESULT
	CalcFreq FREQ_G >> 1
NOTE_G3 SET RESULT
	CalcFreq FREQ_Gs >> 1
NOTE_Gs3 SET RESULT
	CalcFreq FREQ_Ab
NOTE_Ab3 SET RESULT
	CalcFreq FREQ_A
NOTE_A3 SET RESULT
	CalcFreq FREQ_As
NOTE_As3 SET RESULT
	CalcFreq FREQ_Bb
NOTE_Bb3 SET RESULT
	CalcFreq FREQ_B
NOTE_B3 SET RESULT
	CalcFreq FREQ_Cb
NOTE_Cb4 SET RESULT
	CalcFreq FREQ_C
NOTE_C4 SET RESULT
	CalcFreq FREQ_Bs
NOTE_Bs3 SET RESULT
	CalcFreq FREQ_Cs
NOTE_Cs4 SET RESULT
	CalcFreq FREQ_Db
NOTE_Db4 SET RESULT
	CalcFreq FREQ_D
NOTE_D4 SET RESULT
	CalcFreq FREQ_Ds
NOTE_Ds4 SET RESULT
	CalcFreq FREQ_Eb
NOTE_Eb4 SET RESULT
	CalcFreq FREQ_E
NOTE_E4 SET RESULT
	CalcFreq FREQ_Fb
NOTE_Fb4 SET RESULT
	CalcFreq FREQ_F
NOTE_F4 SET RESULT
	CalcFreq FREQ_Es
NOTE_Es4 SET RESULT
	CalcFreq FREQ_Fs
NOTE_Fs4 SET RESULT
	CalcFreq FREQ_Gb
NOTE_Gb4 SET RESULT
	CalcFreq FREQ_G
NOTE_G4 SET RESULT
	CalcFreq FREQ_Gs
NOTE_Gs4 SET RESULT
	CalcFreq FREQ_Ab << 1
NOTE_Ab4 SET RESULT
	CalcFreq FREQ_A << 1
NOTE_A4 SET RESULT
	CalcFreq FREQ_As << 1
NOTE_As4 SET RESULT
	CalcFreq FREQ_Bb << 1
NOTE_Bb4 SET RESULT
	CalcFreq FREQ_B << 1
NOTE_B4 SET RESULT
	CalcFreq FREQ_Cb << 1
NOTE_Cb5 SET RESULT
	CalcFreq FREQ_C << 1
NOTE_C5 SET RESULT
	CalcFreq FREQ_Bs << 1
NOTE_Bs4 SET RESULT
	CalcFreq FREQ_Cs << 1
NOTE_Cs5 SET RESULT
	CalcFreq FREQ_Db << 1
NOTE_Db5 SET RESULT
	CalcFreq FREQ_D << 1
NOTE_D5 SET RESULT
	CalcFreq FREQ_Ds << 1
NOTE_Ds5 SET RESULT
	CalcFreq FREQ_Eb << 1
NOTE_Eb5 SET RESULT
	CalcFreq FREQ_E << 1
NOTE_E5 SET RESULT
	CalcFreq FREQ_Fb << 1
NOTE_Fb5 SET RESULT
	CalcFreq FREQ_F << 1
NOTE_F5 SET RESULT
	CalcFreq FREQ_Es << 1
NOTE_Es5 SET RESULT
	CalcFreq FREQ_Fs << 1
NOTE_Fs5 SET RESULT
	CalcFreq FREQ_Gb << 1
NOTE_Gb5 SET RESULT
	CalcFreq FREQ_G << 1
NOTE_G5 SET RESULT
	CalcFreq FREQ_Gs << 1
NOTE_Gs5 SET RESULT
	CalcFreq FREQ_Ab << 2
NOTE_Ab5 SET RESULT
	CalcFreq FREQ_A << 2
NOTE_A5 SET RESULT
	CalcFreq FREQ_As << 2
NOTE_As5 SET RESULT
	CalcFreq FREQ_Bb << 2
NOTE_Bb5 SET RESULT
	CalcFreq FREQ_B << 2
NOTE_B5 SET RESULT
	CalcFreq FREQ_Cb << 2
NOTE_Cb6 SET RESULT
	CalcFreq FREQ_C << 2
NOTE_C6 SET RESULT
	CalcFreq FREQ_Bs << 2
NOTE_Bs5 SET RESULT
	CalcFreq FREQ_Cs << 2
NOTE_Cs6 SET RESULT
	CalcFreq FREQ_Db << 2
NOTE_Db6 SET RESULT
	CalcFreq FREQ_D << 2
NOTE_D6 SET RESULT
	CalcFreq FREQ_Ds << 2
NOTE_Ds6 SET RESULT
	CalcFreq FREQ_Eb << 2
NOTE_Eb6 SET RESULT
	CalcFreq FREQ_E << 2
NOTE_E6 SET RESULT
	CalcFreq FREQ_Fb << 2
NOTE_Fb6 SET RESULT
	CalcFreq FREQ_F << 2
NOTE_F6 SET RESULT
	CalcFreq FREQ_Es << 2
NOTE_Es6 SET RESULT
	CalcFreq FREQ_Fs << 2
NOTE_Fs6 SET RESULT
	CalcFreq FREQ_Gb << 2
NOTE_Gb6 SET RESULT
	CalcFreq FREQ_G << 2
NOTE_G6 SET RESULT
	CalcFreq FREQ_Gs << 2
NOTE_Gs6 SET RESULT
	CalcFreq FREQ_Ab << 3
NOTE_Ab6 SET RESULT
	CalcFreq FREQ_A << 3
NOTE_A6 SET RESULT
	CalcFreq FREQ_As << 3
NOTE_As6 SET RESULT
	CalcFreq FREQ_Bb << 3
NOTE_Bb6 SET RESULT
	CalcFreq FREQ_B << 3
NOTE_B6 SET RESULT
	CalcFreq FREQ_Cb << 3
NOTE_Cb7 SET RESULT
	CalcFreq FREQ_C << 3
NOTE_C7 SET RESULT
	CalcFreq FREQ_Bs << 3
NOTE_Bs6 SET RESULT
	CalcFreq FREQ_Cs << 3
NOTE_Cs7 SET RESULT
	CalcFreq FREQ_Db << 3
NOTE_Db7 SET RESULT
	CalcFreq FREQ_D << 3
NOTE_D7 SET RESULT
	CalcFreq FREQ_Ds << 3
NOTE_Ds7 SET RESULT
	CalcFreq FREQ_Eb << 3
NOTE_Eb7 SET RESULT
	CalcFreq FREQ_E << 3
NOTE_E7 SET RESULT
	CalcFreq FREQ_Fb << 3
NOTE_Fb7 SET RESULT
	CalcFreq FREQ_F << 3
NOTE_F7 SET RESULT
	CalcFreq FREQ_Es << 3
NOTE_Es7 SET RESULT
	CalcFreq FREQ_Fs << 3
NOTE_Fs7 SET RESULT
	CalcFreq FREQ_Gb << 3
NOTE_Gb7 SET RESULT
	CalcFreq FREQ_G << 3
NOTE_G7 SET RESULT
	CalcFreq FREQ_Gs << 3
NOTE_Gs7 SET RESULT

ENDC

PRINTV NOTE_C4
PRINTV NOTE_E4
