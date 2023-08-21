; Modified Rare's Donkey Kong Country.
; Based on Donkey Kong Country sound engine disassembly.
; Author: PoteznaSowa.

; Some changes included in the mod:
; - optimised code, unused features removed, data transfer sped up;
; - added preprocessing of sound sequence data in background;
; - music runs at variable SPC timer period instead of
;   using a single fixed-period timer in the original design;
; - removed mixing-out stereo which is anyway not used in the game

hirom

	ORG	0
; Page 0 variables

; 0: engine is running
; 1: halve BGM tempo
; 2: if bit 1 is set, skip BGM updates
; 3: initialize DSP
; 4: events are being preprocessed
GlobalFlags:		skip 1

ScratchArea:		skip 5	; local variables take place here

;NoiseShadow:		skip 1	; DSP Flags & $1F
;DSPFlagShadow:		skip 1	; DSP Flags & $E0
KeyOnShadow:		skip 1
CurrentTrack:		skip 1
CurPreprocTrack:	skip 1


BGMTempo:		skip 1
Timer0Ticks:		skip 1
Timer1Ticks:		skip 1
SFXDivCounter:		skip 1	; must be 1..8
MiscDivCounter:		skip 1	; must be 1..5


NoteLen_H:		skip 16	; $2C
NoteLen_L:		skip 16	; $3C
TrackPtr_L:		skip 16	; $4C
TrackPtr_H:		skip 16	; $5C
FineTune:		skip 16	; $6C
MeanPitch_H:		skip 16	; $7C	; used for pitch slide and vibrato
MeanPitch_L:		skip 16	; $8C	; used for pitch slide and vibrato
t_PitchSlideSteps:	skip 16	; $9C
t_VibSteps:		skip 16	; $AC
t_VibInterval:		skip 16 ; $BC
t_VibDelay:		skip 16	; $CC
PrevEnvLvl:		skip 16
SndStackPtr:		skip 16 ; $DC

BGMSwitch:		skip 1	; $ED
MsgBuffer:		skip 1


; Memory-mapped hardware registers, also in page 0
	ORG	$F0
		skip 1	; debug register, never use
HWControl:	skip 1
DSPAddr:	skip 1
DSPData:	skip 1
IOPort0:	skip 1
IOPort1:	skip 1
IOPort2:	skip 1
IOPort3:	skip 1
IOUnused0:	skip 1	; can be used as RAM
IOUnused1:	skip 1	; can be used as RAM
Timer0:		skip 1
Timer1:		skip 1
Timer2:		skip 1
Timer0_out:	skip 1
Timer1_out:	skip 1
Timer2_out:	skip 1

; Direct page 1 variables
PitchSlideTimer:	skip 16	; $100
TrackOperating:		skip 16	; $110
DefaultDur_L:		skip 16 ; $120
DefaultDur_H:		skip 16 ; $130
Transpose:		skip 16 ; $140

; 0: portamento on
; 1: vibrato on
; 2: tremolo on
; 6: already ready for key-on
; 7: track audible (no rest)
EffectFlags:		skip 16	; $150

PitchSlideDelayTimer:	skip 16	; $160
PitchSlideDelta:	skip 16 ; $170
PitchSlideAltCntr:	skip 16	; $180
LongNote:		skip 16	; $190
ChannelOverride:	skip 16	; $1A0
PitchSlideDelay:	skip 16	; $1B0
PitchSlideInterval:	skip 16	; $1C0
PitchSlideLen:		skip 16 ; $1D0
PitchSlideAltLen:	skip 16 ; $1E0
			skip 16	; $1F0	; program stack


; From here, these variables cannot be accessed using direct page addressing
VibratoLen:		skip 16	; $200
VibratoInterval:	skip 16	; $210
VibratoDelay:		skip 16	; $220

MasterL_Shadow:		skip 1	; $230
MasterR_Shadow:		skip 1	; $231
EchoL_Shadow:		skip 1	; $232
EchoR_Shadow:		skip 1	; $233

VibratoDepth:		skip 16	; $234

SndSRCN:		skip 16	; $244
SndVolL:		skip 16	; $254
SndVolR:		skip 16	; $264
SndADSR1:		skip 16	; $274
SndADSR2:		skip 16	; $284
SndEchoFlag:		skip 16	; $294

TremoloDelayTimer:	skip 16	; $2A4
TremoloTimer:		skip 16	; $2B4
TremoloInterval:	skip 16	; $2C4
TremoloDepth:		skip 16	; $2D4
TremoloCntr:		skip 16	; $2E4
TremoloLen:		skip 16	; $2F4
TremoloDelay:		skip 16	; $304
VolL_Copy:		skip 16	; $314	; used for tremolo
VolR_Copy:		skip 16	; $324	; used for tremolo

Stack_PtrL:		skip 128	; $334
Stack_PtrH:		skip 128	; $3B4
Stack_RepCnt:		skip 128	; $434

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

SoundEntryPnt =		$5E8
MusicData =		$12A0
SFXData	=		$2380

	arch spc700
	optimize dp always

	ORG	$8AA342
	base	$4B8
;-----------------------------------------------------------------------------
	MOV	MsgBuffer, IOPort0
	SET3	GlobalFlags
	MOV	X, #0			; clear X
	MOV	Y, MsgBuffer		; read previous message
TransferMode:
-	CMP	Y, IOPort0		; has SNES sent next data?
	BEQ	-			; repeat if not
	MOV	Y, IOPort0		; load message ID into Y
	BBC0	IOPort0, +		; if it is even, branch

	MOV	A, IOPort1		; read data byte
	MOV	(IOPort2+X), A		; store it at the address from IOPort2
	MOV	IOPort0, Y		; reply to SNES
	JMP	-			; retry
;-----------------------------------------------------------------------------
+	MOV	IOPort0, Y
	MOV	MsgBuffer, Y
	MOV	X, #$FF
	MOV	IOPort1, X	; indicate for SNES that engine is ready
	MOV	SP, X	; SP = $01FF

	;MOV	MsgBuffer, Y		; store previous message
	;JMP	(IOPort2+X)		; run program at the address from IOPort2
	JMP	ProgramStart
;-----------------------------------------------------------------------------
	rep 9 : db 0
