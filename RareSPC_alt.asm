; Modified Rare's Donkey Kong Country sound engine.
; Based on Donkey Kong Country sound engine disassembly.
; Author: PoteznaSowa.

; Some changes included in the mod:
; - optimised code, unused features removed, data transfer sped up;
; - added preprocessing of sound sequence data in background;
; - music runs at variable SPC timer period instead of
;   using a single fixed-period timer in the original design;
; - removed mixing-out stereo which is anyway not used in the game

hirom

; Page 0 variables
	ORG	0
_S0:	skip 1	; scratch RAM for intermediate data
_S1:	skip 1
_S2:	skip 1
_S3:	skip 1
_S4:	skip 1
_S5:	skip 1
TempFlags:	skip 1
CurrentTrack:	skip 1
CurVoiceBit:	skip 1
CurVoiceAddr:	skip 1
KeyOnShadow:	skip 1	; key-on bitmask

PrevMsg:		skip 1

; 0: engine is running
; 1: halve BGM tempo
; 2: if bit 1 is set, skip BGM updates
; 3: events are being preprocessed
; 4: cold reset
GlobalFlags:	skip 1

CurPreprocTrack:	skip 1	; number of channel to be preprocessed

BGMTempo:	skip 1
Timer0Ticks:	skip 1
Timer1Ticks:	skip 1
SFXDivCounter:		skip 1	; must be 1..8
MiscDivCounter:		skip 1	; must be 1..5

	ORG	$20

; 0: active
; 1: long duration on
; 2: echo on
; 3: noise on
; 5: overridden by SFX
; 6: already ready for key-on
; 7: track audible (no rest)
SndFlags:	skip 16

NoteDur_L:	skip 16	; 16-bit duration
NoteDur_H:	skip 16
TrkPtr_L:	skip 16	; track pointer
TrkPtr_H:	skip 16
SndTimbre:	skip 16	; instrument
SndFineTune:	skip 16	; pitch tuning
t_PitchSlideTimer:	skip 16	; pitch slide timer
t_PitchSlideSteps:	skip 16	; pitch slide steps left
t_VibTimer:	skip 16	; vibrato interval timeout
t_VibSteps:	skip 16	; vibrato cycle steps left
t_TremTimer:	skip 16
SndStackPtr:	skip 16	; current stack pointer


; Memory-mapped hardware registers, also in page 0
	ORG	$F1
ControlReg:	skip 1
DSPAddr:	skip 1
DSPData:	skip 1
Port0:	skip 1
Port1:	skip 1
Port2:	skip 1
Port3:	skip 1
IOUnused0:	skip 1	; can be used as RAM
IOUnused1:	skip 1	; can be used as RAM
Timer0:		skip 1
Timer1:		skip 1
Timer2:		skip 1
Timer0_out:	skip 1
Timer1_out:	skip 1
Timer2_out:	skip 1

; Direct page 1 variables
			skip 16
Transpose:	skip 16	; signed pitch offset in semitones

; S-DSP sound parameters
SndVol_L:	skip 16	; left channel volume
SndVol_R:	skip 16	; right channel volume
SndADSR1:	skip 16	; ADSR 1 value
SndADSR2:	skip 16	; ADSR 2 value

t_PitchSlideDelay:	skip 16	; pitch slide delay timeout
t_VibDelay:	skip 16	; vibrato delay timeout
t_PitchSlideStepsDown:	skip 16	; pitch slide down steps left

DfltNoteDur_L:	skip 16	; Current default duration.
DfltNoteDur_H:	skip 16

PitchSlideDelay:	skip 16	; stored pitch slide delay
PitchSlideInterval:	skip 16	; stored pitch slide interval (time between steps)
PitchSlideSteps:	skip 16	; stored total pitch slide steps
PitchSlideStepsDown:	skip 16	; stored pitch slide steps in opposite direction
PitchSlideDelta:	skip 16	; pitch slide pitch delta (linear, signed)

VibDelay:	skip 16	; stored vibrato delay
VibLen:		skip 16	; steps per vibrato cycle
VibInterval:	skip 16	; stored vibrato interval (time between steps) 
VibDelta:	skip 16	; vibrato pitch delta (linear, signed)

SndEnvLvl:	skip 16	; current ADSR envelope level

t_TremDelay:		skip 16	; $2A4
TremInterval:		skip 16	; $2C4
TremDelta:		skip 16	; $2D4
t_TremLen:		skip 16	; $2E4
TremLen:		skip 16	; $2F4
TremDelay:		skip 16	; $304

; Subroutine stack. The maximum nest level is 8.
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

; External data locations.
SoundEntryPnt =		$5E8
MusicData =		$12A0
SFXData	=		$2380
SourceDir =		$3200
EchoBuffer =		$DF00

	arch spc700
	optimize dp always

	ORG	$8AA342
	base	$4B8
; -----------------------------------------------------------------------------
	MOV	Y, Port0
	SET4	GlobalFlags
	MOV	X, #0			; clear X
	MOV	DSPAddr, #$7D
	MOV	DSPData, X		; set the echo delay to 0 ms
TransferMode:
-	CMP	Y, Port0		; has SNES sent next data?
	BEQ	-			; repeat if not
	MOV	Y, Port0		; load message ID into Y
	BBC0	Port0, +		; if it is even, branch

	MOV	A, Port1		; read data byte
	MOV	(Port2+X), A		; store it at the address from IOPort2
	MOV	Port0, Y		; reply to SNES
	JMP	-			; retry
; -----------------------------------------------------------------------------
+	MOV	Port0, Y
	MOV	PrevMsg, Y
	JMP	ProgramStart
; -----------------------------------------------------------------------------
	rep 12 : db 0	; must be at least 8
; -----------------------------------------------------------------------------
TimbreLUT:
	rep 256 : db 0
; =============================================================================
ProgramStart:
	MOV	Port1, #$FF	; indicate for SNES that engine is ready
	MOV	X, #$F
	MOV	SP, X	; SP = $010F
	CALL	SetUpEngine

GetMessage:	; $606
	CMP	Port0, PrevMsg	; has SNES sent next message?
	BEQ	MainLoop	; branch if no
