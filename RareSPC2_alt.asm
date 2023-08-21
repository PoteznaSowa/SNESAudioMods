; Modified Rare's Donkey Kong Country 2 and 3 sound engine.
; Based on Donkey Kong Country 2 and 3 sound engine disassembly.
; Author: PoteznaSowa.

; Some changes included in the mod:
; - optimised code, unused features removed, data transfer sped up;
; - added preprocessing of sound sequence data in background;
; - music runs at variable SPC timer period instead of
;   using a single fixed-period timer in the original design;
; - removed mixing-out stereo

hirom

	ORG	0
_S0:	skip 1	; scratch RAM for intermediate data
_S1:	skip 1
_S2:	skip 1
_S3:	skip 1
_S4:	skip 1

; 0: engine is running
; 1: halve BGM tempo
; 2: if bit 1 is set, skip BGM updates
; 3: events are being preprocessed
GlobalFlags:	skip 1

CurrentTrack:	skip 1
VarNote0:	skip 8	; $C	; variable note 0, used by BGM only
VarNote1:	skip 8	; $14	; variable note 1, used by BGM only
SndEnable:	skip 1	; $1C	; if cleared, the engine won't play music
BGMTempo:	skip 1	; $1F	; current BGM tempo, added to division buffer
Timer0Ticks:	skip 1
Timer1Ticks:	skip 1

Duration_High:	skip 16	; $24	; 16-bit duration
Duration_Low:	skip 16	; $34
TrkPointer_LSB:	skip 16	; $44	; track pointer
TrkPointer_MSB:	skip 16	; $54
SndFineTune:	skip 16	; $64	; pitch tuning
Pitch_High:	skip 16	; $74	; current pitch, used for pitch bend
Pitch_Low:	skip 16	; $84
t_PitchSlideSteps:	skip 16	; $94	; pitch slide steps left
t_VibSteps:	skip 16	; $A4	; vibrato cycle steps left
t_VibInterval:	skip 16	; $B4	; vibrato interval timeout
t_VibDelay:	skip 16	; $C4	; vibrato delay timeout
SndStackPtr:	skip 16	; $D4	; current stack pointer

MusicPointer:	skip 2	; $E5	; BGM data pointer
GuardByte:	skip 1	; $E9	; Next message number
;DataSize:	skip 2	; $EA
SndNewPitchOffset:	skip 2	; $EC	; New pitch offset for SFX channel #5
SndPitchOffset:	skip 2	; $EE		; Current pitch offset for SFX channel #5
EchoBufferLoc:	skip 1	; location of the echo buffer
KeyOnShadow:	skip 1	; key-on bitmask
MsgBuffer:	skip 1	; 2nd message argument buffer
SFXCount:	skip 1
CurPreprocTrack:	skip 1	; number of channel to be preprocessed

	ORG	$F1
ControlReg:	skip 1	; $F1	; S-SMP Control register used to enable/disable timers
DSPAddr:	skip 1	; $F2	; S-DSP address register
DSPData:	skip 1	; $F3	; S-DSP	data register
Port0:		skip 1	; $F4	; I/O ports. Port 0 stores the message number.
Port1:		skip 1	; $F5	; 1st argument of message.
Port2:		skip 1	; $F6	; 2nd argument of message.
Port3:		skip 1	; $F7	; Unused in Donkey Kong Country 2 and 3.
UnusedIO0:	skip 1	; $F8	; Normal RAM.
UnusedIO1:	skip 1	; $F9	; Normal RAM.
Timer0:		skip 1	; $FA	; Write here BGM timer interval in units of .125 ms.
Timer1:		skip 1	; $FB	; Set at 100*.125=12.5 ms. Used for SFX.
Timer2:		skip 1	; $FC	; Unused.
Timer0_out:	skip 1	; $FD	; Number of timer 0 ticks.
Timer1_out:	skip 1	; $FE	; Number of timer 1 ticks.
Timer2_out:	skip 1	; $FF	; Number of timer 2 ticks.

t_PitchSlideInterval:	skip 16	; $100	; pitch slide interval timeout
SndActive:		skip 16	; $110	; flag to allow channel activity
DfltDuration_Low:	skip 16	; $120	; current default duration
DfltDuration_High:	skip 16	; $130
Transpose:		skip 16	; $140	; signed pitch offset in semitones

; 0: portamento on
; 1: vibrato on
; 5: enable noise
; 6: already ready for key-on
; 7: track audible (no rest)
EffectFlags:		skip 16	; $150	; channel flags

PitchSlideDelay:	skip 16	; $160	; stored pitch slide delay
PitchSlideInterval:	skip 16	; $170	; stored pitch slide interval (time between steps)
PitchSlideSteps:	skip 16	; $180	; stored total pitch slide steps
PitchSlideStepsDown:	skip 16	; $190	; stored pitch slide steps in opposite direction
t_PitchSlideDelay:	skip 16	; $1A0	; pitch slide delay timeout
PitchSlideDelta:	skip 16	; $1B0	; pitch slide pitch delta (linear, signed)
t_PitchSlideStepsDown:	skip 16	; $1C0	; pitch slide down steps left
SndLongDuration:	skip 16	; $1D0	; if flag is set, long (16-bit) duration will be used

	ORG	$1F0
SFXOverride:		skip 16	; $1E0	; if flag is set, BGM won't touch S-DSP when in use by SFX

EchoSample:	skip 4
SndEnvLvl:	skip 16	; current ADSR envelope level
VibLen:		skip 16	; $200	; steps per vibrato cycle
VibInterval:	skip 16	; $210	; stored vibrato interval (time between steps) 
VibratoDelay:	skip 16	; $220	; stored vibrato delay
VibratoDepth:	skip 16	; $234	; vibrato pitch delta (linear, signed)

; S-DSP sound parameters
SndSRCN:	skip 16	; $244	; source number
SndVolume_L:	skip 16	; $254	; left channel volume
SndVolume_R:	skip 16	; $264	; right channel volume
SndADSR1:	skip 16	; $274	; ADSR 1 value
SndADSR2:	skip 16	; $284	; ADSR 2 value
SndEchoFlag:	skip 16	; $294	; if flag is set, echo will be enabled

; subroutine stack. The maximum nest level is 8.
Stack_PtrL:	skip 128 ; $334
Stack_PtrH:	skip 128 ; $3B4
Stack_RepCnt:	skip 128 ; $434	; stack repeat count

;NoiseFreq:	skip 1 ; $4B4
BGMVol:		skip 1 ; $4B6	; current BGM volume
VolPreset1_L:	skip 1 ; $4B8
VolPreset1_R:	skip 1 ; $4B9
VolPreset2_L:	skip 1 ; $4BA
VolPreset2_R:	skip 1 ; $4BB

; DSP register addresses
DSP_Vol =	0
DSP_VolL =	0
DSP_VolR =	1

DSP_Pitch =	2
DSP_PitchL =	2
DSP_PitchH =	3

DSP_Voice =	4

DSP_ADSR =	5
DSP_ADSR1 =	5
DSP_ADSR2 =	6
DSP_Gain =	7

DSP_EnvLevel =	8
DSP_OutX =	9

DSP_MasterL =	$0C
DSP_MasterR =	$1C
DSP_EchoL =	$2C
DSP_EchoR =	$3C
DSP_KeyOn =	$4C
DSP_KeyOff =	$5C
DSP_Flags =	$6C
DSP_EndX =	$7C
DSP_Feedback =	$0D
DSP_PitchMod =	$2D
DSP_NoiseOn =	$3D
DSP_EchoOn =	$4D
DSP_VoiceDir =	$5D
DSP_EchoLoc =	$6D
DSP_EchoDelay =	$7D
DSP_FIR =	$0F

; locations of external data
MusicData =	$1400
MusicIndex =	$1312
SFX_IndexBound0 =	$2410
SFX_IndexBound1 =	$2E94
SFX_PtrTable0 =	$2412
SFX_PtrTable1 =	$2E96


	arch spc700
	optimize dp always

	ORG	$EE0000	; set to $ED0000 for Donkey Kong Country 3
	base	$4D8