;-----------------------------------------------------------------------------
TimbreLUT:
	rep 256 : db 0
;-----------------------------------------------------------------------------
ProgramStart:
	CALL	SetUpEngine

GetMessage:	; $606
	MOV	Y, IOPort0	; read message ID
	CMP	Y, MsgBuffer	; has SNES sent next message?
	BEQ	NoMessage	; branch if no
	MOV	A, IOPort1	; read first byte of message
	MOV	X, IOPort2	; read second byte of message
	MOV	IOPort0, Y	; reply to SNES
	MOV	MsgBuffer, Y	; store message ID

	CMP	A, #$FF
	BEQ	GotoTransferMode
	CMP	A, #$FE
	BEQ	StartSound
	CMP	A, #$FD
	BEQ	SetBGMSwitch
	CMP	A, #$FC
	BEQ	SetMonoFlag

	; play SFX
	CALL	PlaySFX
	JMP	GetMessage
;-----------------------------------------------------------------------------
SetBGMSwitch:	; $635
	MOV	BGMSwitch, X
	JMP	GetMessage
;-----------------------------------------------------------------------------
SetMonoFlag:	; $63C
	JMP	GetMessage
;-----------------------------------------------------------------------------
GotoTransferMode:	; $71F
	MOV	X, #0
	MOV	IOPort1, X
	MOV	DSPAddr, #$5C	; key-off
	MOV	DSPData, #-1	; mute all channels
	MOV	DSPAddr, #$D	; echo feedback
	MOV	DSPData, X
	JMP	TransferMode
;-----------------------------------------------------------------------------
StartSound:	; $643
	SET0	GlobalFlags
	MOVW	YA, Timer0_out
	JMP	GetMessage
;-----------------------------------------------------------------------------
NoMessage:	; $649
	BBC0	GlobalFlags, PreprocessTracks

	CLR4	GlobalFlags

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

	DBNZ	SFXDivCounter, SkipSFXUpdate
	MOV	SFXDivCounter, #8

	MOV	CurrentTrack, #8

UpdateSFX:
	MOV	X, CurrentTrack
	MOV	A, $1A0-8+X
	BEQ	+
	CALL	UpdateTrack
+	INC	CurrentTrack
	CMP	CurrentTrack, #16
	BCC	UpdateSFX
	CALL	WriteKeyOn

SkipSFXUpdate:
	DBNZ	MiscDivCounter, PreprocessTracks
	MOV	MiscDivCounter, #5

	MOV	CurrentTrack, #0

UpdateTracks2:
	MOV	X, CurrentTrack
	MOV	A, $1A0+X	; is the channel used by SFX?
	BEQ	+		; branch if no
	OR	CurrentTrack, #8
+	CALL	UpdateTrack2
	AND	CurrentTrack, #7
	INC	CurrentTrack
	CMP	CurrentTrack, #8
	BCC	UpdateTracks2

PreprocessTracks:
	CMP	MsgBuffer, IOPort0	; has SNES sent next message?
	BNE	Goto_GetMessage		; branch if yes

	BBC0	GlobalFlags, +

	CLRC
	ADC	Timer0Ticks, Timer0_out
	BNE	Goto_GetMessage
	CLRC
	ADC	Timer1Ticks, Timer1_out
	BNE	Goto_GetMessage

+	INC	CurPreprocTrack
	AND	CurPreprocTrack, #15
	MOV	X, CurPreprocTrack

	MOV	A, $110+X
	BEQ	Goto_GetMessage

	MOV	A, X
	AND	A, #7
	XCN	A
	OR	A, #8
	MOV	DSPAddr, A
	MOV	A, DSPData
	CMP	A, PrevEnvLvl+X
	MOV	PrevEnvLvl+X, A
	BCS	+
	OR	A, #0
	BNE	+
	MOV	A, $150+X	; effects
	AND	A, #$7F
	MOV	$150+X, A

+	MOV	CurrentTrack, X
	MOV	A, TrackPtr_L+X
	MOV	Y, TrackPtr_H+X
	MOVW	1, YA
	MOV	Y, #0
	MOV	A, (1)+Y
	BMI	Preproc_RestOrNote
	MOV	X, A
	MOV	A, EventTypeTable+X
	BMI	+
	BEQ	Goto_GetMessage
	MOV	X, CurrentTrack
	MOV	A, $150+X	; effects
	BMI	Goto_GetMessage

+	SET4	GlobalFlags
	MOV	A, (1)+Y
	INC	Y
	ASL	A
	MOV	X, A
	JMP	(TrackEventTable+X)
;-----------------------------------------------------------------------------
Goto_GetMessage:
	JMP	GetMessage
;-----------------------------------------------------------------------------
Preproc_RestOrNote:
	CMP	A, #$80
	BEQ	Preproc_Rest

	PUSH	A
	MOV	A, $1A0+X
	POP	A
	BNE	Goto_GetMessage

	PUSH	A
	MOV	A, $150+X	; effects
	AND	A, #$C0
	POP	A
	BNE	Goto_GetMessage

	PUSH	A
	MOV	A, PrevEnvLvl+X
	POP	A
	BNE	Goto_GetMessage

	CALL	PrepareNote
	MOV	A, $150+X	; effects
	OR	A, #$40
	MOV	$150+X, A
	JMP	GetMessage
;-----------------------------------------------------------------------------
Preproc_Rest:
	MOV	A, $150+X	; effects
	AND	A, #$C0
	BNE	Goto_GetMessage
	INC	Y

	CLRC
	MOV	A, $120+X	; is default note duration set?
	BEQ	+		; branch if not
	MOV	3, A	; set duration LSB
	MOV	A, $130+X
	MOV	4, A	; set duration MSB
	JMP	++

+	MOV	A, $190+X	; is 16-bit note duration mode on?
	MOV	4, A
	BEQ	+		; branch if not
	MOV	A, (1)+Y	; get duration MSB
	MOV	4, A
	INC	Y
+	MOV	A, (1)+Y	; get duration LSB
	MOV	3, A
	INC	Y