GetMessage2:
	MOV	A, Port1	; read message
	MOV	X, Port2
	MOV	Y, Port0	; read messsage ID again
	MOV	Port0, Y	; reply to SNES
	MOV	PrevMsg, Y	; store message ID

	CMP	A, #$FF
	BEQ	GotoTransferMode
	CMP	A, #$FE
	BEQ	StartSound
	;CMP	A, #$FD
	;BEQ	SetBGMSwitch
	;CMP	A, #$FC
	;BEQ	SetMonoFlag

	; play SFX
	CALL	PlaySFX
	JMP	GetMessage
; -----------------------------------------------------------------------------
;SetBGMSwitch:
;SetMonoFlag:
;	JMP	GetMessage
;	JMP	GetMessage
; -----------------------------------------------------------------------------
GotoTransferMode:	; $71F
	MOV	X, #0
	MOV	Port1, X	; Tell SNES we are in transfer mode.

	; Set all channels to fade out.
	MOV	DSPAddr, #7
	CLRC
-	MOV	DSPData, #$BF	; Exponential fade-out, rate 15
	CLR1	DSPAddr
	CLR7	DSPData
	ADC	DSPAddr, #$12
	BPL	-

	; Fade out echo feedback.
	MOV	DSPAddr, #$D
	MOV	A, DSPData
	BPL	+
-	INC	DSPData
	BNE	-
	JMP	++
; -----------------------------------------------------------------------------
+	BEQ	++
-	DBNZ	DSPData, -
++

	; Wait until all channels fade out.
	MOV	DSPAddr, #8
-	MOV	A, DSPData
	BNE	-
	ADC	DSPAddr, #$10
	BPL	-

	JMP	TransferMode
; -----------------------------------------------------------------------------
StartSound:	; $643
	SET0	GlobalFlags
	CALL	TempoToInterval2
-	CALL	PreprocessTracks2
	BBC3	CurPreprocTrack, -
	MOV	ControlReg, #3	; Start timers 0 and 1.
	JMP	GetMessage
; =============================================================================
MainLoop:	; $649
	BBC0	GlobalFlags, PreprocessTracks

	CLRC
	ADC	Timer0Ticks, Timer0_out	; has the BGM timer ticked?
	BEQ	SkipBGMUpdate		; branch if no

UpdateBGM:
	BBC1	GlobalFlags, +	; Branch if tempo not halved.
	BBS2	GlobalFlags, ++	; Skip updates every second tick.

+	MOV	CurrentTrack, #0
	CALL	UpdateTracks

++	DEC	Timer0Ticks
	EOR	GlobalFlags, #4	; Toggle the "skip tick" flag.

SkipBGMUpdate:
	CMP	Port0, PrevMsg	; has SNES sent next message?
	BNE	GetMessage2	; branch if yes

	CLRC
	ADC	Timer1Ticks, Timer1_out	; has the main timer ticked?
	BEQ	PreprocessTracks	; branch if no

UpdateSFX:
	DBNZ	SFXDivCounter, +
	MOV	SFXDivCounter, #8

	MOV	CurrentTrack, #8
	CALL	UpdateTracks

+	DBNZ	MiscDivCounter, FinishSFX
	MOV	MiscDivCounter, #5

	MOV	CurrentTrack, #0
	MOV	DSPAddr, #0	; Go to channel #0 volume
	JMP	+	; Loop optimisation. Saves 10 cycles.
; -----------------------------------------------------------------------------
UpdateTracks2:
	CLR3	CurrentTrack	; revert to BGM
	INC	CurrentTrack
	AND	DSPAddr, #$70
	
+	CALL	UpdateTrack2	; update pitch bend
	ADC	DSPAddr, #$10	; Go to next channel.
	BPL	UpdateTracks2	; ...if any.

FinishSFX:
	DEC	Timer1Ticks

; If we have finished all pending tasks above, try to asynchronously process
; sound data for each channel in a round-robin manner.
; Why are we doing this?
; Occasionally, we may run into a large number of sound control events which
; take lots of time to process, making the sound stall a little bit.
; Instead of wasting cycles while busy-waiting for timers and messages from
; SNES, we can spend our idle time by performing time-consuming tasks such as
; processing the events and preparing to play a note, whenever we can.
; The result is much less lag and thus smoother rhythm.
PreprocessTracks:
	CMP	Port0, PrevMsg	; has SNES sent next message?
	BNE	++		; branch if yes

	BBC0	GlobalFlags, +

	CLRC
	ADC	Timer0Ticks, Timer0_out	; has the BGM timer ticked?
	BNE	UpdateBGM		; branch if yes
	ADC	Timer1Ticks, Timer1_out	; has the main timer ticked?
	BNE	UpdateSFX		; branch if yes

+	CALL	PreprocessTracks2
++	JMP	GetMessage
; =============================================================================
PreprocessTracks2:
	CLR4	CurPreprocTrack
	MOV	X, CurPreprocTrack
	INC	CurPreprocTrack

	MOV	A, SndFlags+X	; Load track flags.
	MOV	TempFlags, A
	BBC0	TempFlags, SkipPreproc	; branch if not active

	; Prepare the DSP address and voice bitmask variables.
	; Also, access the ENVX register.
	MOV	A, X
	AND	A, #7	; Limit to 0..7.
	MOV	Y, A
	XCN	A	; A <<= 4
	MOV	CurVoiceAddr, A	; We have a DSP channel address.
	OR	A, #8		; Go to ENVX register.
	MOV	DSPAddr, A
	MOV	A, VoiceBitMask+Y	; Get the bitmask for the channel.
	MOV	CurVoiceBit, A

	MOV	A, DSPData	; Read the current ADSR envelope level.
	CMP	A, SndEnvLvl+X	; Compare with the level measured earlier.
	MOV	SndEnvLvl+X, A	; Store it.
	BCS	+	; Branch if the envelope does not ramp down.
	MOV	Y, A	; Did it reach zero though?
	BNE	+	; Branch if not.
	CLR7	TempFlags	; Clear the "channel audible" flag.