EntryPoint:
	mov	X, #0
	mov	Port0, X
	mov	DSPAddr, #$7D	; Echo delay
	mov	DSPData, X
	inc	X
	mov	GuardByte, X
	MOV	Timer0, X
	MOV	Timer1, #100
	mov	ControlReg, #3

TransferMode:
	; reset echo buffer settings
	mov	DSPAddr, #$6D	; Echo buffer location
	mov	DSPData, #EchoSample>>8
	mov	EchoBufferLoc, #EchoSample>>8
	mov	X, GuardByte
GetNextBlock:
	cmp	X, Port0
	bne	GetNextBlock
	movw	YA, Port1	; get write address
	mov	Port0, X
	inc	X
	MOVW	2, YA

-	cmp	X, Port0
	bne	-
	movw	YA, Port1	; get block size in words
	mov	Port0, X
	inc	X
	movw	0, YA
	decw	0
	bmi	loc_556

	ADDW	YA, 0
	INC	Y
	EOR	A, #$FF
	MOVW	0, YA
	MOV	Y, A
	MOV	A, 2
	SETC
	SBC	A, 0
	mov	loc_538+1, A
	mov	loc_541+1, A
	MOV	A, 3
	SBC	A, #0
	mov	loc_538+2, A
	mov	loc_541+2, A
loc_532:
	cmp	X, Port0
	bne	loc_532
	mov	A, Port1
loc_538:
	mov.W	0+Y, A
	mov	A, Port2
	mov	Port0, X
	inc	X
	inc	Y
loc_541:
	mov.W	0+Y, A
	inc	Y
	bne	loc_532
	inc	(loc_538)+2	; add $100 to write address
	inc	(loc_541)+2
	DBNZ	1, loc_532
	jmp	GetNextBlock
;-----------------------------------------------------------------------------
loc_556:
	mov	GuardByte, X	; store guard byte
	mov	X, #0		; clear index
	jmp	(2+X)	; jump to the given address
;-----------------------------------------------------------------------------
; ==============================================================================
; This engine uses "word stream" to get data from SNES.
; For example, to write $12 $34 $56 $78 into $2442
; and $9A $BC $DE $F0 into $432,
; SNES sends several blocks below (note that addresses are given
; in little-endian):
; $2442 $0002 $1234 $5678
; $3204 $0002 $9ABC $DEF0
; Then, when all data is sent, SNES returns APU into sound engine
; and sends a command to begin music:
; $7206 $0000 $00FE $00FA
; Each time a word of data is sent, SNES increments word counter at Port 0.
; See GetMessage for more information
; ==============================================================================
	base off
	ORG	$EE0088	; set to $ED0000 for Donkey Kong Country 3
	base	$560
; ==============================================================================
TimbreLUT:
	dw	0, 0, 0, 0, 0, 0, 0, 0	; The table stores SRCNs
	dw	0, 0, 0, 0, 0, 0, 0, 0	; for up to 256 samples.
	dw	0, 0, 0, 0, 0, 0, 0, 0	; It's created by SNES
	dw	0, 0, 0, 0, 0, 0, 0, 0	; during data transfer.
	dw	0, 0, 0, 0, 0, 0, 0, 0
	dw	0, 0, 0, 0, 0, 0, 0, 0
	dw	0, 0, 0, 0, 0, 0, 0, 0
	dw	0, 0, 0, 0, 0, 0, 0, 0
	dw	0, 0, 0, 0, 0, 0, 0, 0
	dw	0, 0, 0, 0, 0, 0, 0, 0
	dw	0, 0, 0, 0, 0, 0, 0, 0
	dw	0, 0, 0, 0, 0, 0, 0, 0
	dw	0, 0, 0, 0, 0, 0, 0, 0
	dw	0, 0, 0, 0, 0, 0, 0, 0
	dw	0, 0, 0, 0, 0, 0, 0, 0
	dw	0, 0, 0, 0, 0, 0, 0, 0
; ==============================================================================
SetIndexedBGM:
	; this engine can play additional music without
	; entering transfer routine
	mov.W	A, MsgBuffer
	asl	A
	mov	Y, A
	mov	A, MusicIndex+Y
	mov	MusicPointer, A
	mov	A, MusicIndex+1+Y
	mov	MusicPointer+1, A
	jmp	EngineStart
; ==============================================================================
SetFixedBGM:
	; this is an entry point of the engine
	mov	MusicPointer+1, #$13
	mov	MusicPointer, #0
EngineStart:
	call	SetUpEngine	; set up S-DSP and music

GetMessage:
; Check if there's an incoming message from SNES, and process it.
; To play composite SFX (which is played at more than one channel), SNES
; sends more than single message.
	mov	A, GuardByte
	cbne	Port0, MainLoop
	mov	X, Port2		; get command argument
	mov	MsgBuffer, X	; store it
	mov	X, Port1		; get command ID
	mov	Port0, A		; reply to SNES
	inc	A		; increment message counter
	mov	GuardByte, A	; store it
	mov	A, X
	bmi	+		; if not, branch

	mov	X, MsgBuffer
	call	SetUpSFX	; set up SFX
	JMP	GetMessage
; ==============================================================================
+	and	A, #7		; clear unwanted bits
	asl	A
	mov	X, A
	jmp	(Command_Index+X)	; process the command
; ==============================================================================
Command_Index:
	dw	CommandF8, CommandF9		; $F8, $F9
	dw	SetStereo, SetIndexedBGM	; $FA, $FB
	dw	CommandFC, CommandFD		; $FC, $FD
	dw	PlayBGM, GotoTransferMode	; $FE, $FF
; ==============================================================================
CommandF8:
CommandF9:
SetStereo:
	jmp	GetMessage
; ==============================================================================
CommandFD:
	; change volume modifier for SFX at channel #5
	; Volume = Volume * Modifier / 100
	mov	Y, MsgBuffer
	mov	DSPAddr, #$50
	mov	A, DSPData
	call	ApplyVolMod2
	mov	DSPData, A
	inc	DSPAddr
	mov	Y, MsgBuffer
	mov	A, DSPData
	call	ApplyVolMod2
	mov	DSPData, A
	JMP	GetMessage
; ==============================================================================
CommandFC:
	; change pitch modifier for SFX at channel #5
	mov	A, MsgBuffer
	bmi	+
	mov	SndNewPitchOffset+1, #0
	JMP	++

+	mov	SndNewPitchOffset+1, #-1
++	ASL	A
	ROL	SndNewPitchOffset+1
	ASL	A
	ROL	SndNewPitchOffset+1
	ASL	A
	ROL	SndNewPitchOffset+1
	MOV	SndNewPitchOffset, A

	mov	DSPAddr, #$4D
	CLR5	DSPData
	mov	A, #0
	mov	SndEchoFlag+8+5, A
	JMP	GetMessage
; ==============================================================================
PlayBGM:
	SET0	GlobalFlags
	MOVW	YA, Timer0_out
	JMP	GetMessage
; ==============================================================================
MainLoop:
	BBC0	GlobalFlags, GetMessage

	CLR3	GlobalFlags	; clear the preprocess flag

	CLRC
	ADC	Timer0Ticks, Timer0_out
	BEQ	SkipBGMUpdate
	DEC	Timer0Ticks

	EOR	GlobalFlags, #4
	MOV	CurrentTrack, #0

UpdateBGM:
	CALL	UpdateTrack
	INC	CurrentTrack	; increment channel index
	CMP	CurrentTrack, #8
	BCC	UpdateBGM
	CALL	WriteKeyOn

SkipBGMUpdate:
	CLRC
	ADC	Timer1Ticks, Timer1_out
	BEQ	PreprocessTracks
	DEC	Timer1Ticks

	MOV	SFXCount, #0
	MOV	CurrentTrack, #8

UpdateSFX:
	MOV	X, CurrentTrack
	MOV	A, SFXOverride-8+X
	BEQ	+
	CALL	UpdateTrack