++	MOV	5, Y
	MOV	A, NoteLen_L+X
	MOV	Y, NoteLen_H+X
	ADDW	YA, 3
	BCS	Goto_GetMessage
	MOV	NoteLen_L+X, A
	MOV	NoteLen_H+X, Y
	MOV	A, 5
	MOV	Y, #0
	ADDW	YA, 1
	MOV	TrackPtr_L+X, A	; store pointer LSB
	MOV	TrackPtr_H+X, Y	; store pointer MSB
	JMP	GetMessage
;-----------------------------------------------------------------------------
SoftKeyRelease:
	MOV	A, $1A0+X
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

	MOV	A, $150+X	; effects
	AND	A, #$7F
	MOV	$150+X, A
+	RET
;-----------------------------------------------------------------------------
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
;-----------------------------------------------------------------------------
UpdateTrack:	; $74E
	MOV	X, CurrentTrack
	; Update note countdown timer. If it expires, process next data.

	MOV	A, $110+X
	BEQ	+

	; Decrement note duration. If one tick is left, mute the channel.
	; If zero ticks are left, run next sound command.
	MOV	A, NoteLen_L+X
	MOV	Y, NoteLen_H+X

	CMP	X, #8
	BCS	.decDur
	BBC1	GlobalFlags, .decDur
	BBC2	GlobalFlags, .checkDur

.decDur:
	MOVW	1, YA
	MOVW	YA, 1
	BEQ	FetchNextEvent
	DECW	1
	BEQ	FetchNextEvent
	MOVW	YA, 1
	MOV	NoteLen_L+X, A
	MOV	NoteLen_H+X, Y

	CMP	X, #8
	BCS	.checkDur
	BBC1	GlobalFlags, .checkDur
	BBS2	GlobalFlags, +

.checkDur:
	CMP	A, #1
	BNE	+
	MOV	A, Y
	BNE	+
	MOV	A, $150+X	; effects
	AND	A, #$40
	BEQ	SoftKeyRelease
+	RET
;-----------------------------------------------------------------------------
FetchNextEvent:	; $78B
	MOV	A, TrackPtr_L+X
	MOV	Y, TrackPtr_H+X
	MOVW	1, YA
	MOV	Y, #0
FetchNextEvent2:
	MOV	A, (1)+Y
	BMI	GotoPlayNote
	INC	Y
	ASL	A
	MOV	X, A
	JMP	(TrackEventTable+X)
;-----------------------------------------------------------------------------
IncAndFinishEvent:
	INC	Y
FinishEvent:
	BBC4	GlobalFlags, FetchNextEvent2
	MOV	X, CurrentTrack
	MOV	A, Y
	MOV	Y, #0
	ADDW	YA, 1
	MOV	TrackPtr_L+X, A	; store pointer LSB
	MOV	TrackPtr_H+X, Y	; store pointer MSB
	JMP	GetMessage
;-----------------------------------------------------------------------------
ProcessRest:
	CALL	SoftKeyRelease2
Goto_SetDuration:
	MOV	A, $150+X	; effects
	AND	A, #$3F
	MOV	$150+X, A
	JMP	SetDuration
;-----------------------------------------------------------------------------
GotoPlayNote:
	INC	Y

	PUSH	A
	MOV	X, CurrentTrack
	MOV	A, $1A0+X	; is the channel used by SFX?
	POP	A
	BNE	Goto_SetDuration
	CMP	A, #$80			; is the event a rest?
	BEQ	ProcessRest		; if yes, branch

	PUSH	A
	MOV	A, $150+X	; effects
	AND	A, #$40
	POP	A
	BNE	+
	PUSH	Y
	CALL	PrepareNote
	POP	Y
+	MOV	A, VoiceBitTable+X
	TSET	KeyOnShadow, A
	MOV	A, $150+X	; effects
	AND	A, #$3F
	OR	A, #$80
	MOV	$150+X, A
	MOV	A, #0
	MOV	PrevEnvLvl+X, A

SetDuration:
	MOV	A, $120+X	; is default note duration set?
	BEQ	+		; branch if not
	MOV	NoteLen_L+X, A	; set duration LSB
	MOV	A, $130+X
	MOV	NoteLen_H+X, A	; set duration MSB
	JMP	++

+	MOV	A, $190+X	; is 16-bit note duration mode on?
	BEQ	+		; branch if not
	MOV	A, (1)+Y	; get duration MSB
	MOV	NoteLen_H+X, A
	INC	Y
+	MOV	A, (1)+Y	; get duration LSB
	MOV	NoteLen_L+X, A
	INC	Y

++
	MOV	A, Y
	MOV	Y, #0
	ADDW	YA, 1
	MOV	TrackPtr_L+X, A	; store pointer LSB
	MOV	TrackPtr_H+X, Y	; store pointer MSB
	RET
;-----------------------------------------------------------------------------
PrepareNote:
	MOV	DSPAddr, #$5C
	PUSH	A
	MOV	A, VoiceBitTable+X
	MOV	DSPData, A	; turn off the note, just in case
	POP	A

	; calculate pitch
	; Note: maximum range is 5 octaves
	CLRC
	ADC	A, $140+X
	ASL	A

	MOV	Y, FineTune+X
	BEQ	SkipFineTune
	MOV	X, A
	MOV	5, Y
	MOV	A, Y
	BPL	+
	EOR	A, #-1
	INC	A

+	MOV	Y, A
	PUSH	Y
	MOV	A, PitchTable+X
	MUL	YA
	MOV	3, Y
	MOV	4, #0
	POP	Y
	MOV	A, PitchTable+1+X
	MUL	YA
	ADDW	YA, 3
	MOV	4, Y

	LSR	4
	ROR	A
	LSR	4
	ROR	A
	MOV	3, A
	MOV	A, PitchTable+1+X
	MOV	Y, A
	MOV	A, PitchTable+X
	MOV	X, 5
	BMI	+
	ADDW	YA, 3
	JMP	++

+	SUBW	YA, 3
++	MOVW	3, YA
	JMP	Loc81F
;-----------------------------------------------------------------------------
SkipFineTune:	; $814
	MOV	X, A
	MOV	A, PitchTable+X
	MOV	3, A
	MOV	A, PitchTable+1+X
	MOV	4, A