+	MOV	CurrentTrack, X
	MOV	A, TrkPtr_L+X	; load the track pointer
	MOV	Y, TrkPtr_H+X
	MOVW	0, YA
	MOV	Y, #0
	MOV	A, (0)+Y		; read a track byte
	BMI	Preproc_RestOrNote	; branch if this is a note or rest
	;CMP	A, #$33
	;BCS	FinishPreproc	; branch on invalid data
	MOV	2, A		; Preserve the event type.
	MOV	Y, A
	MOV	A, EventTypeTable+Y	; check the type of the sound event
	BMI	+		; branch if it can be run without any trouble
	BEQ	FinishPreproc	; branch if it must always be run synchronously
	BBS7	TempFlags, FinishPreproc	; Branch if the track is audible.

+	SET3	GlobalFlags	; Set the "async sound events" flag.
	MOV	Y, #1	; Go to the next track byte.
	MOV	A, 2
	ASL	A
	MOV	X, A
	JMP	(TrackEventTable+X)	; run the sound event
; -----------------------------------------------------------------------------
Preproc_RestOrNote:
	BBS6	TempFlags, FinishPreproc	; Branch if ready for key-on.
	BBS7	TempFlags, FinishPreproc	; Branch if audible.

	CMP	A, #$80
	BEQ	Preproc_Rest

	BBS5	TempFlags, FinishPreproc	; Branch if the channel in use by SFX.

	CALL	PrepareNote	; Prepare a note for key-on.

	SET6	TempFlags	; Set the "ready for key-on" flag.
FinishPreproc:
	MOV	A, TempFlags	; Save track flags.
	MOV	SndFlags+X, A
SkipPreproc:
	RET
; -----------------------------------------------------------------------------
Preproc_Rest:
	INC	Y	; proceed to the next track byte
	MOV	A, DfltNoteDur_L+X	; is default note duration set?
	BEQ	+		; branch if not
	MOV	2, A	; set duration LSB
	MOV	A, DfltNoteDur_H+X
	MOV	3, A	; set duration MSB
	JMP	++
; -----------------------------------------------------------------------------
+	MOV	A, #0		; Placeholder value.
	BBC1	TempFlags, +	; Branch if long duration mode off.
	MOV	A, (0)+Y	; Get duration MSB.
	INC	Y
+	MOV	3, A
	MOV	A, (0)+Y	; Get duration LSB.
	MOV	2, A
	INC	Y
++	MOV	4, Y	; Preserve the track data offset.
	MOV	A, NoteDur_L+X
	MOV	Y, NoteDur_H+X
	ADDW	YA, 2	; Add the rest length to the current rest duration.
	BCS	FinishPreproc	; Branch if the result does not fit into 16 bits.
	MOV	NoteDur_L+X, A	; Store the result.
	MOV	NoteDur_H+X, Y
	MOV	A, 4
	MOV	Y, #0
	ADDW	YA, 0	; Add the track offset the pointer.
	MOV	TrkPtr_L+X, A	; store pointer LSB
	MOV	TrkPtr_H+X, Y	; store pointer MSB
	JMP	FinishPreproc
; =============================================================================
SoftKeyRelease:
	BBS5	TempFlags, +	; Skip if channel in use by SFX.
	BBS6	TempFlags, +	; Skip if a note is ready for key-on.
	MOV	A, CurVoiceAddr
	OR	A, #7
	MOV	Y, #$BF		; Exponential fade-out, rate 15
	MOVW	DSPAddr, YA
	CLR1	DSPAddr
	CLR7	DSPData
	MOV	A, #127
	MOV	SndEnvLvl+X, A
+	RET
; =============================================================================
TempoToInterval2:
	MOV	A, BGMTempo

; Convert BGM tempo at register A to a timer period.
; Period=25600/Tempo
TempoToInterval:
	CLR1	GlobalFlags	; Clear the "halve BGM tempo" flag.
	MOV	2, Y	; Preserve Y.
	MOV	X, A
	MOV	A, #0
	MOV	Y, #$64	; YA = 25600
	DIV	YA, X
	BVC	+	; branch if quotient < 256
	SETC
	ROR	A	; A = (A >> 1) | $80
	SET1	GlobalFlags	; Clear the "halve BGM tempo" flag.
+	MOV	Timer0, A
	MOV	Y, 2
	RET
; =============================================================================
UpdateTracks:
	; Initialise variables for channel #0.
	MOV	CurVoiceBit, #1
	MOV	CurVoiceAddr, #0
	MOV	KeyOnShadow, #0
	CLR3	GlobalFlags
	JMP	+	; Loop optimisation. Saves 6 cycles.
; -----------------------------------------------------------------------------
NextTrack:
	ADC	CurVoiceAddr, #$10
	INC	CurrentTrack

+	MOV	X, CurrentTrack

	MOV	A, SndFlags+X	; Load track flags.
	MOV	TempFlags, A
	BBC0	TempFlags, FinishTrackUpdate	; Branch if track inactive.

	MOV	Y, NoteDur_L+X
	CMP	Y, #3
	BCS	ContinueNote
	MOV	A, NoteDur_H+X
	CMP	A, #1		; C = (A >= 1)
	DEC	Y
	BPL	+
	BCC	FetchNextEvent
	DEC	NoteDur_H+X
	JMP	ContinueNote
; -----------------------------------------------------------------------------
+	BCS	ContinueNote
	BEQ	FetchNextEvent
	CALL	SoftKeyRelease
ContinueNote:
	DEC	NoteDur_L+X
FinishTrackUpdate:
	ASL	CurVoiceBit	; Go to the next track.
	BCC	NextTrack	; ...if any.

	; Now write the key-on mask to the DSP.
	MOV	Y, KeyOnShadow
	BEQ	+	; Do not bother if nothing to key-on.
	MOV	DSPAddr, #$5C
	MOV	DSPData, #0
	MOV	A, #$4C
	MOVW	DSPAddr, YA
+	RET
; -----------------------------------------------------------------------------
FetchNextEvent:
	CALL	SoftKeyRelease
	MOV	A, TrkPtr_L+X	; Load track data pointer.
	MOV	Y, TrkPtr_H+X
	MOVW	0, YA
	MOV	Y, #0
	BBS6	TempFlags, TriggerNote	; Branch if ready for key-on.