+	INC	CurrentTrack
	CMP	CurrentTrack, #16
	BCC	UpdateSFX
	CALL	WriteKeyOn

	MOV	CurrentTrack, #0

UpdateTracks2:
	MOV	X, CurrentTrack
	MOV	A, SFXOverride+X	; is the channel used by SFX?
	BEQ	+		; branch if no
	OR	CurrentTrack, #8
+	CALL	UpdateTrack_2
	AND	CurrentTrack, #7
	INC	CurrentTrack
	CMP	CurrentTrack, #8
	BCC	UpdateTracks2

PreprocessTracks:
	; If we have finished all pending tasks above,
	; try to preprocess sound data for each channel
	; in a round-robin manner.
	CMP	GuardByte, Port0	; has SNES sent next message?
	BEQ	Goto_GetMessage		; branch if yes

	CLRC
	ADC	Timer0Ticks, Timer0_out
	BNE	Goto_GetMessage
	CLRC
	ADC	Timer1Ticks, Timer1_out
	BNE	Goto_GetMessage

	; Increment the preprocess index.
	; Notice that it is never initialised anywhere,
	; as we do not need this.
	INC	CurPreprocTrack
	AND	CurPreprocTrack, #15
	MOV	X, CurPreprocTrack

	MOV	A, SndActive+X	; is the channel active?
	BEQ	Goto_GetMessage	; branch if no

	MOV	A, X
	AND	A, #7
	XCN	A
	OR	A, #8
	MOV	DSPAddr, A
	MOV	A, DSPData
	CMP	A, SndEnvLvl+X
	MOV	SndEnvLvl+X, A
	BCS	+
	OR	A, #0
	BNE	+
	MOV	A, EffectFlags+X
	AND	A, #$7F			; clear the "channel audible" flag
	MOV	EffectFlags+X, A

+	MOV	CurrentTrack, X
	MOV	A, TrkPointer_LSB+X	; load the track pointer
	MOV	Y, TrkPointer_MSB+X
	MOVW	0, YA
	MOV	Y, #0
	MOV	A, (0)+Y		; read the next track byte
	BMI	Preproc_RestOrNote	; branch if this is a note or rest
	MOV	X, A
	MOV	A, EventTypeTable+X	; check the type of the voice command
	BMI	+			; branch if it can be run without no trouble
	BEQ	Goto_GetMessage		; branch if it must not be run in preprocess
	MOV	X, CurrentTrack
	MOV	A, EffectFlags+X	; is the channel audible now?
	BMI	Goto_GetMessage		; branch if yes

+	SET3	GlobalFlags
	MOV	A, (0)+Y	; read the track byte again
	INC	Y		; proceed to the next track byte
	ASL	A
	MOV	X, A
	JMP	(CtrlEventIndex+X)	; run the voice command
;-----------------------------------------------------------------------------
Goto_GetMessage:
	JMP	GetMessage
;-----------------------------------------------------------------------------
Preproc_RestOrNote:
	CMP	A, #$80
	BEQ	Preproc_Rest

	PUSH	A
	MOV	A, SFXOverride+X
	POP	A
	BNE	Goto_GetMessage

	PUSH	A
	MOV	A, EffectFlags+X	; effects
	AND	A, #$C0
	POP	A
	BNE	Goto_GetMessage

	PUSH	A
	MOV	A, SndEnvLvl+X
	POP	A
	BNE	Goto_GetMessage

	CALL	PrepareNote
	MOV	A, EffectFlags+X	; effects
	OR	A, #$40
	MOV	EffectFlags+X, A
	JMP	GetMessage
;-----------------------------------------------------------------------------
Preproc_Rest:
	MOV	A, EffectFlags+X	; effects
	AND	A, #$C0
	BNE	Goto_GetMessage
	INC	Y	; proceed to the next track byte

	CLRC
	MOV	A, DfltDuration_Low+X	; is default note duration set?
	BEQ	+		; branch if not
	MOV	2, A	; set duration LSB
	MOV	A, DfltDuration_High+X
	MOV	3, A	; set duration MSB
	JMP	++

+	MOV	A, SndLongDuration+X	; is 16-bit note duration mode on?
	MOV	3, A
	BEQ	+		; branch if not
	MOV	A, (0)+Y	; get duration MSB
	MOV	3, A
	INC	Y
+	MOV	A, (0)+Y	; get duration LSB
	MOV	2, A
	INC	Y
++	MOV	4, Y
	MOV	A, Duration_Low+X
	MOV	Y, Duration_High+X
	ADDW	YA, 2
	BCS	Goto_GetMessage
	MOV	Duration_Low+X, A
	MOV	Duration_High+X, Y
	MOV	A, 4
	MOV	Y, #0
	ADDW	YA, 0
	MOV	TrkPointer_LSB+X, A	; store pointer LSB
	MOV	TrkPointer_MSB+X, Y	; store pointer MSB
	JMP	GetMessage
; ==============================================================================
WriteKeyOn:
	MOV	A, KeyOnShadow
	BEQ	+
	MOV	DSPAddr, #$5C
	TCLR	DSPData, A
	MOV	DSPAddr, #$4C
	MOV	DSPData, A
	MOV	Y, #26
-	DBNZ	Y, -	; short delay as a workaround for buggy SNES emulators
	MOV	KeyOnShadow, Y
+	RET
; ==============================================================================
GotoTransferMode:
	mov	DSPAddr, #$5C	; Key-off
	mov	DSPData, #-1	; release all notes
	mov	X, #0
	mov	DSPAddr, #$7D	; echo delay
	mov	DSPData, X
	mov	DSPAddr, #$D	; Echo feedback
	mov	DSPData, X
	mov	DSPAddr, #$4D	; Echo enable
	mov	DSPData, X
	CALL	WaitForEcho
	CALL	WaitForEcho
	jmp	TransferMode	; enter transfer mode
; ==============================================================================
SoftKeyRelease:
	MOV	A, SFXOverride+X
	BNE	+
SoftKeyRelease2:
	MOV	A, X
	AND	A, #7
	XCN	A
	OR	A, #7
	MOV	DSPAddr, A
	MOV	DSPData, #$BF
	SETC
	SBC	DSPAddr, #2
	CLR7	DSPData
+	RET
; ==============================================================================
HardKeyRelease:
	MOV	A, X
	AND	A, #7
	XCN	A
	OR	A, #7
	MOV	DSPAddr, A
	MOV	DSPData, #$9F
	SETC
	SBC	DSPAddr, #2
	CLR7	DSPData
	RET
; ==============================================================================
UpdateTrack:
	MOV	X, CurrentTrack

	mov	A, SndActive+X	; is the channel active?
	beq	+		; if yes, branch

	MOV	A, Duration_Low+X
	MOV	Y, Duration_High+X

	CMP	X, #8
	BCS	.decDur
	BBC1	GlobalFlags, .decDur
	BBC2	GlobalFlags, .checkDur

.decDur:
	MOVW	0, YA
	MOVW	YA, 0
	BEQ	FetchNextEvent
	DECW	0
	BEQ	FetchNextEvent
	MOVW	YA, 0
	MOV	Duration_Low+X, A
	MOV	Duration_High+X, Y

	CMP	X, #8
	BCS	.checkDur
	BBC1	GlobalFlags, .checkDur
	BBS2	GlobalFlags, +

.checkDur:
	CMP	A, #1
	BNE	+
	MOV	A, Y
	BNE	+
	MOV	A, EffectFlags+X	; effects
	AND	A, #$40
	BEQ	SoftKeyRelease
+	RET
; ==============================================================================
FetchNextEvent:
	mov	A, TrkPointer_LSB+X
	mov	Y, TrkPointer_MSB+X
	movw	0, YA
	mov	Y, #0
FetchNextEvent2:
	mov	A, (0)+Y
	bmi	GotNote
	INC	Y
	ASL	A
	MOV	X, A
	jmp	(CtrlEventIndex+X)
; ==============================================================================
IncAndFinishEvent:
	INC	Y