Loc81F:
	MOV	A, CurrentTrack
	MOV	X, A
	AND	A, #7
	XCN	A
	MOV	DSPAddr, A

	MOV	A, $254+X
	MOV	DSPData, A	; left channel volume
	INC	DSPAddr
	MOV	A, $264+X
	MOV	DSPData, A	; right channel volume
	INC	DSPAddr

	MOV	A, $150+X
	AND	A, #1
	BEQ	+
	MOV	A, $1B0+X
	MOV	$160+X, A
	MOV	A, $1C0+X
	MOV	$100+X, A
	MOV	A, $1D0+X
	MOV	t_PitchSlideSteps+X, A
	MOV	A, $1E0+X
	MOV	$180+X, A
+	; $85A
	MOV	A, $150+X
	AND	A, #2
	BEQ	Loc87C
	MOV	A, $234+X
	BPL	+
	EOR	A, #-1
	INC	A
	MOV	$234+X, A
+	; $86C
	MOV	A, $200+X
	LSR	A
	MOV	t_VibSteps+X, A
	MOV	A, $210+X
	MOV	t_VibInterval+X, A
	MOV	A, $220+X
	MOV	t_VibDelay+X, A
Loc87C:
	MOV	A, $150+X
	AND	A, #4
	BEQ	Loc8AD
	MOV	A, $2D4+X
	BPL	+
	EOR	A, #-1
	INC	A
	MOV	$2D4+X, A
+	; $88E
	MOV	A, $2F4+X
	LSR	A
	MOV	$2E4+X, A
	MOV	A, $2C4+X
	MOV	$2B4+X, A
	MOV	A, $304+X
	MOV	$2A4+X, A
	MOV	A, $314+X
	MOV	$254+X, A
	MOV	A, $324+X
	MOV	$264+X, A
Loc8AD:

	MOV	A, 3
	MOV	MeanPitch_L+X, A
	MOV	DSPData, A	; pitch LSB
	INC	DSPAddr
	MOV	A, 4
	MOV	MeanPitch_H+X, A
	MOV	DSPData, A	; pitch MSB
	INC	DSPAddr
	MOV	A, $244+X
	MOV	DSPData, A	; SRCN
	INC	DSPAddr
	MOV	A, $274+X
	MOV	DSPData, A	; ADSR 1
	INC	DSPAddr
	MOV	A, $284+X
	MOV	DSPData, A	; ADSR 2
	INC	DSPAddr
	MOV	DSPData, #127	; GAIN value if ADSR is disabled

	MOV	DSPAddr, #DSP_EchoOn
	MOV	A, $294+X
	BEQ	+
	MOV	A, VoiceBitTable+X
	TSET	DSPData, A
	RET
;-----------------------------------------------------------------------------
+	MOV	A, VoiceBitTable+X
	TCLR	DSPData, A
	RET
;-----------------------------------------------------------------------------
AddAndClipPitch:
	MOV	2, A
	MOV	A, MeanPitch_L+X
	MOV	Y, MeanPitch_H+X
	ADDW	YA, 1
	BMI	++
	CMP	Y, #$40
	BCC	+
	MOV	Y, #$3F
	MOV	A, #$FF
+	MOV	MeanPitch_H+X, Y
	MOV	MeanPitch_L+X, A
	RET

++	MOV	A, #0
	MOV	Y, A
	MOV	MeanPitch_H+X, A
	MOV	MeanPitch_L+X, A
	RET
;-----------------------------------------------------------------------------
UpdateTrack2:	; $91C
	MOV	X, CurrentTrack
	MOV	A, $150+X
	BMI	+
	RET

	; Update pitch slide, vibrato and tremolo
+	AND	A, #1
	BNE	+
	JMP	Loc9A9

+	; $926
	MOV	A, $160+X
	BEQ	+
	CMP	A, #-1
	BEQ	Loc9A9
	DEC	A
	MOV	$160+X, A
	BNE	Loc9A9
	MOV	A, #1
	MOV	$100+X, A
+	; $93A
	MOV	A, $100+X
	DEC	A
	MOV	$100+X, A
	BNE	Loc9A9
	MOV	A, $1C0+X
	MOV	$100+X, A
	MOV	A, $180+X
	BEQ	Loc970
	DEC	A
	MOV	$180+X, A
	MOV	A, $170+X
	EOR	A, #-1
	INC	A
	MOV	1, A
	BPL	+
	MOV	A, #-1
	JMP	Loc962
+	; $960
	MOV	A, #0
Loc962:
	CALL	AddAndClipPitch
	JMP	Loc98B
Loc970:
	MOV	A, $170+X
	MOV	1, A
	BPL	+
	MOV	A, #-1
	JMP	Loc97F
+	; $97D
	MOV	A, #0
Loc97F:
	CALL	AddAndClipPitch
Loc98B:
	MOV	A, X
	AND	A, #7
	XCN	A
	OR	A, #DSP_Pitch
	MOV	DSPAddr, A
	MOV	A, MeanPitch_L+X
	MOV	DSPData, A
	INC	DSPAddr
	MOV	DSPData, Y
+	; $9A0
	DEC	t_PitchSlideSteps+X
	BNE	Loc9A9
	MOV	A, #-1
	MOV	$160+X, A

Loc9A9:
	MOV	A, $150+X
	AND	A, #2
	BEQ	LocA03
	MOV	A, t_VibDelay+X
	BEQ	+
	DEC	t_VibDelay+X
	JMP	LocA03
+	; $9B8
	DEC	t_VibInterval+X
	BNE	LocA03
	MOV	A, $210+X
	MOV	t_VibInterval+X, A
	MOV	A, $234+X
	MOV	1, A
	BPL	+
	MOV	A, #-1
	JMP	Loc9D0
+	; $9CE
	MOV	A, #0
Loc9D0:
	CALL	AddAndClipPitch

	MOV	A, X
	AND	A, #7
	XCN	A
	OR	A, #DSP_Pitch
	MOV	DSPAddr, A
	MOV	A, MeanPitch_L+X
	MOV	DSPData, A
	INC	DSPAddr
	MOV	DSPData, Y

	DEC	t_VibSteps+X
	BNE	LocA03
	MOV	A, $200+X
	MOV	t_VibSteps+X, A
	MOV	A, $234+X
	EOR	A, #-1
	INC	A
	MOV	$234+X, A