FetchNextEvent2:
	MOV	A, (0)+Y
	BMI	GotNote	; Branch on note/rest.
	INC	Y	; Go to the next byte.
	ASL	A
	MOV	X, A
	JMP	(TrackEventTable+X)	; Run an event handler.
; =============================================================================
SetMasterVolume:	; dummied out
	INC	Y
SetTimerFreq:		; dummied out
SetJumpCond:		; dummied out
IncAndFinishEvent:
	INC	Y
FinishEvent:
	BBC3	GlobalFlags, FetchNextEvent2

	MOV	X, CurrentTrack
	MOV	A, Y
	MOV	Y, #0
	ADDW	YA, 0
	MOV	TrkPtr_L+X, A	; store pointer LSB
	MOV	TrkPtr_H+X, Y	; store pointer MSB
	DEC	CurPreprocTrack		; Process the track again.
	MOV	A, TempFlags		; Store the flags.
	MOV	SndFlags+X, A
	RET
; =============================================================================
GotNote:
	MOV	X, CurrentTrack
	BBS5	TempFlags, SetDuration
	CMP	A, #$80			; is the event a rest?
	BEQ	SetDuration		; if yes, branch

	MOV	5, Y	; Preserve Y.
	CALL	PrepareNote
	MOV	Y, 5
TriggerNote:
	OR	KeyOnShadow, CurVoiceBit
	CLR6	TempFlags
	SET7	TempFlags	; Set the "track audible" flag.
	MOV	A, #0
	MOV	SndEnvLvl+X, A

SetDuration:
	INC	Y
	MOV	A, DfltNoteDur_L+X	; is default note duration set?
	BEQ	+		; branch if not
	MOV	NoteDur_L+X, A	; set duration LSB
	MOV	A, DfltNoteDur_H+X
	MOV	NoteDur_H+X, A	; set duration MSB
	JMP	++
; -----------------------------------------------------------------------------
+	BBC1	TempFlags, +	; Branch if long duration mode off.
	MOV	A, (0)+Y	; get duration MSB
	MOV	NoteDur_H+X, A
	INC	Y
+	MOV	A, (0)+Y	; get duration LSB
	MOV	NoteDur_L+X, A
	INC	Y

++	MOV	A, Y
	MOV	Y, #0
	ADDW	YA, 0
	MOV	TrkPtr_L+X, A	; store pointer LSB
	MOV	TrkPtr_H+X, Y	; store pointer MSB
	MOV	A, TempFlags
	MOV	SndFlags+X, A
	JMP	FinishTrackUpdate
; =============================================================================
PrepareNote:
	MOV	DSPAddr, #$5C
	MOV	DSPData, CurVoiceBit	; Key-off the channel.

	; calculate pitch
	; Note: maximum range is 5 octaves
	CLRC
	ADC	A, Transpose+X
	ASL	A

	; fine-tune given pitch P with current signed fine-tune value T by the
	; following formula:
	; P=P*(1024+T)/1024
	MOV	Y, SndFineTune+X	; is fine-tune value zero?
	BEQ	SkipTuning	; if yes, branch
	MOV	X, A
	MOV	4, Y	; Store the original fine-tune value.
	MOV	A, Y
	BPL	+	; Y = abs(Y)
	EOR	A, #-1
	INC	A
	MOV	Y, A
+	MOV	3, Y
	MOV	A, PitchTable+X	; read LSB of base pitch value
	MUL	YA	; multiple it with fine-tune value
	MOV	2, Y	; store MSB of the result as LSB of pitch offset
	MOV	Y, 3	; get fine-tune multiplier again
	MOV	3, #0	; clear MSB of pitch offset
	MOV	A, PitchTable+1+X	; read MSB of base pitch value
	MUL	YA	; multiple it with fine-tune value
	ADDW	YA, 2	; add pitch offset to the result
	MOV	3, Y	; store MSB of the result as MSB of the variable
	LSR	3	; divide the result by 4
	ROR	A
	LSR	3
	ROR	A
	MOV	2, A	; store LSB of the result as LSB of pitch offset
	MOV	A, PitchTable+1+X	; read LSB of seed pitch value
	MOV	Y, A	
	MOV	A, PitchTable+X	; read MSB of seed pitch value
	BBS7	4, +	; branch on negative fine-tune
	ADDW	YA, 2	; add given pitch offset to seed pitch
	JMP	TuningDone
; -----------------------------------------------------------------------------
+	SUBW	YA, 2	; subtract given pitch offset from seed pitch
	JMP	TuningDone
; -----------------------------------------------------------------------------
SkipTuning:
	; simply get the pitch value from the table
	MOV	X, A
	MOV	A, PitchTable+1+X
	MOV	Y, A
	MOV	A, PitchTable+X
TuningDone:
	MOVW	2, YA	; Now we have the pitch value.
	MOV	X, CurrentTrack

	; Copy initial pitch slide parameters.
	MOV	A, PitchSlideDelay+X	; delay
	MOV	t_PitchSlideDelay+X, A
	MOV	A, PitchSlideInterval+X	; interval
	MOV	t_PitchSlideTimer+X, A
	MOV	A, PitchSlideSteps+X	; total up/down steps
	MOV	t_PitchSlideSteps+X, A
	MOV	A, PitchSlideStepsDown+X	; steps of going down
	MOV	t_PitchSlideStepsDown+X, A

	; Copy initial vibrato parameters.
	MOV	A, VibDelta+X
	BPL	+	; Delta=abs(Delta)
	EOR	A, #-1
	INC	A
	MOV	VibDelta+X, A
+	MOV	A, VibLen+X	; cycle length
	LSR	A	; divide it by 2
	MOV	t_VibSteps+X, A
	MOV	A, VibInterval+X	; interval
	MOV	t_VibTimer+X, A
	MOV	A, VibDelay+X	; delay
	MOV	t_VibDelay+X, A

	; Copy initial tremolo parameters.
	MOV	A, TremDelta+X
	BPL	+	; Delta=abs(Delta)
	EOR	A, #-1
	INC	A
	MOV	TremDelta+X, A