FinishEvent:
	BBC3	GlobalFlags, FetchNextEvent2
	MOV	X, CurrentTrack
	MOV	A, Y
	MOV	Y, #0
	ADDW	YA, 0
	MOV	TrkPointer_LSB+X, A	; store pointer LSB
	MOV	TrkPointer_MSB+X, Y	; store pointer MSB
	JMP	GetMessage
; ==============================================================================
ProcessRest:
	CALL	SoftKeyRelease2
Goto_SetDuration:
	MOV	A, EffectFlags+X	; effects
	AND	A, #$3F
	MOV	EffectFlags+X, A
	JMP	SetDuration
; ==============================================================================
GotNote:
	INC	Y

	PUSH	A
	MOV	X, CurrentTrack
	MOV	A, SFXOverride+X	; is the channel used by SFX?
	POP	A
	BNE	Goto_SetDuration
	CMP	A, #$80			; is the event a rest?
	BEQ	ProcessRest		; if yes, branch

	PUSH	A
	MOV	A, EffectFlags+X	; effects
	AND	A, #$40
	POP	A
	BNE	+
	PUSH	Y
	CALL	PrepareNote
	POP	Y
+	MOV	A, VoiceBitMask+X
	TSET	KeyOnShadow, A
	MOV	A, EffectFlags+X	; effects
	AND	A, #$3F
	OR	A, #$80
	MOV	EffectFlags+X, A
	MOV	A, #0
	MOV	SndEnvLvl+X, A

SetDuration:
	MOV	A, DfltDuration_Low+X	; is default note duration set?
	BEQ	+		; branch if not
	MOV	Duration_Low+X, A	; set duration LSB
	MOV	A, DfltDuration_High+X
	MOV	Duration_High+X, A	; set duration MSB
	JMP	++

+	MOV	A, SndLongDuration+X	; is 16-bit note duration mode on?
	BEQ	+		; branch if not
	MOV	A, (0)+Y	; get duration MSB
	MOV	Duration_High+X, A
	INC	Y
+	MOV	A, (0)+Y	; get duration LSB
	MOV	Duration_Low+X, A
	INC	Y

++	MOV	A, Y
	MOV	Y, #0
	ADDW	YA, 0
	MOV	TrkPointer_LSB+X, A	; store pointer LSB
	MOV	TrkPointer_MSB+X, Y	; store pointer MSB
	RET
; ==============================================================================
PrepareNote:
	mov	DSPAddr, #$5C	; Key-off
	PUSH	A
	mov	A, VoiceBitMask+X
	mov	DSPData, A
	POP	A

	cmp	A, #$E0	; variable note 0
	bmi	++
	cmp	A, #$E1	; variable note 1
	beq	+
	mov	A, VarNote0+X
	JMP	++

+	mov	A, VarNote1+X
++	clrc
	adc	A, #$24
	adc	A, Transpose+X
	asl	A

	; fine-tune given pitch with current fine-tune value
	; with following formula:
	; P=P*(1024+T)/1024, where T is fine-tune offset
	mov	Y, SndFineTune+X	; is fine-tune value zero?
	beq	SkipTuning	; if yes, branch
	mov	X, A
	mov	4, Y
	mov	A, Y
	bpl	+	; get an absolute value of fine-tune value
	eor	A, #-1
	inc	A

+	mov	Y, A	; set a multiplier
	push	Y
	mov	A, PitchTable+X ; read LSB of base pitch value
	mul	YA	; multiple it with fine-tune value
	mov	2, Y	; store MSB of the result as LSB of pitch offset
	mov	3, #0	; clear MSB of pitch offset
	pop	Y	; get fine-tune multiplier again
	mov	A, PitchTable+1+X ; read MSB of base pitch value
	mul	YA	; multiple it with fine-tune value
	addw	YA, 2	; add pitch offset to the result
	mov	3, Y	; store MSB of the result as MSB of the variable

	lsr	3	; divide the result by 4
	ror	A
	lsr	3
	ror	A
	mov	2, A	; store LSB of the result as LSB of pitch offset
	mov	A, PitchTable+1+X ; read LSB of seed pitch value
	mov	Y, A	
	mov	A, PitchTable+X ; read MSB of seed pitch value
	mov	X, 4	; is a fine-tune value negative?
	bmi	+	; if no, branch
	addw	YA, 2	; add given pitch offset to seed pitch
	JMP	++
+
	subw	YA, 2	; subtract given pitch offset from seed pitch
++	movw	2, YA	; store it
	JMP	TuningDone
SkipTuning:
	; simply get the pitch value from the table
	mov	X, A
	mov	A, PitchTable+X
	mov	2, A
	mov	A, PitchTable+1+X
	mov	3, A
TuningDone:
	MOV	A, CurrentTrack
	MOV	X, A
	AND	A, #7
	XCN	A
	MOV	DSPAddr, A

	; write current sound parameters into DSP
	mov	A, SndVolume_L+X
	call	ApplyVolMod
	mov	DSPData, A	; Left channel level
	inc	DSPAddr
	mov	A, SndVolume_R+X
	call	ApplyVolMod
	mov	DSPData, A	; Right channel level
	inc	DSPAddr

	; set up initial pitch slide parameters
	mov	A, EffectFlags+X	; read bit array
	and	A, #1		; is pitch slide enabled?
	beq	+		; if not, branch
	mov	A, PitchSlideDelay+X	; delay
	mov	t_PitchSlideDelay+X, A
	mov	A, PitchSlideInterval+X	; interval
	mov	t_PitchSlideInterval+X, A
	mov	A, PitchSlideSteps+X	; total up/down steps
	mov	t_PitchSlideSteps+X, A
	mov	A, PitchSlideStepsDown+X	; steps of going down
	mov	t_PitchSlideStepsDown+X, A
+
	; set up initial vibrato parameters
	mov	A, EffectFlags+X	; read bit array
	and	A, #2		; is vibrato enabled?
	beq	++		; if not, branch
	mov	A, VibratoDepth+X	; pitch delta
	bpl	+
	eor	A, #-1
	inc	A
	mov	VibratoDepth+X, A
+
	mov	A, VibLen+X	; cycle length
	lsr	A	; divide it by 2
	mov	t_VibSteps+X, A
	mov	A, VibInterval+X	; interval
	mov	t_VibInterval+X, A
	mov	A, VibratoDelay+X	; delay
	mov	t_VibDelay+X, A
++
	mov	A, 2
	mov	Pitch_Low+X, A
	mov	DSPData, A	; LSB of pitch value
	inc	DSPAddr
	mov	A, 3
	mov	Pitch_High+X, A
	mov	DSPData, A	; MSB of pitch value
	inc	DSPAddr
	mov	A, SndSRCN+X
	mov	DSPData, A	; Source number
	inc	DSPAddr
	mov	A, SndADSR1+X
	mov	DSPData, A	; ADSR 1
	inc	DSPAddr
	mov	A, SndADSR2+X
	mov	DSPData, A	; ADSR 2
	inc	DSPAddr
	mov	DSPData, #127	; GAIN value if ADSR is disabled

	MOV	DSPAddr, #$4D
	MOV	A, SndEchoFlag+X
	BEQ	+
	MOV	A, VoiceBitMask+X
	TSET	DSPData, A
	JMP	++
;-----------------------------------------------------------------------------
+	MOV	A, VoiceBitMask+X
	TCLR	DSPData, A

++	mov	DSPAddr, #$3D
	MOV	A, EffectFlags+X
	AND	A, #$20
	BEQ	+
	MOV	A, VoiceBitMask+X
	TSET	DSPData, A
	RET
;-----------------------------------------------------------------------------
+	MOV	A, VoiceBitMask+X
	TCLR	DSPData, A
	RET
; ==============================================================================
AddAndClipPitch:
	ADDW	YA, 0
	BMI	++
	CMP	Y, #$40
	BCC	+
	MOV	Y, #$3F
	MOV	A, #$FF
+	MOV	Pitch_High+X, Y
	MOV	Pitch_Low+X, A
	RET

++	MOV	A, #0
	MOV	Y, A
	MOV	Pitch_High+X, A
	MOV	Pitch_Low+X, A
	RET