LocA03:
	MOV	A, $150+X
	AND	A, #4
	BEQ	LocA6D
	MOV	A, $2A4+X
	BEQ	+
	DEC	A
	MOV	$2A4+X, A
	RET

+	MOV	A, $2B4+X
	DEC	A
	MOV	$2B4+X, A
	BNE	LocA6D
	MOV	A, $2C4+X
	MOV	$2B4+X, A
	MOV	A, $2D4+X
	MOV	1, A
	CLRC
	ADC	A, $254+X
	MOV	$254+X, A
	MOV	A, 1
	CLRC	
	ADC	A, $264+X
	MOV	$264+X, A

	MOV	A, X
	AND	A, #7
	XCN	A
	MOV	DSPAddr, A
	MOV	A, $254+X
	MOV	DSPData, A
	INC	DSPAddr
	MOV	A, $264+X
	MOV	DSPData, A

	MOV	A, $2E4+X
	DEC	A
	MOV	$2E4+X, A
	BNE	LocA6D
	MOV	A, $2F4+X
	MOV	$2E4+X, A
	MOV	A, $2D4+X
	EOR	A, #-1
	INC	A
	MOV	$2D4+X, A
LocA6D:
	RET
;-----------------------------------------------------------------------------
EndOfTrack:	; $A6E
	MOV	X, CurrentTrack
	CALL	SoftKeyRelease
	MOV	A, #0
	MOV	$110+X, A
	MOV	$150+X, A
	CMP	X, #8
	BCC	LocAB7
	MOV	$1A0-8+X, A
	MOV	DSPAddr, #DSP_NoiseOn
	MOV	A, VoiceBitTable+X
	TCLR	DSPData, A

LocAB7:
	BBS4	GlobalFlags, +
	RET

+	JMP	GetMessage
;-----------------------------------------------------------------------------
SetVoice:	; $ABA
	MOV	A, (1)+Y
	MOV	X, A
	MOV	A, TimbreLUT+X
	MOV	X, CurrentTrack
	MOV	$244+X, A
	MOV	A, #0
	MOV	FineTune+X, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
SetVolume:	; $AE3
	MOV	X, CurrentTrack
	MOV	A, (1)+Y
	MOV	$254+X, A
	INC	Y
	MOV	A, (1)+Y
	MOV	$264+X, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
JumpTrack:	; $B14
	MOV	A, (1)+Y	; LSB
	MOV	3, A
	INC	Y
	MOV	A, (1)+Y	; MSB
	MOV	2, A
	MOV	1, 3
	MOV	Y, #0
	JMP	FinishEvent
;-----------------------------------------------------------------------------
CallSub:	; $B29
	MOV	X, CurrentTrack

	MOV	A, (1)+Y	; repeat count
	MOV	3, A
	INC	Y

	MOV	A, Y
	MOV	Y, #0
	ADDW	YA, 1
	MOVW	4, YA

	MOV	Y, SndStackPtr+X
	MOV	$334+Y, A
	MOV	A, 5
	MOV	$3B4+Y, A
	MOV	A, 3
	MOV	$434+Y, A
	INC	SndStackPtr+X

	MOV	Y, #1
	MOV	A, (4)+Y	; MSB
	MOV	2, A
	DEC	Y
	MOV	A, (4)+Y	; LSB
	MOV	1, A
	JMP	FinishEvent
;-----------------------------------------------------------------------------
RetSub:	; $B5E
	MOV	X, CurrentTrack

	MOV	Y, SndStackPtr+X
	DEC	Y
	MOV	A, $334+Y	; LSB
	MOV	1, A
	MOV	A, $3B4+Y	; MSB
	MOV	2, A

	MOV	A, $434+Y
	DEC	A
	BEQ	+
	MOV	$434+Y, A	; decrement repeat count

	MOV	Y, #1
	MOV	A, (1)+Y	; MSB
	MOV	3, A
	DEC	Y
	MOV	A, (1)+Y	; LSB
	MOV	1, A
	MOV	2, 3
	JMP	FinishEvent

+
	MOV	SndStackPtr+X, Y
	MOV	Y, #2
	JMP	FinishEvent
;-----------------------------------------------------------------------------
DefaultDurOn:	; $BA4
	MOV	X, CurrentTrack

	MOV	A, (1)+Y
	MOV	$120+X, A
	MOV	A, $190+X
	BEQ	+
	MOV	A, $120+X
	MOV	$130+X, A
	INC	Y
	MOV	A, (1)+Y
	MOV	$120+X, A
+	; $BC3
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
DefaultDurOff:	; $BC9
	MOV	X, CurrentTrack
	MOV	A, #0
	MOV	$120+X, A
	MOV	$130+X, A
	JMP	FinishEvent
;-----------------------------------------------------------------------------
PitchSlideUp:	; $BD5
	MOV	X, CurrentTrack
	MOV	A, $150+X
	OR	A, #1
	MOV	$150+X, A

	MOV	A, (1)+Y	; delay
	MOV	$1B0+X, A
	INC	Y
	MOV	A, (1)+Y	; interval
	MOV	$1C0+X, A
	INC	Y
	MOV	A, (1)+Y	; length
	MOV	$1D0+X, A
	INC	Y
	MOV	A, (1)+Y	; delta
	MOV	$170+X, A
	INC	Y
	MOV	A, (1)+Y	; opposite direction length
	MOV	$1E0+X, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
PitchSlideDown:	; $C09
	MOV	X, CurrentTrack
	MOV	A, $150+X
	OR	A, #1
	MOV	$150+X, A

	MOV	A, (1)+Y
	MOV	$1B0+X, A
	INC	Y
	MOV	A, (1)+Y
	MOV	$1C0+X, A
	INC	Y
	MOV	A, (1)+Y
	MOV	$1D0+X, A
	INC	Y
	MOV	A, (1)+Y
	EOR	A, #-1
	INC	A
	MOV	$170+X, A
	INC	Y
	MOV	A, (1)+Y
	MOV	$1E0+X, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
PitchSlideOff:	; $C40
	MOV	X, CurrentTrack
	MOV	A, $150+X
	AND	A, #-2
	MOV	$150+X, A
	JMP	FinishEvent