+	MOV	A, TremLen+X
	LSR	A
	MOV	t_TremLen+X, A
	MOV	A, TremInterval+X
	MOV	t_TremTimer+X, A
	MOV	A, TremDelay+X
	MOV	t_TremDelay+X, A

	; write current sound parameters into DSP
	MOV	DSPAddr, CurVoiceAddr

	MOV	A, SndVol_L+X
	MOV	DSPData, A	; left channel volume
	INC	DSPAddr
	MOV	A, SndVol_R+X
	MOV	DSPData, A	; right channel volume
	INC	DSPAddr
	MOV	A, 2
	MOV	DSPData, A	; LSB of pitch value
	INC	DSPAddr
	MOV	A, 3
	MOV	DSPData, A	; MSB of pitch value
	INC	DSPAddr
	MOV	Y, SndTimbre+X
	MOV	A, TimbreLUT+Y
	MOV	DSPData, A	; Source number
	INC	DSPAddr
	MOV	A, SndADSR1+X
	MOV	DSPData, A	; ADSR 1
	INC	DSPAddr
	MOV	A, SndADSR2+X
	MOV	DSPData, A	; ADSR 2
	INC	DSPAddr
	MOV	DSPData, #127	; GAIN value if ADSR is disabled

	MOV	DSPAddr, #$4D
	MOV	A, DSPData
	OR	A, CurVoiceBit
	BBS2	TempFlags, +
	EOR	A, CurVoiceBit	; disable echo
+	MOV	DSPData, A

	MOV	DSPAddr, #$3D
	MOV	A, DSPData
	OR	A, CurVoiceBit
	BBS3	TempFlags, +
	EOR	A, CurVoiceBit	; disable noise
+	MOV	DSPData, A

	RET
; =============================================================================
UpdateTrack2:	; $91C
	MOV	X, CurrentTrack
	MOV	A, SndFlags+X
	AND	A, #$20		; is the channel used by SFX?
	BEQ	+		; branch if no
	SET3	CurrentTrack	; process a SFX channel instead
	MOV	X, CurrentTrack
+	MOV	A, SndFlags+X
	BMI	+
	RET
; -----------------------------------------------------------------------------
+	MOV	A, t_TremDelay+X
	BEQ	+
	DEC	A
	MOV	t_TremDelay+X, A
	JMP	FinishTremolo
; -----------------------------------------------------------------------------
+	DEC	t_TremTimer+X
	BNE	FinishTremolo
	MOV	A, TremInterval+X
	MOV	t_TremTimer+X, A

	MOV	A, TremDelta+X
	MOV	0, A
	CLRC
	ADC	DSPData, 0
	INC	DSPAddr
	CLRC
	ADC	DSPData, 0

	MOV	A, t_TremLen+X
	DEC	A
	MOV	t_TremLen+X, A
	BNE	FinishTremolo
	MOV	A, TremLen+X
	MOV	t_TremLen+X, A
	MOV	A, TremDelta+X
	EOR	A, #-1
	INC	A
	MOV	TremDelta+X, A
FinishTremolo:
	CLR0	DSPAddr
	SET1	DSPAddr

	MOV	A, #0
	MOV	Y, A
	MOVW	0, YA	; Set the initial delta to 0.

	MOV	A, t_PitchSlideDelay+X
	BEQ	loc_9DA
	CMP	A, #-1
	BEQ	loc_A39		; Branch if pitch slide finished.
	DEC	A
	MOV	t_PitchSlideDelay+X, A
	BNE	loc_A39
	MOV	A, #1
	MOV	t_PitchSlideTimer+X, A
loc_9DA:
	DEC	t_PitchSlideTimer+X
	BNE	loc_A39
	MOV	A, PitchSlideInterval+X
	MOV	t_PitchSlideTimer+X, A

	;MOV	Y, #0
	MOV	A, t_PitchSlideStepsDown+X
	BEQ	+
	DEC	A
	MOV	t_PitchSlideStepsDown+X, A

	MOV	A, PitchSlideDelta+X	; get pitch offset
	EOR	A, #-1		; negate it
	INC	A
	JMP	++
; -----------------------------------------------------------------------------
+	MOV	A, PitchSlideDelta+X
++	BPL	+		; sign-extend it
	DEC	Y
+	MOVW	0, YA	; Store the delta.

	DEC	t_PitchSlideSteps+X
	BNE	loc_A39
	MOV	A, #-1
	MOV	t_PitchSlideDelay+X, A

loc_A39:
	MOV	A, t_VibDelay+X
	BEQ	loc_A48
	DEC	A
	MOV	t_VibDelay+X, A
	JMP	loc_AB4
; -----------------------------------------------------------------------------
loc_A48:
	DEC	t_VibTimer+X
	BNE	loc_AB4
	MOV	A, VibInterval+X
	MOV	t_VibTimer+X, A

	MOV	Y, #0
	MOV	A, VibDelta+X
	BPL	+
	DEC	Y
+	ADDW	YA, 0
	MOVW	0, YA
	
	DEC	t_VibSteps+X
	BNE	loc_AB4
	MOV	A, VibLen+X
	MOV	t_VibSteps+X, A
	MOV	A, VibDelta+X
	EOR	A, #-1
	INC	A
	MOV	VibDelta+X, A
loc_AB4:
	; Now add the delta to the current pitch value at the DSP.
	; Limit the pitch to the valid range of $0000..$3FFF.
	MOV	A, 1
	CLRC
	ADC	DSPData, 0
	INC	DSPAddr
	ADC	A, DSPData
	BMI	.minus
	CMP	A, #$40
	BCS	+		; branch if pitch is out of range
	MOV	DSPData, A
	RET
; -----------------------------------------------------------------------------
	; Set the maximum possible pitch.
+	MOV	DSPData, #$3F
	DEC	DSPAddr
	MOV	DSPData, #$FF
	RET
; -----------------------------------------------------------------------------
	; Set the minimum possible pitch.
.minus:
	MOV	DSPData, #0
	DEC	DSPAddr
	MOV	DSPData, #0
	RET
; =============================================================================
EndOfTrack:
	MOV	X, CurrentTrack
	BBS5	TempFlags, +
	BBC7	TempFlags, +
	MOV	A, CurVoiceAddr
	OR	A, #8
	MOV	DSPAddr, A
	MOV	A, DSPData
	BNE	.ret	; if the channel is still audible, we will come back here later