; ==============================================================================
UpdateTrack_2:
	MOV	X, CurrentTrack
	MOV	A, EffectFlags+X
	BMI	+
	RET

+	and	A, #1	; is portamento enabled?
	beq	loc_A39	; if no, branch
	mov	A, t_PitchSlideDelay+X
	beq	loc_9DA
	cmp	A, #-1
	beq	loc_A39
	dec	A
	mov	t_PitchSlideDelay+X, A
	bne	loc_A39
	mov	A, #1
	mov	t_PitchSlideInterval+X, A
loc_9DA:
	mov	A, t_PitchSlideInterval+X
	dec	A
	mov	t_PitchSlideInterval+X, A
	bne	loc_A39
	mov	A, PitchSlideInterval+X
	mov	t_PitchSlideInterval+X, A
	mov	A, t_PitchSlideStepsDown+X
	beq	loc_A10
	dec	A
	mov	t_PitchSlideStepsDown+X, A
	mov	A, PitchSlideDelta+X	; get pitch offset
	eor	A, #-1		; negate it
	inc	A
	mov	0, A		; store it
	bpl	loc_A00		; sign-extend it
	mov	A, #-1
	JMP	loc_A02
loc_A00:
	mov	A, #0
loc_A02:
	mov	1, A
	mov	A, Pitch_Low+X
	mov	Y, Pitch_High+X
	CALL	AddAndClipPitch
	JMP	loc_A1B
loc_A10:
	mov	A, PitchSlideDelta+X
	mov	0, A
	bpl	loc_A00
	mov	A, #-1
	JMP	loc_A02
loc_A1B:
	mov	A, X
	and	A, #7
	xcn	A
	or	A, #2
	mov	DSPAddr, A	; LSB of pitch value
	mov	A, Pitch_Low+X
	mov	DSPData, A
	inc	DSPAddr		; MSB of pitch value
	mov	DSPData, Y
loc_A30:
	dec	t_PitchSlideSteps+X
	bne	loc_A39
	mov	A, #-1
	mov	t_PitchSlideDelay+X, A
loc_A39:
	mov	A, EffectFlags+X
	and	A, #2
	beq	loc_AB4
	mov	A, t_VibDelay+X
	beq	loc_A48
	dec	t_VibDelay+X
	RET

loc_A48:
	dec	t_VibInterval+X
	bne	loc_AB4
	mov	A, VibInterval+X
	mov	t_VibInterval+X, A
	mov	A, VibratoDepth+X
	mov	0, A
	bpl	loc_A5C
	mov	A, #-1
	JMP	loc_A5E
loc_A5C:
	mov	A, #0
loc_A5E:
	mov	1, A
	mov	A, Pitch_Low+X
	mov	Y, Pitch_High+X
	cmp	X, #13	; is the engine processing SFX channel #5?
	bne	loc_A87	; if no, branch
	subw	YA, SndPitchOffset
	addw	YA, SndNewPitchOffset
	mov	SndPitchOffset, SndNewPitchOffset
	mov	SndPitchOffset+1, SndNewPitchOffset+1
loc_A87:
	CALL	AddAndClipPitch
	mov	A, X
	and	A, #7
	xcn	A
	or	A, #2
	mov	DSPAddr, A	; LSB of pitch value
	mov	A, Pitch_Low+X
	mov	DSPData, A
	inc	DSPAddr		; MSB of pitch value
	mov	DSPData, Y
loc_AA2:
	dec	t_VibSteps+X
	bne	loc_AB4
	mov	A, VibLen+X
	mov	t_VibSteps+X, A
	mov	A, VibratoDepth+X
	eor	A, #-1
	inc	A
	mov	VibratoDepth+X, A
loc_AB4:
	ret
; ==============================================================================
StopTrack:	; $B18
	MOV	X, CurrentTrack
	CALL	SoftKeyRelease
	MOV	A, #0
	MOV	SndActive+X, A
	MOV	EffectFlags+X, A
	CMP	X, #8
	BCC	+
	MOV	SFXOverride-8+X, A
+	BBS3	GlobalFlags, +
	RET

+	JMP	GetMessage
; ==============================================================================
SetInstrument:	; $B72
	MOV	A, (0)+Y
	MOV	X, A
	MOV	A, TimbreLUT+X
	MOV	X, CurrentTrack
	MOV	SndSRCN+X, A
	JMP	IncAndFinishEvent
; ==============================================================================
SetVoiceParams:	; $B97
	MOV	A, (0)+Y
	MOV	X, A
	MOV	A, TimbreLUT+X
	MOV	X, CurrentTrack
	MOV	SndSRCN+X, A
	INC	Y
	mov	A, (0)+Y
	mov	Transpose+X, A	; transpose
	inc	Y
	mov	A, (0)+Y
	mov	SndFineTune+X, A	; tuning
	inc	Y
	mov	A, (0)+Y
	mov	SndVolume_L+X, A
	inc	Y
	mov	A, (0)+Y
	mov	SndVolume_R+X, A
	inc	Y
	mov	A, (0)+Y
	mov	SndADSR1+X, A ; ADSR 1
	inc	Y
	mov	A, (0)+Y
	mov	SndADSR2+X, A ; ADSR 2
	JMP	IncAndFinishEvent
; ==============================================================================
SetVolume:	; $BB6
	MOV	X, CurrentTrack
	mov	A, (0)+Y
	mov	SndVolume_L+X, A
	inc	Y
	mov	A, (0)+Y
	mov	SndVolume_R+X, A
	JMP	IncAndFinishEvent
; ==============================================================================
SetVolume_4:	; $BF0
	MOV	X, CurrentTrack
	mov	A, (0)+Y
	mov	SndVolume_L+X, A
	mov	SndVolume_R+X, A
	JMP	IncAndFinishEvent
; ==============================================================================
UsePresetVolume1:	; $C02
	MOV	X, CurrentTrack
	mov	A, VolPreset1_L
	mov	SndVolume_L+X, A
	mov	A, VolPreset1_R
	mov	SndVolume_R+X, A
	JMP	FinishEvent
; ==============================================================================
UsePresetVolume2:	; $C18
	MOV	X, CurrentTrack
	mov	A, VolPreset2_L
	mov	SndVolume_L+X, A
	mov	A, VolPreset2_R
	mov	SndVolume_R+X, A
	JMP	FinishEvent
; ==============================================================================
SetBGMVol:	; $C4E
	mov	A, (0)+Y
	mov	BGMVol, A

	MOV	X, #7
-	MOV	A, EffectFlags+X	; effects
	AND	A, #$BF
	MOV	EffectFlags+X, A
	DEC	X
	BPL	-

	JMP	IncAndFinishEvent
; ==============================================================================
ApplyVolMod:	; $C59
	; calculate sound volume with following formula:
	; Volume*Modifier/100
	cmp	X, #8
	bcs	ApplyVolMod2_ret	; don't change volume for SFXs
	mov	Y, BGMVol
ApplyVolMod2:
	push	X
	or	A, #0
	bmi	loc_C71
	mul	YA
	mov	X, #100
	div	YA, X
	bvs	+
	mov	X, A
	bpl	++	; branch if A < 128
+	mov	A, #127
++	pop	X
.ret:	ret

loc_C71:
	eor	A, #-1
	inc	A
	mul	YA
	mov	X, #100
	div	YA, X
	bvs	+
	mov	X, A
	bpl	++	; branch if A < 128
+	mov	A, #-128
	pop	X
	ret

++	eor	A, #-1
	inc	A
	pop	X
	ret
; ==============================================================================
SetVolumePreset:	; $C83
	mov	A, (0)+Y
	mov	VolPreset1_L, A
	inc	Y
	mov	A, (0)+Y
	mov	VolPreset1_R, A
	inc	Y
	mov	A, (0)+Y
	mov	VolPreset2_L, A
	inc	Y
	mov	A, (0)+Y
	mov	VolPreset2_R, A
	JMP	IncAndFinishEvent