;-----------------------------------------------------------------------------
SetTempo:	; $C56
	MOV	A, (1)+Y
	MOV	BGMTempo, A
	CALL	TempoToInterval
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
AddTempo:	; $C6B
	MOV	A, (1)+Y
	CLRC
	ADC	A, BGMTempo
	MOV	BGMTempo, A
	CALL	TempoToInterval
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
Vibrato2:	; $C78
	MOV	X, CurrentTrack
	MOV	A, $150+X
	OR	A, #2
	MOV	$150+X, A

	MOV	A, (1)+Y
	MOV	$200+X, A
	INC	Y
	MOV	A, (1)+Y
	MOV	$210+X, A
	INC	Y
	MOV	A, (1)+Y
	MOV	$234+X, A
	MOV	A, #0
	MOV	$220+X, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
VibratoOff:	; $CA5
	MOV	X, CurrentTrack
	MOV	A, $150+X
	AND	A, #-3
	MOV	$150+X, A
	JMP	FinishEvent
;-----------------------------------------------------------------------------
Vibrato:	; $CB1
	MOV	X, CurrentTrack
	MOV	A, $150+X
	OR	A, #2
	MOV	$150+X, A

	MOV	A, (1)+Y	; length
	MOV	$200+X, A
	INC	Y
	MOV	A, (1)+Y	; interval
	MOV	$210+X, A
	INC	Y
	MOV	A, (1)+Y	; depth
	MOV	$234+X, A
	INC	Y
	MOV	A, (1)+Y	; delay
	MOV	$220+X, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
SetADSR:	; $CDF
	MOV	X, CurrentTrack

	MOV	A, (1)+Y
	MOV	$274+X, A
	INC	Y
	MOV	A, (1)+Y
	MOV	$284+X, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
SetMasterVolume:	; $CF9
	INC	Y
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
SetTuning:	; $D32
	MOV	X, CurrentTrack
	MOV	A, (1)+Y
	MOV	FineTune+X, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
SetTranspose:	; $D45
	MOV	X, CurrentTrack
	MOV	A, (1)+Y
	MOV	$140+X, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
AddTranspose:	; $D59
	MOV	X, CurrentTrack
	MOV	A, (1)+Y
	CLRC
	ADC	A, $140+X
	MOV	$140+X, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
SetEchoParams:	; $D71
	MOV	DSPAddr, #DSP_Feedback
	MOV	A, (1)+Y
	MOV	DSPData, A
	INC	Y

	MOV	DSPAddr, #DSP_EchoL
	MOV	A, (1)+Y
	MOV	DSPData, A
	INC	Y

	MOV	DSPAddr, #DSP_EchoR
	MOV	A, (1)+Y
	MOV	DSPData, A
	JMP	IncAndFinishEvent

	;MOV	A, #0
	;MOV	DSPFlagShadow, A
	;MOV	DSPAddr, #DSP_Flags
	;MOV	DSPData, A
	;JMP	FinishEvent
;-----------------------------------------------------------------------------
EchoOn:		; $DA0
	MOV	X, CurrentTrack
	MOV	A, #1
	MOV	$294+X, A
	JMP	FinishEvent
;-----------------------------------------------------------------------------
EchoOff:	; $DBB
	MOV	X, CurrentTrack
	MOV	A, #0
	MOV	$294+X, A
	JMP	FinishEvent
;-----------------------------------------------------------------------------
SetFIR:		; $DD8
	MOV	DSPAddr, #DSP_FIR
-
	MOV	A, (1)+Y
	MOV	DSPData, A
	INC	Y
	CLRC
	ADC	DSPAddr, #$10
	BPL	-

	JMP	FinishEvent
;-----------------------------------------------------------------------------
SetNoise:	; $DF8
	MOV	A, (1)+Y
	;MOV	NoiseShadow, A
	;OR	A, DSPFlagShadow
	MOV	DSPAddr, #DSP_Flags
	MOV	DSPData, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
NoiseOn:	; $E12
	MOV	X, CurrentTrack
	MOV	DSPAddr, #DSP_NoiseOn
	MOV	A, VoiceBitTable+X
	TSET	DSPData, A
	JMP	FinishEvent
;-----------------------------------------------------------------------------
NoiseOff:	; $E2A
	MOV	X, CurrentTrack
	MOV	DSPAddr, #DSP_NoiseOn
	MOV	A, VoiceBitTable+X
	TCLR	DSPData, A
	JMP	FinishEvent
;-----------------------------------------------------------------------------
PitchSlideDown2:	; $EA7
	MOV	X, CurrentTrack
	MOV	A, $150+X
	OR	A, #1
	MOV	$150+X, A

	MOV	A, (1)+Y
	MOV	$1B0+X, A
	INC	Y
	MOV	A, (1)+Y
	MOV	$1C0+X, A
	INC	Y
	MOV	A, (1)+Y
	MOV	$1E0+X, A
	ASL	A
	MOV	$1D0+X, A
	INC	Y
	MOV	A, (1)+Y
	EOR	A, #-1
	INC	A
	MOV	$170+X, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
PitchSlideUp2:	; $EDC
	MOV	X, CurrentTrack
	MOV	A, $150+X
	OR	A, #1
	MOV	$150+X, A

	MOV	A, (1)+Y
	MOV	$1B0+X, A
	INC	Y
	MOV	A, (1)+Y
	MOV	$1C0+X, A
	INC	Y
	MOV	A, (1)+Y
	MOV	$1E0+X, A
	ASL	A
	MOV	$1D0+X, A
	INC	Y
	MOV	A, (1)+Y
	MOV	$170+X, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
VoiceAndVolume:	; $F0E
	MOV	A, (1)+Y
	MOV	X, A
	MOV	A, TimbreLUT+X
	MOV	X, CurrentTrack
	MOV	$244+X, A
	MOV	A, #0
	MOV	FineTune+X, A
	INC	Y

	MOV	A, (1)+Y
	MOV	$254+X, A
	INC	Y
	MOV	A, (1)+Y
	MOV	$264+X, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
SetTimerFreq:	; $F60
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
LongNoteOn:	; $F72
	MOV	X, CurrentTrack
	MOV	A, #1
	MOV	$190+X, A
	JMP	FinishEvent