+	AND	TempFlags, #$20
	CMP	X, #8
	BCC	.ret
	MOV	A, SndFlags-8+X
	AND	A, #$DF
	MOV	SndFlags-8+X, A

.ret:	MOV	A, TempFlags
	MOV	SndFlags+X, A
	BBS3	GlobalFlags, +
	JMP	FinishTrackUpdate
; -----------------------------------------------------------------------------
+	RET
; =============================================================================
SetVoice:	; $ABA
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndTimbre+X, A	; Store the logical instrument index.
	MOV	A, #0
	MOV	SndFineTune+X, A
	JMP	IncAndFinishEvent
; -----------------------------------------------------------------------------
SetVolume:	; $AE3
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndVol_L+X, A
	INC	Y
	MOV	A, (0)+Y
	MOV	SndVol_R+X, A
	JMP	IncAndFinishEvent
; -----------------------------------------------------------------------------
JumpTrack:	; $B14
	MOV	A, (0)+Y	; LSB
	MOV	2, A
	INC	Y
	MOV	A, (0)+Y	; MSB
	MOV	1, A
	MOV	0, 2
	MOV	Y, #0
	JMP	FinishEvent
; -----------------------------------------------------------------------------
CallSub:	; $B29
	MOV	A, (0)+Y	; repeat count
	MOV	2, A
	INC	Y

	MOV	A, Y
	MOV	Y, #0
	ADDW	YA, 0
	MOVW	3, YA

	MOV	X, CurrentTrack
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
; -----------------------------------------------------------------------------
RetSub:	; $B5E
	MOV	X, CurrentTrack

	MOV	Y, SndStackPtr+X
	MOV	A, Stack_PtrL-1+Y	; LSB
	MOV	0, A
	MOV	A, Stack_PtrH-1+Y	; MSB
	MOV	1, A

	MOV	A, Stack_RepCnt-1+Y
	DEC	A	; decrement repeat count
	BEQ	+
	MOV	Stack_RepCnt-1+Y, A

	; Repeat the subroutine.
	MOV	Y, #1
	MOV	A, (0)+Y	; MSB
	MOV	2, A
	DEC	Y
	MOV	A, (0)+Y	; LSB
	MOV	0, A
	MOV	1, 2
	JMP	FinishEvent
; -----------------------------------------------------------------------------
+	DEC	SndStackPtr+X
	MOV	Y, #2
	JMP	FinishEvent
; =============================================================================
DefaultDurOn:	; $BA4
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	BBC1	TempFlags, +
	MOV	DfltNoteDur_H+X, A
	INC	Y
	MOV	A, (0)+Y
+	MOV	DfltNoteDur_L+X, A
	JMP	IncAndFinishEvent
; =============================================================================
DefaultDurOff:	; $BC9
	MOV	X, CurrentTrack
	MOV	A, #0
	MOV	DfltNoteDur_L+X, A
	MOV	DfltNoteDur_H+X, A
	JMP	FinishEvent
; =============================================================================
PitchSlideUp:	; $BD5
	MOV	X, CurrentTrack
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
; =============================================================================
PitchSlideDown:	; $C09
	MOV	X, CurrentTrack
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
; =============================================================================
PitchSlideOff:	; $C40
	MOV	X, CurrentTrack
	MOV	A, #0
	MOV	PitchSlideDelta+X, A
	JMP	FinishEvent
; =============================================================================
SetTempo:	; $DEB
	MOV	A, (0)+Y
	MOV	BGMTempo, A
	CALL	TempoToInterval
	JMP	IncAndFinishEvent
; =============================================================================
AddTempo:	; $DF8
	MOV	A, (0)+Y
	ADC	A, BGMTempo
	MOV	BGMTempo, A
	CALL	TempoToInterval
	JMP	IncAndFinishEvent
; =============================================================================
Vibrato2:	; $C78
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	VibLen+X, A	; vibrato cycle length
	INC	Y
	MOV	A, (0)+Y
	MOV	VibInterval+X, A	; step interval
	INC	Y
	MOV	A, (0)+Y
	MOV	VibDelta+X, A	; pitch delta
	MOV	A, #0
	MOV	VibDelay+X, A
	JMP	IncAndFinishEvent
; =============================================================================
VibratoOff:	; $CA5
	MOV	X, CurrentTrack
	MOV	A, #0
	MOV	VibDelta+X, A
	JMP	FinishEvent
; =============================================================================
Vibrato:	; $CB1
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	VibLen+X, A	; vibrato cycle length
	INC	Y
	MOV	A, (0)+Y
	MOV	VibInterval+X, A	; step interval
	INC	Y
	MOV	A, (0)+Y
	MOV	VibDelta+X, A	; pitch delta
	INC	Y
	MOV	A, (0)+Y
	MOV	VibDelay+X, A	; delay
	JMP	IncAndFinishEvent
; =============================================================================
SetADSR:	; $CDF
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndADSR1+X, A	; ADSR 1
	INC	Y
	MOV	A, (0)+Y
	MOV	SndADSR2+X, A	; ADSR 2
	JMP	IncAndFinishEvent
; =============================================================================
SetTuning:	; $D32
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndFineTune+X, A
	JMP	IncAndFinishEvent
; =============================================================================
SetTranspose:	; $D45
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	Transpose+X, A
	JMP	IncAndFinishEvent
; =============================================================================
AddTranspose:	; $D59
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	ADC	A, Transpose+X
	MOV	Transpose+X, A
	JMP	IncAndFinishEvent
; =============================================================================
SetEchoParams:	; $D71
	MOV	DSPAddr, #DSP_Feedback
	MOV	A, (0)+Y
	MOV	DSPData, A
	INC	Y

	MOV	DSPAddr, #DSP_EchoL
	MOV	A, (0)+Y
	MOV	DSPData, A
	INC	Y

	SET4	DSPAddr
	MOV	A, (0)+Y
	MOV	DSPData, A
	JMP	IncAndFinishEvent
; =============================================================================
EchoOn:		; $DA0
	SET2	TempFlags
	JMP	FinishEvent
; =============================================================================
EchoOff:	; $DBB
	CLR2	TempFlags
	JMP	FinishEvent
; =============================================================================
SetFIR:		; $DD8
	MOV	DSPAddr, #DSP_FIR