; ==============================================================================
WaitForEcho:
	mov	A, EchoBufferLoc
	MOV	.w1+2, A
	MOV	.w2+2, A
	MOV	A, #1
.w1:	MOV	$FF00, A
.w2:	MOV	A, $FF00
	BNE	.w2
+	RET
; ==============================================================================
SetEchoDelay:	; $CA0
	MOV	A, #0
	mov	DSPAddr, #$7D	; echo delay
	mov	DSPData, A
	mov	DSPAddr, #$D	; Echo feedback
	mov	DSPData, A
	mov	DSPAddr, #$4D	; Echo enable
	mov	DSPData, A
	CALL	WaitForEcho
	CALL	WaitForEcho
	mov	A, (0)+Y
	AND	A, #$1E
	BEQ	+

	mov	2, A
	mov	DSPAddr, #$6D	; echo buffer location
	asl	A
	asl	A
	eor	A, #-1
	mov	DSPData, A
	mov	EchoBufferLoc, A

	mov	DSPAddr, #$7D	; echo delay
	mov	A, 2
	lsr	A
	mov	DSPData, A

	CALL	WaitForEcho
	MOV	A, Timer0_out
	MOV	A, Timer1_out

+	JMP	IncAndFinishEvent
; ==============================================================================
Jump:	; $CD7
	MOV	A, (0)+Y	; LSB
	MOV	2, A
	INC	Y
	MOV	A, (0)+Y	; MSB
	MOV	1, A
	MOV	0, 2
	MOV	Y, #0
	JMP	FinishEvent
; ==============================================================================
CallSubroutine:	; $CE6
	MOV	A, (0)+Y	; repeat count
	MOV	2, A
	INC	Y

CallSubroutine2:
	MOV	X, CurrentTrack

	MOV	A, Y
	MOV	Y, #0
	ADDW	YA, 0
	MOVW	3, YA

	MOV	Y, SndStackPtr+X
	MOV	Stack_PtrL+Y, A
	MOV	A, 4
	MOV	Stack_PtrH+Y, A
	MOV	A, 2
	MOV	Stack_RepCnt+Y, A
	INC	SndStackPtr+X

	MOV	Y, #1
	MOV	A, (3)+Y	; MSB
	MOV	1, A
	DEC	Y
	MOV	A, (3)+Y	; LSB
	MOV	0, A
	JMP	FinishEvent
; ==============================================================================
CallSubroutineOnce:	; $CFF
	MOV	2, #1
	JMP	CallSubroutine2
; ==============================================================================
RetSub:	; $D34
	MOV	X, CurrentTrack

	MOV	Y, SndStackPtr+X
	DEC	Y
	MOV	A, Stack_PtrL+Y	; LSB
	MOV	0, A
	MOV	A, Stack_PtrH+Y	; MSB
	MOV	1, A

	MOV	A, Stack_RepCnt+Y
	DEC	A
	MOV	Stack_RepCnt+Y, A	; decrement repeat count
	BEQ	+

	MOV	Y, #1
	MOV	A, (0)+Y	; MSB
	MOV	2, A
	DEC	Y
	MOV	A, (0)+Y	; LSB
	MOV	0, A
	MOV	1, 2
	JMP	FinishEvent

+	MOV	SndStackPtr+X, Y
	MOV	Y, #2
	JMP	FinishEvent
; ==============================================================================
SetDefaultDuration:	; $D70
	MOV	X, CurrentTrack
	mov	A, (0)+Y
	mov	DfltDuration_Low+X, A
	mov	A, SndLongDuration+X
	beq	+
	mov	A, DfltDuration_Low+X
	mov	DfltDuration_High+X, A
	inc	Y
	mov	A, (0)+Y
	mov	DfltDuration_Low+X, A
+
	JMP	IncAndFinishEvent
; ==============================================================================
DisableDfltDuration:	; $D8F
	MOV	X, CurrentTrack
	MOV	A, #0
	mov	DfltDuration_Low+X, A
	mov	DfltDuration_High+X, A
	JMP	FinishEvent
; ==============================================================================
SetPortamento_1:	; $D9B
	MOV	X, CurrentTrack
	MOV	A, EffectFlags+X
	OR	A, #1
	MOV	EffectFlags+X, A

	MOV	A, (0)+Y	; delay
	MOV	PitchSlideDelay+X, A
	INC	Y
	MOV	A, (0)+Y	; interval
	MOV	PitchSlideInterval+X, A
	INC	Y
	MOV	A, (0)+Y	; length
	MOV	PitchSlideSteps+X, A
	INC	Y
	MOV	A, (0)+Y	; delta
	MOV	PitchSlideDelta+X, A
	INC	Y
	MOV	A, (0)+Y	; opposite direction length
	MOV	PitchSlideStepsDown+X, A
	JMP	IncAndFinishEvent
; ==============================================================================
SetPortamento_2:	; $DA2
	MOV	X, CurrentTrack
	MOV	A, EffectFlags+X
	OR	A, #1
	MOV	EffectFlags+X, A

	MOV	A, (0)+Y	; delay
	MOV	PitchSlideDelay+X, A
	INC	Y
	MOV	A, (0)+Y	; interval
	MOV	PitchSlideInterval+X, A
	INC	Y
	MOV	A, (0)+Y	; length
	MOV	PitchSlideSteps+X, A
	INC	Y
	MOV	A, (0)+Y	; delta
	EOR	A, #-1
	INC	A
	MOV	PitchSlideDelta+X, A
	INC	Y
	MOV	A, (0)+Y	; opposite direction length
	MOV	PitchSlideStepsDown+X, A
	JMP	IncAndFinishEvent
; ==============================================================================
DisablePortamento:	; $DD6
	MOV	X, CurrentTrack
	mov	A, EffectFlags+X
	and	A, #-2	; clear "portamento enable" flag
	mov	EffectFlags+X, A
	JMP	FinishEvent
; ==============================================================================
SetTempo:	; $DEB
	mov	A, (0)+Y
	mov	BGMTempo, A
	CALL	TempoToInterval
	JMP	IncAndFinishEvent
; ==============================================================================
AddTempo:	; $DF8
	MOV	A, (0)+Y
	CLRC
	ADC	A, BGMTempo
	MOV	BGMTempo, A
	CALL	TempoToInterval
	JMP	IncAndFinishEvent
; ==============================================================================
DisableVibrato:	; $E05
	MOV	X, CurrentTrack
	mov	A, EffectFlags+X
	and	A, #-3
	mov	EffectFlags+X, A
	JMP	FinishEvent
; ==============================================================================
SetVibrato_1:	; $E11
	MOV	X, CurrentTrack
	mov	A, EffectFlags+X
	or	A, #2	; set "vibrato enabled" bit
	mov	EffectFlags+X, A

	mov	A, (0)+Y
	mov	VibLen+X, A ; vibrato cycle length
	inc	Y
	mov	A, (0)+Y
	mov	VibInterval+X, A ; step interval
	inc	Y
	mov	A, (0)+Y
	mov	VibratoDepth+X, A ; pitch delta
	MOV	A, #0
	mov	VibratoDelay+X, A
	JMP	IncAndFinishEvent
; ==============================================================================
SetVibrato_2:	; $E1A
	MOV	X, CurrentTrack
	mov	A, EffectFlags+X
	or	A, #2	; set "vibrato enabled" bit
	mov	EffectFlags+X, A

	mov	A, (0)+Y
	mov	VibLen+X, A ; vibrato cycle length
	inc	Y
	mov	A, (0)+Y
	mov	VibInterval+X, A ; step interval
	inc	Y
	mov	A, (0)+Y
	mov	VibratoDepth+X, A ; pitch delta
	inc	Y
	mov	A, (0)+Y
	mov	VibratoDelay+X, A
	JMP	IncAndFinishEvent
; ==============================================================================
SetADSR_1:	; $E45
	MOV	X, CurrentTrack
	mov	A, (0)+Y
	mov	SndADSR1+X, A ; ADSR 1
	inc	Y
	mov	A, (0)+Y
	mov	SndADSR2+X, A ; ADSR 2
	JMP	IncAndFinishEvent