;-----------------------------------------------------------------------------
LongNoteOff:	; $F82
	MOV	X, CurrentTrack
	MOV	A, #0
	MOV	$190+X, A
	JMP	FinishEvent
;-----------------------------------------------------------------------------
CondJump:	; $F92
	MOV	A, Y
	MOV	Y, #0
	ADDW	YA, 1
	MOVW	3, YA

	MOV	A, BGMSwitch
	ASL	A
	INC	A
	MOV	Y, A

	MOV	A, (3)+Y
	MOV	1, A
	INC	Y
	MOV	A, (3)+Y
	MOV	2, A
	MOV	Y, #0
	JMP	FinishEvent
;-----------------------------------------------------------------------------
SetJumpCond:	; $FAC
	MOV	A, (1)+Y
	MOV	BGMSwitch, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
SetTremolo:	; $FBE
	MOV	X, CurrentTrack
	MOV	A, $150+X
	OR	A, #4
	MOV	$150+X, A

	MOV	A, (1)+Y	; length
	MOV	$2F4+X, A
	INC	Y
	MOV	A, (1)+Y	; interval
	MOV	$2C4+X, A
	INC	Y
	MOV	A, (1)+Y	; depth
	MOV	$2D4+X, A
	INC	Y
	MOV	A, (1)+Y	; delay
	MOV	$304+X, A
	MOV	A, $254+X
	MOV	$314+X, A
	MOV	A, $264+X
	MOV	$324+X, A
	JMP	IncAndFinishEvent
;-----------------------------------------------------------------------------
TremoloOff:	; $FF8
	MOV	X, CurrentTrack
	MOV	A, $150+X
	AND	A, #$FB
	MOV	$150+X, A
	JMP	FinishEvent
;-----------------------------------------------------------------------------
VoiceBitTable:	; $1004
	db	1, 2, 4, 8, $10, $20, $40, $80	; for BGM
	db	1, 2, 4, 8, $10, $20, $40, $80	; for SFX
TrackEventTable:	; $1014
	; See https://loveemu.hatenablog.com/entry/20130819/SNES_Rare_Music_Spec for details
	dw	EndOfTrack	; $A6E	; individual effect
	dw	SetVoice	; $ABA	; individual effect (no rest required)
	dw	SetVolume	; $AE3	; individual effect (no rest required)
	dw	JumpTrack	; $B14	; individual effect (no rest required)
	dw	CallSub		; $B29	; individual effect (no rest required)
	dw	RetSub		; $B5E	; individual effect (no rest required)
	dw	DefaultDurOn	; $BA4	; individual effect (no rest required)
	dw	DefaultDurOff	; $BC9	; individual effect (no rest required)
	dw	PitchSlideUp	; $BD5	; individual effect
	dw	PitchSlideDown	; $C09	; individual effect
	dw	PitchSlideOff	; $C40	; individual effect
	dw	SetTempo	; $C56	; global effect
	dw	AddTempo	; $C6B	; global effect
	dw	Vibrato2	; $C78	; individual effect
	dw	VibratoOff	; $CA5	; individual effect
	dw	Vibrato		; $CB1	; individual effect
	dw	SetADSR		; $CDF	; individual effect (no rest required)
	dw	SetMasterVolume	; $CF9	; individual effect (no rest required)
	dw	SetTuning	; $D32	; individual effect (no rest required)
	dw	SetTranspose	; $D45	; individual effect (no rest required)
	dw	AddTranspose	; $D59	; individual effect (no rest required)
	dw	SetEchoParams	; $D71	; global effect
	dw	EchoOn		; $DA0	; individual effect (no rest required)
	dw	EchoOff		; $DBB	; individual effect (no rest required)
	dw	SetFIR		; $DD8	; global effect
	dw	SetNoise	; $DF8	; global effect
	dw	NoiseOn		; $E12	; individual effect
	dw	NoiseOff	; $E2A	; individual effect
	dw	0	; global effect
	dw	0	; global effect
	dw	0	; global effect
	dw	0	; global effect
	dw	0	; global effect
	dw	0	; global effect
	dw	0	; global effect
	dw	0	; global effect
	dw	0	; global effect
	dw	0	; global effect
	dw	PitchSlideDown2	; $EA7	; individual effect
	dw	PitchSlideUp2	; $EDC	; individual effect
	dw	VoiceAndVolume	; $F0E	; individual effect (no rest required)
	dw	0	; global effect
	dw	SetTimerFreq	; $F60	; individual effect (no rest required)
	dw	LongNoteOn	; $F72	; individual effect (no rest required)
	dw	LongNoteOff	; $F82	; individual effect (no rest required)
	dw	CondJump	; $F92	; global effect
	dw	SetJumpCond	; $FAC	; global effect
	dw	SetTremolo	; $FBE	; individual effect
	dw	TremoloOff	; $FF8	; individual effect
EventTypeTable:
	db	1	; individual effect
	db	-1	; individual effect (no rest required)
	db	-1	; individual effect (no rest required)
	db	-1	; individual effect (no rest required)
	db	-1	; individual effect (no rest required)
	db	-1	; individual effect (no rest required)
	db	-1	; individual effect (no rest required)
	db	-1	; individual effect (no rest required)
	db	1	; individual effect
	db	1	; individual effect
	db	1	; individual effect
	db	0	; global effect
	db	0	; global effect
	db	1	; individual effect
	db	1	; individual effect
	db	1	; individual effect
	db	-1	; individual effect (no rest required)
	db	-1	; individual effect (no rest required)
	db	-1	; individual effect (no rest required)
	db	-1	; individual effect (no rest required)
	db	-1	; individual effect (no rest required)
	db	0	; global effect
	db	-1	; individual effect (no rest required)
	db	-1	; individual effect (no rest required)
	db	0	; global effect
	db	0	; global effect
	db	1	; individual effect
	db	1	; individual effect
	db	0	; global effect
	db	0	; global effect
	db	0	; global effect
	db	0	; global effect
	db	0	; global effect
	db	0	; global effect
	db	0	; global effect
	db	0	; global effect
	db	0	; global effect
	db	0	; global effect
	db	1	; individual effect
	db	1	; individual effect
	db	-1	; individual effect (no rest required)
	db	0	; global effect
	db	-1	; individual effect (no rest required)
	db	-1	; individual effect (no rest required)
	db	-1	; individual effect (no rest required)
	db	0	; global effect
	db	0	; global effect
	db	1	; individual effect
	db	1	; individual effect