-	MOV	A, (0)+Y
	MOV	DSPData, A
	INC	Y
	ADC	DSPAddr, #$10
	BPL	-

	JMP	FinishEvent
; =============================================================================
SetNoise:	; $DF8
	MOV	A, (0)+Y
	MOV	DSPAddr, #DSP_Flags
	MOV	DSPData, A
	JMP	IncAndFinishEvent
; =============================================================================
NoiseOn:	; $E12
	SET3	TempFlags
	JMP	FinishEvent
; =============================================================================
NoiseOff:	; $E2A
	CLR3	TempFlags
	JMP	FinishEvent
; =============================================================================
PitchSlideDown2:	; $EA7
	MOV	X, CurrentTrack
	MOV	A, (0)+Y	; delay
	MOV	PitchSlideDelay+X, A
	INC	Y
	MOV	A, (0)+Y	; portamento interval
	MOV	PitchSlideInterval+X, A
	INC	Y
	MOV	A, (0)+Y	; portamento steps
	MOV	PitchSlideStepsDown+X, A
	ASL	A
	MOV	PitchSlideSteps+X, A
	INC	Y
	MOV	A, (0)+Y	; pitch delta
	EOR	A, #-1
	INC	A
	MOV	PitchSlideDelta+X, A
	JMP	IncAndFinishEvent
; =============================================================================
PitchSlideUp2:	; $EDC
	MOV	X, CurrentTrack
	MOV	A, (0)+Y	; delay
	MOV	PitchSlideDelay+X, A
	INC	Y
	MOV	A, (0)+Y	; portamento interval
	MOV	PitchSlideInterval+X, A
	INC	Y
	MOV	A, (0)+Y	; portamento steps
	MOV	PitchSlideStepsDown+X, A
	ASL	A
	MOV	PitchSlideSteps+X, A
	INC	Y
	MOV	A, (0)+Y	; pitch delta
	MOV	PitchSlideDelta+X, A
	JMP	IncAndFinishEvent
; =============================================================================
VoiceAndVolume:	; $F0E
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndTimbre+X, A	; Store the logical instrument index.
	INC	Y
	MOV	A, (0)+Y
	MOV	SndVol_L+X, A
	INC	Y
	MOV	A, (0)+Y
	MOV	SndVol_R+X, A
	MOV	A, #0
	MOV	SndFineTune+X, A
	JMP	IncAndFinishEvent
; =============================================================================
LongNoteOn:	; $F72
	SET1	TempFlags
	JMP	FinishEvent
; =============================================================================
LongNoteOff:	; $F82
	CLR1	TempFlags
	JMP	FinishEvent
; =============================================================================
SetTremolo:	; $FBE
	MOV	X, CurrentTrack
	MOV	A, (0)+Y	; length
	MOV	TremLen+X, A
	INC	Y
	MOV	A, (0)+Y	; interval
	MOV	TremInterval+X, A
	INC	Y
	MOV	A, (0)+Y	; depth
	MOV	TremDelta+X, A
	INC	Y
	MOV	A, (0)+Y	; delay
	MOV	TremDelay+X, A
	JMP	IncAndFinishEvent
; =============================================================================
TremoloOff:	; $FF8
	MOV	X, CurrentTrack
	MOV	A, #0
	MOV	TremDelta+X, A
	JMP	FinishEvent
; =============================================================================
VoiceBitMask:	; $1004
	db	1, 2, 4, 8, $10, $20, $40, $80
; =============================================================================
TrackEventTable:	; $1014
	; See https://loveemu.hatenablog.com/entry/20130819/SNES_Rare_Music_Spec for details
	DW	EndOfTrack	; $A6E	; individual effect
	DW	SetVoice	; $ABA	; individual effect (no rest required)
	DW	SetVolume	; $AE3	; individual effect (no rest required)
	DW	JumpTrack	; $B14	; individual effect (no rest required)
	DW	CallSub		; $B29	; individual effect (no rest required)
	DW	RetSub		; $B5E	; individual effect (no rest required)
	DW	DefaultDurOn	; $BA4	; individual effect (no rest required)
	DW	DefaultDurOff	; $BC9	; individual effect (no rest required)
	DW	PitchSlideUp	; $BD5	; individual effect
	DW	PitchSlideDown	; $C09	; individual effect
	DW	PitchSlideOff	; $C40	; individual effect
	DW	SetTempo	; $C56	; global effect
	DW	AddTempo	; $C6B	; global effect
	DW	Vibrato2	; $C78	; individual effect
	DW	VibratoOff	; $CA5	; individual effect
	DW	Vibrato		; $CB1	; individual effect
	DW	SetADSR		; $CDF	; individual effect (no rest required)
	DW	SetMasterVolume	; $CF9	; individual effect (no rest required)
	DW	SetTuning	; $D32	; individual effect (no rest required)
	DW	SetTranspose	; $D45	; individual effect (no rest required)
	DW	AddTranspose	; $D59	; individual effect (no rest required)
	DW	SetEchoParams	; $D71	; global effect
	DW	EchoOn		; $DA0	; individual effect (no rest required)
	DW	EchoOff		; $DBB	; individual effect (no rest required)
	DW	SetFIR		; $DD8	; global effect
	DW	SetNoise	; $DF8	; global effect
	DW	NoiseOn		; $E12	; individual effect (no rest required)
	DW	NoiseOff	; $E2A	; individual effect (no rest required)
	DW	0	; global effect
	DW	0	; global effect
	DW	0	; global effect
	DW	0	; global effect
	DW	0	; global effect
	DW	0	; global effect
	DW	0	; global effect
	DW	0	; global effect
	DW	0	; global effect
	DW	0	; global effect
	DW	PitchSlideDown2	; $EA7	; individual effect
	DW	PitchSlideUp2	; $EDC	; individual effect
	DW	VoiceAndVolume	; $F0E	; individual effect (no rest required)
	DW	0	; global effect
	DW	SetTimerFreq	; $F60	; individual effect (no rest required)
	DW	LongNoteOn	; $F72	; individual effect (no rest required)
	DW	LongNoteOff	; $F82	; individual effect (no rest required)
	DW	0	; global effect
	DW	SetJumpCond	; $FAC	; individual effect (no rest required)
	DW	SetTremolo	; $FBE	; individual effect
	DW	TremoloOff	; $FF8	; individual effect