; ==============================================================================
SetVarNote1:	; $E5A
	MOV	X, CurrentTrack
	mov	A, (0)+Y
	mov	VarNote0+X, A
	JMP	IncAndFinishEvent
; ==============================================================================
SetVarNote2:	; $E64
	MOV	X, CurrentTrack
	mov	A, (0)+Y
	mov	VarNote1+X, A
	JMP	IncAndFinishEvent
; ==============================================================================
Tuning:	; $E71
	MOV	X, CurrentTrack
	mov	A, (0)+Y
	mov	SndFineTune+X, A
	JMP	IncAndFinishEvent
; ==============================================================================
SetTranspose:	; $E7B
	MOV	X, CurrentTrack
	mov	A, (0)+Y
	mov	Transpose+X, A
	JMP	IncAndFinishEvent
; ==============================================================================
AddTranspose:	; $E88
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	CLRC
	adc	A, Transpose+X
	mov	Transpose+X, A
	JMP	IncAndFinishEvent
; ==============================================================================
SetEcho:	; $E97
	mov	DSPAddr, #$D  ; echo feedback
	mov	A, (0)+Y
	mov	DSPData, A
	inc	Y

	mov	DSPAddr, #$2C ; echo left channel
	mov	A, (0)+Y
	mov	DSPData, A
	inc	Y

	mov	DSPAddr, #$3C ; echo right channel
	mov	A, (0)+Y
	mov	DSPData, A

	JMP	IncAndFinishEvent
; ==============================================================================
EchoOn:	; $EC4
	MOV	X, CurrentTrack
	mov	A, #1
	mov	SndEchoFlag+X, A
	JMP	FinishEvent
; ==============================================================================
EchoOff:	; $EDC
	MOV	X, CurrentTrack
	mov	A, #0
	mov	SndEchoFlag+X, A
	JMP	FinishEvent
; ==============================================================================
EchoFilter:	; $EF6
	mov	DSPAddr, #$F	; FIR 1st tap

-	MOV	A, (0)+Y
	MOV	DSPData, A
	INC	Y
	CLRC
	ADC	DSPAddr, #$10
	BPL	-

	JMP	FinishEvent
; ==============================================================================
SetNoiseFreq:	; $F10
	mov	A, (0)+Y
	mov	DSPAddr, #$6C ; DSP flags
	mov	DSPData, A
	JMP	IncAndFinishEvent
; ==============================================================================
NoiseOn:	; $F23
	MOV	X, CurrentTrack
	MOV	A, EffectFlags+X
	OR	A, #$20
	MOV	EffectFlags+X, A
	JMP	FinishEvent
; ==============================================================================
NoiseOff:	; $F34
	MOV	X, CurrentTrack
	MOV	A, EffectFlags+X
	AND	A, #$DF
	MOV	EffectFlags+X, A
	JMP	FinishEvent
; ==============================================================================
SetPortamento_4:	; $F44
	MOV	X, CurrentTrack
	mov	A, EffectFlags+X
	or	A, #1
	mov	EffectFlags+X, A

	mov	A, (0)+Y ; delay
	mov	PitchSlideDelay+X, A
	inc	Y
	mov	A, (0)+Y ; portamento interval
	mov	PitchSlideInterval+X, A
	inc	Y
	mov	A, (0)+Y ; portamento steps
	mov	PitchSlideStepsDown+X, A
	asl	A
	mov	PitchSlideSteps+X, A
	inc	Y
	mov	A, (0)+Y ; pitch delta
	eor	A, #-1
	inc	A
	mov	PitchSlideDelta+X, A
	JMP	IncAndFinishEvent
; ==============================================================================
SetPortamento_5:	; $F4E
	MOV	X, CurrentTrack
	mov	A, EffectFlags+X
	or	A, #1
	mov	EffectFlags+X, A

	mov	A, (0)+Y ; delay
	mov	PitchSlideDelay+X, A
	inc	Y
	mov	A, (0)+Y ; portamento interval
	mov	PitchSlideInterval+X, A
	inc	Y
	mov	A, (0)+Y ; portamento steps
	mov	PitchSlideStepsDown+X, A
	asl	A
	mov	PitchSlideSteps+X, A
	inc	Y
	mov	A, (0)+Y ; pitch delta
	mov	PitchSlideDelta+X, A
	JMP	IncAndFinishEvent
; ==============================================================================
LongDurationOn:	; $F7C
	MOV	X, CurrentTrack
	MOV	A, #1
	mov	SndLongDuration+X, A
	JMP	FinishEvent
; ==============================================================================
LongDurationOff:	; $F86
	MOV	X, CurrentTrack
	MOV	A, #0
	mov	SndLongDuration+X, A
	JMP	FinishEvent
; ==============================================================================
VoiceBitMask:	; $F95
	db	1, 2, 4, 8, $10, $20, $40, $80	; used by BGM
	db	1, 2, 4, 8, $10, $20, $40, $80	; used by SFX
CtrlEventIndex:	; $FA5
	dw	StopTrack		; $00	; individual effect
	dw	SetInstrument		; $01	; individual effect (no rest required)
	dw	SetVolume		; $02	; individual effect (no rest required)
	dw	Jump			; $03	; individual effect (no rest required)
	dw	CallSubroutine		; $04	; individual effect (no rest required)
	dw	RetSub			; $05	; individual effect (no rest required)
	dw	SetDefaultDuration	; $06	; individual effect (no rest required)
	dw	DisableDfltDuration	; $07	; individual effect (no rest required)
	dw	SetPortamento_1		; $08	; individual effect
	dw	SetPortamento_2		; $09	; individual effect
	dw	DisablePortamento	; $0A	; individual effect
	DW	SetTempo		; $0B	; global effect
	DW	AddTempo		; $0C	; global effect
	DW	SetVibrato_1		; $0D	; individual effect
	DW	DisableVibrato		; $0E	; individual effect
	DW	SetVibrato_2		; $0F	; individual effect
	DW	SetADSR_1		; $10	; individual effect (no rest required)
	DW	0			; $11	; global effect
	DW	Tuning			; $12	; individual effect (no rest required)
	DW	SetTranspose		; $13	; individual effect (no rest required)
	DW	AddTranspose		; $14	; individual effect (no rest required)
	DW	SetEcho			; $15	; global effect
	DW	EchoOn			; $16	; individual effect (no rest required)
	DW	EchoOff			; $17	; individual effect (no rest required)
	DW	EchoFilter		; $18	; global effect
	DW	SetNoiseFreq		; $19	; global effect
	DW	NoiseOn			; $1A	; individual effect
	DW	NoiseOff		; $1B	; individual effect
	DW	SetVarNote1		; $1C	; individual effect (no rest required)
	DW	SetVarNote2		; $1D	; individual effect (no rest required)
	DW	SetVolumePreset		; $1E	; global effect
	DW	SetEchoDelay		; $1F	; individual effect (no rest required)
	DW	UsePresetVolume1	; $20	; global effect
	DW	CallSubroutineOnce	; $21	; individual effect (no rest required)
	DW	SetVoiceParams		; $22	; individual effect (no rest required)
	DW	SetVolume_4		; $23	; individual effect (no rest required)
	DW	SetBGMVol		; $24	; global effect
	DW	0			; $25	; global effect
	DW	SetPortamento_4		; $26	; individual effect
	DW	SetPortamento_5		; $27	; individual effect
	DW	0			; $28	; global effect
	DW	0			; $29	; global effect
	DW	0			; $2A	; global effect
	DW	LongDurationOn		; $2B	; individual effect (no rest required)
	DW	LongDurationOff		; $2C	; individual effect (no rest required)
	DW	0			; $2D	; global effect
	DW	0			; $2E	; global effect
	DW	0			; $2F	; global effect
	DW	EchoOff			; $30	; individual effect (no rest required)
	DW	UsePresetVolume2	; $31	; global effect
	DW	EchoOff			; $32	; individual effect (no rest required)