;-----------------------------------------------------------------------------
WaitForEcho:
	MOV	A, #1
	MOV	$8700, A
-	MOV	A, $8700
	BNE	-
	RET
;-----------------------------------------------------------------------------
SetUpEngine:	; $1076
	MOV	A, #0
	BBC3	GlobalFlags, +	; skip some init on warm reset

	MOV	DSPAddr, #$D	; echo feedback
	MOV	DSPData, A
	MOV	DSPAddr, #$4D	; echo enable
	MOV	DSPData, A

	MOV	DSPAddr, #$7D	; echo delay
	MOV	DSPData, A	; set the echo delay to 0 ms
	MOV	DSPAddr, #$6D	; echo buffer location
	MOV	DSPData, #$87	; = $8700..$8703

	MOV	DSPAddr, #DSP_Flags
	MOV	DSPData, #$C0
	CALL	WaitForEcho
	CALL	WaitForEcho
	; Here, A equals 0

	MOV	DSPAddr, #$6D	; echo buffer location
	MOV	DSPData, #$DF	; = $DF00..$FEFF
	MOV	DSPAddr, #$7D	; echo delay
	MOV	DSPData, #4	; set the echo delay to 4*16=64 ms

	MOV	DSPAddr, #$C	; master left volume
	MOV	DSPData, #64
	MOV	DSPAddr, #$1C	; master right volume
	MOV	DSPData, #64
	MOV	DSPAddr, #$2D	; pitch modulation
	MOV	DSPData, A
	MOV	DSPAddr, #$5D	; source directory (instrument table)
	MOV	DSPData, #$32	; =$3200

	MOV	Timer0, #1
	MOV	Timer1, #20	; 2.5 ms | 400 Hz
	MOV	HWControl, #3

+	MOV	DSPAddr, #$2C	; echo left volume
	MOV	DSPData, A	; ...is set to 0
	MOV	DSPAddr, #$3C	; echo right volume
	MOV	DSPData, A	; ...is set to 0
	MOV	DSPAddr, #$3D	; noise enable
	MOV	DSPData, A
	MOV	DSPAddr, #DSP_Flags
	MOV	DSPData, A

	MOV	GlobalFlags, A
	MOV	Timer0Ticks, A
	MOV	Timer1Ticks, A
	MOV	SFXDivCounter, #1
	MOV	MiscDivCounter, #1
	MOV	KeyOnShadow, A
	MOV	BGMSwitch, A

	MOV	1, #8
	MOV	X, A
	MOV	Y, A
	MOV	2, Y

	; $1128
-	MOV	A, #1
	MOV	NoteLen_L+X, A
	MOV	$110+X, A
	MOV	A, MusicData+Y
	MOV	TrackPtr_L+X, A
	MOV	A, MusicData+1+Y
	MOV	TrackPtr_H+X, A
	MOV	A, 2
	MOV	SndStackPtr+X, A
	MOV	A, #0
	MOV	$190+X, A
	MOV	NoteLen_H+X, A
	MOV	$120+X, A
	MOV	$130+X, A
	MOV	$150+X, A
	MOV	FineTune+X, A
	MOV	$140+X, A
	MOV	$1A0+X, A
	MOV	$294+X, A
	MOV	$110+8+X, A
	MOV	A, #$8E
	MOV	$274+X, A
	MOV	A, #$C1
	MOV	$284+X, A

	INC	X
	INC	Y
	INC	Y
	CLRC
	ADC	2, #8
	DBNZ	1, -

	MOV	A, MusicData+16
	MOV	BGMTempo, A
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
;-----------------------------------------------------------------------------
PlaySFX:	; $1178
	ASL	A
	PUSH	A
	CALL	SoftKeyRelease2
	MOV	A, #1
	MOV	$1A0+X, A
	MOV	A, $150+X
	AND	A, #$3F
	MOV	$150+X, A
	MOV	DSPAddr, #DSP_NoiseOn
	MOV	A, VoiceBitTable+X
	TCLR	DSPData, A
	MOV	A, X
	OR	A, #8
	MOV	X, A
	ASL	A
	ASL	A
	ASL	A
	MOV	SndStackPtr+X, A
	MOV	A, #1
	MOV	$110+X, A
	MOV	A, #0
	MOV	$120+X, A
	MOV	$130+X, A
	MOV	NoteLen_H+X, A
	MOV	$190+X, A
	MOV	$1A0+X, A
	MOV	$150+X, A
	MOV	$140+X, A
	MOV	FineTune+X, A
	MOV	$274+X, A
	MOV	$284+X, A
	MOV	$294+X, A
	MOV	A, #127
	MOV	$254+X, A
	MOV	$264+X, A
	MOV	$314+X, A
	MOV	$324+X, A
	POP	Y
	MOV	A, SFXData+Y
	MOV	TrackPtr_L+X, A
	INC	Y
	MOV	A, SFXData+Y
	MOV	TrackPtr_H+X, A
	MOV	A, #2
	MOV	NoteLen_L+X, A
	RET
;-----------------------------------------------------------------------------
PitchTable:	; $11E6
	dw	484
	dw	512,	543,	575,	609,	646,	684
	dw	725,	768,	813,	862,	913,	967
	dw	1024,	1085,	1150,	1218,	1291,	1367
	dw	1449,	1535,	1626,	1723,	1825,	1934
	dw	2048,	2170,	2299,	2436,	2581,	2734
	dw	2897,	3069,	3251,	3445,	3650,	3867
	dw	4096,	4340,	4598,	4871,	5161,	5468
	dw	5793,	6138,	6502,	6889,	7299,	7733
	dw	8192,	8680,	9196,	9742,	10322,	10936
	dw	11586,	12275,	13004,	13778,	14597,	15465
	dw	16383,	8680,	9196,	9742,	10322,	10936
	dw	11586,	12275,	13004,	13778,	14597,	15465