; =============================================================================
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
	db	-1	; individual effect (no rest required)
	db	-1	; individual effect (no rest required)
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
	db	-1	; individual effect (no rest required)
	db	1	; individual effect
	db	1	; individual effect
; =============================================================================
SetUpEngine:	; $1076
	MOV	Y, #0
	BBC4	GlobalFlags, +	; skip some init on warm reset

	MOV	Timer1, #20	; Set timer 1 to 2.5 ms.

	MOV	A, #$D		; echo feedback
	MOVW	DSPAddr, YA	; = 0
	MOV	A, #$4D		; echo enable
	MOVW	DSPAddr, YA	; = 0

	SET5	DSPAddr		; echo buffer location
	MOV	DSPData, #EchoBuffer>>8

	SET4	DSPAddr		; echo delay
	MOV	DSPData, #4	; = 64 ms

	MOV	Y, #64
	MOV	A, #$C		; master left volume
	MOVW	DSPAddr, YA
	MOV	A, #$1C
	MOVW	DSPAddr, YA

	MOV	A, #$5D		; source directory (instrument table)
	MOV	Y, #SourceDir>>8
	MOVW	DSPAddr, YA

	MOV	Y, #0
	MOV	A, #$2D		; pitch modulation
	MOVW	DSPAddr, YA	; = 0

+	MOV	A, #$2C		; echo left volume
	MOVW	DSPAddr, YA	; = 0
	MOV	A, #$3C		; echo right volume
	MOVW	DSPAddr, YA	; = 0
	MOV	A, #$6C
	MOVW	DSPAddr, YA

	MOV	A, Y	; A = 0
	MOV	ControlReg, A
	MOVW	GlobalFlags, YA		; Also clears CurPreprocTrack.

	INC	A	; A = 1
	MOV	Y, A	; Y = 1
	MOVW	SFXDivCounter, YA	; Also sets MiscDivCounter
	MOVW	Timer0Ticks, YA		; Also sets Timer1Ticks.

	MOV	X, #7
	MOV	Y, #15
	JMP	+	; Loop optimisation. Saves 3 cycles.
; -----------------------------------------------------------------------------
-	DEC	X
	DEC	Y

	MOV	A, #1
+	MOV	NoteDur_L+X, A	; set delay duration to 1
	MOV	SndFlags+X, A
	DEC	A	; A = 0
	MOV	NoteDur_H+X, A
	MOV	DfltNoteDur_L+X, A
	MOV	DfltNoteDur_H+X, A
	MOV	SndFlags+8+X, A
	MOV	Transpose+X, A
	MOV	SndFineTune+X, A
	MOV	PitchSlideDelta+X, A
	MOV	VibDelta+X, A
	MOV	TremDelta+X, A
	MOV	A, MusicData-1+Y
	MOV	TrkPtr_L+X, A
	MOV	A, MusicData+Y
	MOV	TrkPtr_H+X, A
	MOV	A, X
	ASL	A
	ASL	A
	ASL	A
	MOV	SndStackPtr+X, A
	; set ADSR to $FE-$C1
	MOV	A, #$FE
	MOV	SndADSR1+X, A
	MOV	A, #$C1
	MOV	SndADSR2+X, A

	DBNZ	Y, -

	MOV	A, MusicData+16
	MOV	BGMTempo, A
	RET
; =============================================================================
PlaySFX:	; $1178
	ASL	A
	MOV	Y, A

	MOV	A, X
	XCN	A
	OR	A, #7
	MOV	DSPAddr, A
	MOV	DSPData, #$9F	; Linear fade-out, rate 15
	CLR1	DSPAddr
	CLR7	DSPData
	MOV	A, #127
	MOV	SndEnvLvl+8+X, A

	MOV	A, SndFlags+X
	OR	A, SndFlags+8+X
	AND	A, #$81
	OR	A, #1
	MOV	SndFlags+8+X, A

	MOV	A, SndFlags+X
	AND	A, #$3F
	OR	A, #$20
	MOV	SndFlags+X, A

	MOV	A, X
	OR	A, #8
	ASL	A
	ASL	A
	ASL	A
	MOV	SndStackPtr+8+X, A	; store stack pointer
	MOV	A, #0
	MOV	DfltNoteDur_L+8+X, A
	MOV	DfltNoteDur_H+8+X, A
	MOV	NoteDur_H+8+X, A
	MOV	Transpose+8+X, A
	MOV	SndFineTune+8+X, A
	MOV	PitchSlideDelta+8+X, A
	MOV	VibDelta+8+X, A
	MOV	TremDelta+8+X, A
	INC	A	; A = 1
	MOV	NoteDur_L+8+X, A

	; set center volume to -128
	MOV	A, #-128
	MOV	SndVol_L+8+X, A
	MOV	SndVol_R+8+X, A

	; set ADSR to $FE-$C1
	MOV	A, #$FE
	MOV	SndADSR1+8+X, A
	MOV	A, #$C1
	MOV	SndADSR2+8+X, A

	; set track pointer
	MOV	A, SFXData+Y
	MOV	TrkPtr_L+8+X, A
	MOV	A, SFXData+1+Y
	MOV	TrkPtr_H+8+X, A
	RET
;-----------------------------------------------------------------------------
PitchTable:	; $11E6
	DW	483
	DW	512,	542,	574,	608,	645,	683
	DW	724,	767,	812,	861,	912,	966
	DW	1024,	1084,	1149,	1217,	1290,	1366
	DW	1448,	1534,	1625,	1722,	1824,	1933
	DW	2048,	2169,	2298,	2435,	2580,	2733
	DW	2896,	3068,	3250,	3444,	3649,	3866
	DW	4096,	4339,	4597,	4870,	5160,	5467
	DW	5792,	6137,	6501,	6888,	7298,	7732
	DW	8192,	8679,	9195,	9741,	10321,	10935
	DW	11585,	12274,	13003,	13777,	14596,	15464
	DW	16383,	8679,	9195,	9741,	10321,	10935
	DW	11585,	12274,	13003,	13777,	14596,	15464