; ==============================================================================
EventTypeTable:
	DB	1	; individual effect
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	1	; individual effect
	DB	1	; individual effect
	DB	1	; individual effect
	DB	0	; global effect
	DB	0	; global effect
	DB	1	; individual effect
	DB	1	; individual effect
	DB	1	; individual effect
	DB	-1	; individual effect (no rest required)
	DB	0	; global effect
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	0	; global effect
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	0	; global effect
	DB	0	; global effect
	DB	1	; individual effect
	DB	1	; individual effect
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	0	; global effect
	DB	-1	; individual effect (no rest required)
	DB	0	; global effect
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	0	; global effect
	DB	0	; global effect
	DB	1	; individual effect
	DB	1	; individual effect
	DB	0	; global effect
	DB	0	; global effect
	DB	0	; global effect
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	0	; global effect
	DB	0	; global effect
	DB	0	; global effect
	DB	-1	; individual effect (no rest required)
	DB	0	; global effect
	DB	-1	; individual effect (no rest required)
; ==============================================================================
SetUpEngine:	; $100B
	mov	A, #0
	mov	DSPAddr, #$D	; Echo feedback
	mov	DSPData, A
	mov	DSPAddr, #$4D	; Echo enable
	mov	DSPData, A
	mov	DSPAddr, #$5C	; Key-off
	mov	DSPData, #-1
	mov	DSPAddr, #$2C	; Echo left channel
	mov	DSPData, A
	mov	DSPAddr, #$3C	; Echo right channel
	mov	DSPData, A
	mov	DSPAddr, #$3D	; Noise enable
	mov	DSPData, A
	mov	DSPAddr, #$2D	; Pitch modulation, which is unused
	mov	DSPData, A
	mov	DSPAddr, #$5D	; sample pointer table location
	mov	DSPData, #$31
	mov	DSPAddr, #$C	; Master left channel
	mov	DSPData, #64
	mov	DSPAddr, #$1C	; Master right channel
	mov	DSPData, #64
	mov	DSPAddr, #$6C	; DSP flags
	mov	DSPData, A

	MOV	GlobalFlags, A
	mov	SndNewPitchOffset, A	; clear pitch modifier for SFX channel #5
	mov	SndNewPitchOffset+1, A
	mov	SndPitchOffset, A
	mov	SndPitchOffset+1, A
	MOV	KeyOnShadow, A
	mov	SndEnable, A	; don't play any sounds at startup
	MOV	Timer0Ticks, A
	MOV	Timer1Ticks, A

	mov	A, #100
	mov	BGMVol, A

	mov	A, #0
	mov	0, #8
	mov	X, A
	mov	Y, A
	mov	1, Y
loc_10A9:
	mov	A, #1
	mov	Duration_Low+X, A	; set delay duration to 1
	mov	SndActive+X, A
	mov	A, (MusicPointer)+Y
	mov	TrkPointer_LSB+X, A
	inc	Y
	mov	A, (MusicPointer)+Y
	mov	TrkPointer_MSB+X, A
	mov	A, 1
	mov	SndStackPtr+X, A
	mov	A, #0
	mov	SndLongDuration+X, A
	mov	Duration_High+X, A
	mov	DfltDuration_Low+X, A
	mov	DfltDuration_High+X, A
	mov	EffectFlags+X, A
	mov	Transpose+X, A
	mov	SndFineTune+X, A
	mov	SFXOverride+X, A
	mov	SndEchoFlag+X, A
	mov	SndActive+8+X, A
	; set ADSR to $8E-$E1
	mov	A, #$8E
	mov	SndADSR1+X, A
	mov	A, #$E1
	mov	SndADSR2+X, A
	inc	X
	inc	Y
	clrc
	adc	1, #8
	dbnz	0, loc_10A9

	mov	A, (MusicPointer)+Y
	mov	BGMTempo, A
TempoToInterval:
	CLR1	GlobalFlags
	PUSH	Y
	MOV	X, A
	MOV	A, #0
	MOV	Y, #$64	; YA = 25600
	DIV	YA, X
	BVC	+	; branch if the quotient is <256
	SETC
	ROR	A	; A = (A >> 1) | $80
	SET1	GlobalFlags
+	MOV	Timer0, A
	POP	Y
	RET
;===============================================================================
SetUpSFX:	; $10F7
	; inputs:
	; A: ID of SFX
	; X: number of channel SFX to be played at
	push	A
	cmp	A, #$60
	bpl	loc_1104	; branch if ID >= $60
	setc
	sbc	A, $2410
	bpl	loc_110D
	JMP	loc_1111
loc_1104:
	setc
	sbc	A, #$60
	setc
	sbc	A, $2E94
	bmi	loc_1111

	; if ID is out of range,
	; replace given SFX with
	; "Stop SFX" command
loc_110D:
	pop	A
	mov	A, #0
	push	A
loc_1111:
	pop	A
	asl	A
	push	A

	CALL	HardKeyRelease
	MOV	A, EffectFlags+X	; effects
	AND	A, #$3F
	MOV	EffectFlags+X, A
	mov	A, #1
	mov	SFXOverride+X, A	; lock the channel

	mov	A, X
	or	A, #8	; set "SFX channel" bit
	mov	X, A
	asl	A	; multiple by 8
	asl	A
	asl	A
	mov	SndStackPtr+X, A	; store stack pointer
	mov	A, #1
	mov	SndActive+X, A	; activate the channel
	dec	A
	mov	DfltDuration_Low+X, A
	mov	DfltDuration_High+X, A
	mov	Duration_High+X, A
	mov	SndLongDuration+X, A
	mov	SFXOverride+X, A
	mov	EffectFlags+X, A	; disable sound modulation
	mov	Transpose+X, A
	mov	SndEchoFlag+X, A	; disable echo
	mov	SndFineTune+X, A

	; set center volume to 127
	mov	A, #127
	mov	SndVolume_L+X, A
	mov	SndVolume_R+X, A

	; set ADSR to $8E-$E1
	mov	A, #$8E
	mov	SndADSR1+X, A
	mov	A, #$E1
	mov	SndADSR2+X, A

	; set track pointer
	pop	A
	cmp	A, #$C0	; $60
	bcs	loc_1179
	mov	Y, A
	mov	A, $2412+Y
	mov	TrkPointer_LSB+X, A
	inc	Y
	mov	A, $2412+Y
	mov	TrkPointer_MSB+X, A
	JMP	loc_1188
loc_1179:
	setc
	sbc	A, #$C0
	mov	Y, A
	mov	A, $2E96+Y
	mov	TrkPointer_LSB+X, A
	inc	Y
	mov	A, $2E96+Y
	mov	TrkPointer_MSB+X, A
loc_1188:
	inc	SFXCount
	mov	A, SFXCount
	mov	Duration_Low+X, A
	ret
;===============================================================================
PitchTable:	; $1199
	; this section contains raw pitch values for S-DSP
PitchTable_LSB:
	DB	0
PitchTable_MSB:	; $119A
	DB	0
	dw	$40
	dw	$44, $48, $4C, $51, $55, $5B
	dw	$60, $66, $6C, $72, $79, $80
	dw	$88, $90, $98, $A1, $AB, $B5
	dw	$C0, $CB, $D7, $E4, $F2, $100
	dw	$10F, $11F, $130, $143, $156, $16A
	dw	$180, $196, $1AF, $1C8, $1E3
	dw	512, 543, 575, 609, 646, 684
	dw	725, 768, 813, 862, 913, 967
	dw	1024, 1085, 1150, 1218, 1291, 1367
	dw	1449, 1535, 1626, 1723, 1825, 1934
	dw	2048, 2170, 2299, 2436, 2581, 2734
	dw	2897, 3069, 3251, 3445, 3650, 3867
	dw	4096, 4340, 4598, 4871, 5161, 5468
	dw	5793, 6138, 6502, 6889, 7299, 7733
	dw	8192, 8680, 9196, 9742, 10322, 10936
	dw	11586, 12275, 13004, 13778, 14597, 15465
	dw	$3FFF
