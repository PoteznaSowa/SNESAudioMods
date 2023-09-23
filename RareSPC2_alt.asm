; Modified Rare's Donkey Kong Country 2 and 3 sound engine.
; Based on Donkey Kong Country 2 and 3 sound engine disassembly.
; Author: PoteznaSowa.

; Some changes included in the mod:
; - optimised code, unused features removed, data transfer sped up;
; - added asynchronous processing of sound sequence data in background;
; - music runs at variable SPC timer period instead of
;   using a single fixed-period timer in the original design;
; - improved mixing-out stereo;
; - improved echo buffer initialisation to fix audible glitches
;   at some occasions

hirom

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

NextMsg:	skip 1	; Next message number

; 0: engine is running
; 1: halve BGM tempo
; 2: if bit 1 is set, skip BGM updates
; 3: events are being preprocessed
; 4: monaural mode
; 5: cold reset
; 6: echo buffer is being cleared
GlobalFlags:	skip 1

CurPreprocTrack:	skip 1	; number of channel to be preprocessed
BGMTempo:	skip 1
Timer0Ticks:	skip 1
Timer1Ticks:	skip 1
SndNewPitchOffset:	skip 2	; New pitch offset for SFX channel #5
SndPitchOffset:	skip 2	; Current pitch offset for SFX channel #5
SFXCount:	skip 1
BGMVol:		skip 1	; current BGM volume
VolPreset1_L:	skip 1
VolPreset1_R:	skip 1
VolPreset2_L:	skip 1
VolPreset2_R:	skip 1
EchoOnShadow:	skip 1

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
t_VibInterval:	skip 16	; vibrato interval timeout
t_VibSteps:	skip 16	; vibrato cycle steps left
SndStackPtr:	skip 16	; current stack pointer
VarNote0:	skip 8	; variable note 0, used by BGM only
VarNote1:	skip 8	; variable note 1, used by BGM only


; Memory-mapped hardware registers, also in page 0
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
Timer2:		skip 1	; $FC	; 1/64 ms timer. Unused.
Timer0_out:	skip 1	; $FD	; Number of timer 0 ticks.
Timer1_out:	skip 1	; $FE	; Number of timer 1 ticks.
Timer2_out:	skip 1	; $FF	; Number of timer 2 ticks.

; Direct page 1 variables

; We had to move the one-sample echo buffer somewhere from $FF00..$FF03.
; Part of the Nuts and Bolts song sample set is written into this region and
; the echo buffer would overwrite it, corrupting the "Kiddy screaming" sample
; in particular.
EchoSample:	skip 4

PrgStack:	skip 11	; Program stack.
PrgStackBase:	skip 1	; Initial stack pointer.

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

; Subroutine stack. The maximum nest level is 8.
Stack_PtrL:	skip 128
Stack_PtrH:	skip 128
Stack_RepCnt:	skip 128	; stack repeat count

SndFIRShadow:	skip 8	; contains echo FIR filter coefficients

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


; Locations of external data.

MusicData =	$1300
MusicIndex =	$1312

; Sound data for SFXs $00..$5F
SFX_IndexBound0 =	$2410
SFX_PtrTable0 =		$2412

; Sound data for SFXs $60..$7F
SFX_IndexBound1 =	$2E94
SFX_PtrTable1 =		$2E96

SourceDir =	$3100
EchoBufEnd =	$FEFE


	arch spc700
	optimize dp always

	ORG	$EE0000	; set to $ED0000 for Donkey Kong Country 3
	base	$4D8
EntryPoint:
	MOV	X, #PrgStackBase&$FF
	MOV	SP, X
	MOV	X, #0
	MOV	Port0, X	; Tell SNES we are in this transfer routine
	MOV	DSPAddr, #$7D
	MOV	DSPData, X	; Set echo delay to 0
	INC	X		; X = 1
	SET5	GlobalFlags

TransferMode:
	; Reset echo buffer settings.
	MOV	A, #$6D
	MOV	Y, #EchoSample>>8
	MOVW	DSPAddr, YA

--	CMP	X, Port0	; has SNES sent the next data word?
	BNE	--	; branch if no
	MOVW	YA, Port1	; get write address
	MOV	Port0, X	; reply to SNES
	INC	X		; increment message ID
	MOVW	2, YA		; store write address

-	CMP	X, Port0	; has SNES sent the next data word?
	BNE	-		; branch if no
	MOVW	YA, Port1	; get block size in words
	MOV	Port0, X	; reply to SNES
	INC	X		; increment message ID
	MOVW	0, YA		; store block size
	DECW	0		; is it $8001..$FFFF or zero?
	BMI	+		; branch if yes

	; Convert the block size into the initial Y index and
	; the number of 256 byte-sized chunks plus 1.
	ADDW	YA, 0	; YA = (block size in words)*2-1
	INC	Y	; Y = number of 256-byte chunks
	EOR	A, #$FF	; A = 256-(first block size in bytes)
	MOVW	0, YA	; store initial block offset and number of chunks
	MOV	Y, A	; now we have the initial index
	MOV	A, 2	; get destination LSB
	SETC
	SBC	A, 0	; subtract the initial index
	MOV	.lsb+1, A	; store the result
	MOV	.msb+1, A
	MOV	A, 3	; get destination MSB
	SBC	A, #0	; decrement on subtraction burrow
	MOV	.lsb+2, A	; store the result
	MOV	.msb+2, A

-	CMP	X, Port0	; has SNES sent the next data word?
	BNE	-		; branch if no
	MOV	A, Port1	; get first data byte

.lsb:	MOV.W	0+Y, A		; store it at the destination
	MOV	A, Port2	; get second data byte
	MOV	Port0, X	; reply to SNES
	INC	X		; increment message ID
	INC	Y		; increment index
.msb:	MOV.W	0+Y, A		; store it at the destination
	INC	Y		; have we finished the chunk?
	BNE	-		; branch if not
	INC	.lsb+2		; add $100 to write address
	INC	.msb+2
	DBNZ	1, -		; proceed with the next chunk if any
	JMP	--
; -----------------------------------------------------------------------------
+	MOV	NextMsg, X	; store next message index
	JMP	SetFixedBGM	; Run the code.
; =============================================================================
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
; =============================================================================
	base off
	ORG	$EE0088	; set to $ED0000 for Donkey Kong Country 3
	base	$560
; =============================================================================
; The table stores SRCNs for up to 256 samples.
; During data transfer, SNES builds it and sends to the engine.
TimbreLUT:
	rep 256 : DB 0
; =============================================================================
; This engine can play additional music without entering transfer routine.
; Get the pointer to a song from the array at $1312 with Y as an index.
SetIndexedBGM:
	MOV	A, Y
	ASL	A
	MOV	X, A
	MOV	A, MusicIndex+1+X	; load BGM location from pointer table
	MOV	Y, A
	MOV	A, MusicIndex+X
	JMP	EngineStart
; =============================================================================
; This is the entry point of the engine.
; Set the pointer to a song to $1300 and initialise the engine.
SetFixedBGM:
	MOV	A, #MusicData&$FF
	MOV	Y, #MusicData>>8
EngineStart:
	MOVW	2, YA
	CALL	SetUpEngine	; set up S-DSP and music

; Check if there's an incoming message from SNES and process it.
; To play a composite SFX (played at more than one channel), SNES sends more
; than a single message.
GetMessage:
	CMP	Port0, NextMsg	; has SNES sent the next data word?
	BNE	MainLoop	; branch if no
GetMessage2:
	MOVW	YA, Port1	; read message word
	MOV	Port0, NextMsg	; reply to SNES
	INC	NextMsg	; increment message counter
	MOV	X, A	; is the first message byte negative?
	BMI	+	; branch if yes

	CMP	Y, #8
	BCS	GetMessage	; Do not set up a SFX on an invalid channel.
	MOV	0, Y	; Y contains the channel number to play SFX at.
	MOV	X, 0	; It needs to be in X instead.
	CALL	SetUpSFX
	JMP	GetMessage
; =============================================================================
+	AND	A, #7		; clear unwanted bits
	ASL	A
	MOV	X, A
	JMP	(Command_Index+X)	; process the command
; =============================================================================
MainLoop:
	BBC0	GlobalFlags, GetMessage	; branch if the sound has not started yet
	BBC6	GlobalFlags, +

	MOV	A, EchoBufEnd
	BNE	+

	CALL	RestoreEcho

+	CLRC
	ADC	Timer0Ticks, Timer0_out	; has the BGM timer ticked?
	BEQ	SkipBGMUpdate		; branch if no

UpdateBGM:
	BBC1	GlobalFlags, +	; Branch if tempo not halved.
	BBS2	GlobalFlags, ++	; Skip updates every second tick.

+	MOV	CurrentTrack, #0
	CALL	UpdateTracks

++	DEC	Timer0Ticks
	EOR	GlobalFlags, #4

SkipBGMUpdate:
	CMP	Port0, NextMsg	; has SNES sent next message?
	BEQ	GetMessage2	; branch if yes

	CLRC
	ADC	Timer1Ticks, Timer1_out	; has the main timer ticked?
	BEQ	PreprocessTracks	; branch if no

UpdateSFX:
	MOV	CurrentTrack, #8
	CALL	UpdateTracks

	MOV	CurrentTrack, #0
	MOV	DSPAddr, #2	; Go to channel #0 pitch

UpdateTracks2:
	MOV	X, CurrentTrack
	MOV	A, SndFlags+X
	AND	A, #$20		; is the channel used by SFX?
	BEQ	+		; branch if no
	OR	CurrentTrack, #8	; process a SFX channel instead
+	CALL	UpdateTrack_2	; update pitch bend
	CLR3	CurrentTrack		; revert to BGM
	INC	CurrentTrack
	ADC	DSPAddr, #$F	; Go to next channel pitch
	BPL	UpdateTracks2

	DEC	Timer1Ticks
	DBNZ	SFXCount, +	; Decrement the initial SFX pre-silence length.
	INC	SFXCount	; Limit it to 1, though.
+

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
	CMP	Port0, NextMsg		; has SNES sent next message?
	BEQ	GetMessage2		; branch if yes
	CLRC
	ADC	Timer0Ticks, Timer0_out	; has the BGM timer ticked?
	BNE	UpdateBGM		; branch if yes
	ADC	Timer1Ticks, Timer1_out	; has the main timer ticked?
	BNE	UpdateSFX		; branch if yes

	CALL	PreprocessTracks2
	JMP	GetMessage
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

	; Mark the channel as silent if the ADSR envelope falls to zero.
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
	JMP	(CtrlEventIndex+X)	; run the sound event
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
	BCS	+	; Branch if the result does not fit into 16 bits.
	MOV	NoteDur_L+X, A	; Store the result.
	MOV	NoteDur_H+X, Y
	MOV	A, 4
	MOV	Y, #0
	ADDW	YA, 0	; Add the track offset the pointer.
	MOV	TrkPtr_L+X, A	; store pointer LSB
	MOV	TrkPtr_H+X, Y	; store pointer MSB
+	JMP	FinishPreproc
; =============================================================================
; Enable the monaural mode if argument non-zero.
SetMonoFlag:
	CLR4	GlobalFlags	; Clear the "monaural mode" flag.
	MOV	A, Y		; Is the argument zero?
	BEQ	+		; Branch if yes.
	SET4	GlobalFlags	; Set the "monaural mode" flag.

	; Invalidate all asynchronous note preparations.
+	MOV	Y, #16
-	MOV	A, SndFlags-1+Y
	AND	A, #$BF
	MOV	SndFlags-1+Y, A
	DBNZ	Y, -
CommandF8:	; formerly used to set a BGM mailslot or something?
CommandF9:	; formerly used to set a BGM mailslot or something?
	JMP	GetMessage
; =============================================================================
; Change pitch modifier for SFX at channel #5.
; Used to adjust pitch of the sound of riding a vehicle in DKC2 (Skull Cart)
; and DKC3 (various vehicles from Funky's Rentals).
; Offset=Argument*8
AdjustSFXPitch:
	MOV	SndNewPitchOffset, Y
	MOV	A, #0
	ASL	SndNewPitchOffset	; Multiply by 8.
	BCC	+		; Sign-extend.
	DEC	A		; A = -1
+	ASL	SndNewPitchOffset
	ROL	A
	ASL	SndNewPitchOffset
	ROL	A
	MOV	SndNewPitchOffset+1, A

	BBC7	SndFlags+8+5, +

	MOVW	YA, SndNewPitchOffset
	SUBW	YA, SndPitchOffset	; subtract the previous pitch modifier
	MOVW	0, YA
	MOVW	YA, SndNewPitchOffset
	MOVW	SndPitchOffset, YA

	MOV	DSPAddr, #$52
	CALL	loc_AB4

	;MOV	DSPAddr, #$4D
	;CLR5	DSPData		; Disable echo for DSP channel #5.
	;CLR5	EchoOnShadow
	;CLR2	SndFlags+8+5	; Clear the "echo on" flag at SFX track #5.
+	JMP	GetMessage
; =============================================================================
; Change the volume of SFX at channel #5.
; Volume = Volume * Modifier / 100
AdjustSFXVol:
	MOV	0, Y
	MOV	DSPAddr, #$50
	MOV	A, DSPData
	CALL	ApplyVolMod2
	MOV	DSPData, A
	INC	DSPAddr
	MOV	Y, 0
	MOV	A, DSPData
	CALL	ApplyVolMod2
	MOV	DSPData, A
	JMP	GetMessage
; =============================================================================
; Start processing music and sound effects.
StartEngine:
	SET0	GlobalFlags
	CALL	TempoToInterval2
-	CALL	PreprocessTracks2
	BBC3	CurPreprocTrack, -
	MOV	ControlReg, #3	; Start timers 0 and 1.
	JMP	GetMessage
; =============================================================================
; Stop the engine and enter transfer mode.
GotoTransferMode:
	; Set all channels to fade out.
	MOV	A, #7
	MOV	Y, #$BF		; Exponential fade-out, rate 15
	CLRC
-	MOVW	DSPAddr, YA
	CLR1	DSPAddr
	CLR7	DSPData
	ADC	A, #$10
	BPL	-

	; Fade out FIR filter taps.
	MOV	DSPAddr, #$F
--	MOV	A, DSPData
	BPL	+
-	INC	DSPData
	BNE	-
	JMP	++
; -----------------------------------------------------------------------------
+	BEQ	++
-	DBNZ	DSPData, -
++	ADC	DSPAddr, #$10
	BPL	--

	MOV	A, #$7D
	MOV	Y, #0
	MOVW	DSPAddr, YA	; set echo delay to 0

	MOV	A, Y
	MOV	Y, #8
-	MOV	SndFIRShadow-1+Y, A
	DBNZ	Y, -

	MOV	X, NextMsg

	; Wait until all channels fade out.
	MOV	DSPAddr, #8
-	MOV	A, DSPData
	BNE	-
	ADC	DSPAddr, #$10
	BPL	-

	MOV	A, #$6C
	MOV	Y, #$E0
	MOVW	DSPAddr, YA

	JMP	TransferMode	; Enter transfer mode.
; =============================================================================
Command_Index:
	DW	CommandF8, CommandF9		; $F8, $F9
	DW	SetMonoFlag, SetIndexedBGM	; $FA, $FB
	DW	AdjustSFXPitch, AdjustSFXVol	; $FC, $FD
	DW	StartEngine, GotoTransferMode	; $FE, $FF
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
	JMP	(CtrlEventIndex+X)	; Run an event handler.
; =============================================================================
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

	CMP	A, #$E0	; variable note 0
	BMI	++
	CMP	A, #$E1	; variable note 1
	BEQ	+
	MOV	A, VarNote0+X
	JMP	++
; -----------------------------------------------------------------------------
+	MOV	A, VarNote1+X
++	CLRC
	ADC	A, #36	; Three-octave adjustment
	ADC	A, Transpose+X
	ASL	A

	; fine-tune given pitch with current fine-tune value
	; with following formula:
	; P=P*(1024+T)/1024, where T is fine-tune offset
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
	MOV	A, PitchTable+1+X ; read LSB of seed pitch value
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
	CMP	X, #13
	BNE	+
	MOV	A, #0
	MOV	Y, A
	MOVW	SndPitchOffset, YA
+
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
	MOV	t_VibInterval+X, A
	MOV	A, VibDelay+X	; delay
	MOV	t_VibDelay+X, A

	; write current sound parameters into DSP
	MOV	DSPAddr, CurVoiceAddr
	MOV	A, SndVol_L+X
	BBC4	GlobalFlags, ++

	; Mix out stereo.
	; Vol=(abs(Vol_L)+abs(Vol_R)+1)/(-2)
	BPL	+	; Vol=abs(Vol)
	EOR	A, #-1
	INC	A
+	MOV	4, A
	MOV	A, SndVol_R+X
	BPL	+
	EOR	A, #-1
	INC	A
+	SETC
	ADC	A, 4
	ROR	A	; Halve the result.
	EOR	A, #-1
	INC	A
	CALL	ApplyVolMod
	MOV	DSPData, A	; Left channel level
	JMP	+++
; -----------------------------------------------------------------------------
++	CALL	ApplyVolMod
	MOV	DSPData, A	; Left channel level
	MOV	A, SndVol_R+X
	CALL	ApplyVolMod
+++	INC	DSPAddr
	MOV	DSPData, A	; Right channel level
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

	OR	EchoOnShadow, CurVoiceBit
	BBS2	TempFlags, +
	EOR	EchoOnShadow, CurVoiceBit
+	BBS6	GlobalFlags, +
	MOV	DSPAddr, #$4D
	MOV	DSPData, EchoOnShadow

+	MOV	DSPAddr, #$3D
	MOV	A, DSPData
	OR	A, CurVoiceBit
	BBS3	TempFlags, +
	EOR	A, CurVoiceBit	; disable noise
+	MOV	DSPData, A

	RET
; =============================================================================
; Updates pitch slide and vibrato for a track.
UpdateTrack_2:
	MOV	X, CurrentTrack
	MOV	A, SndFlags+X
	BMI	+
	SETC
	RET
; -----------------------------------------------------------------------------
+	MOV	A, #0
	MOV	Y, A
	MOVW	0, YA

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
	DEC	t_VibInterval+X
	BNE	loc_AB4
	MOV	A, VibInterval+X
	MOV	t_VibInterval+X, A

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
	SETC
	RET
; =============================================================================
StopTrack:	; $B18
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
SetInstrument:	; $B72
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndTimbre+X, A	; Store the logical instrument index.
	JMP	IncAndFinishEvent
; =============================================================================
SetVoiceParams:	; $B97
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndTimbre+X, A	; instrument
	INC	Y
	MOV	A, (0)+Y
	MOV	Transpose+X, A	; transpose
	INC	Y
	MOV	A, (0)+Y
	MOV	SndFineTune+X, A	; tuning
	INC	Y
	MOV	A, (0)+Y
	MOV	SndVol_L+X, A
	INC	Y
	MOV	A, (0)+Y
	MOV	SndVol_R+X, A
	INC	Y
	MOV	A, (0)+Y
	MOV	SndADSR1+X, A	; ADSR 1
	INC	Y
	MOV	A, (0)+Y
	MOV	SndADSR2+X, A	; ADSR 2
	JMP	IncAndFinishEvent
; =============================================================================
SetVolume:	; $BB6
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndVol_L+X, A
	INC	Y
	MOV	A, (0)+Y
	MOV	SndVol_R+X, A
	JMP	IncAndFinishEvent
; =============================================================================
SetCentreVolume:	; $BF0
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndVol_L+X, A
	MOV	SndVol_R+X, A
	JMP	IncAndFinishEvent
; =============================================================================
UsePresetVolume1:	; $C02
	MOV	X, CurrentTrack
	MOV	A, VolPreset1_L
	MOV	SndVol_L+X, A
	MOV	A, VolPreset1_R
	MOV	SndVol_R+X, A
	JMP	FinishEvent
; =============================================================================
UsePresetVolume2:	; $C18
	MOV	X, CurrentTrack
	MOV	A, VolPreset2_L
	MOV	SndVol_L+X, A
	MOV	A, VolPreset2_R
	MOV	SndVol_R+X, A
	JMP	FinishEvent
; =============================================================================
SetBGMVol:	; $C4E
	MOV	A, (0)+Y
	MOV	BGMVol, A

	; Invalidate all asynchronous note preparations.
	MOV	X, #7
-	MOV	A, SndFlags+X
	AND	A, #$BF
	MOV	SndFlags+X, A
	DEC	X
	BPL	-

	JMP	IncAndFinishEvent
; =============================================================================
ApplyVolMod:	; $C59
	; calculate sound volume with following formula:
	; Volume*Modifier/100
	; Then, clip the result to [-128;127].
	CMP	X, #8
	BCS	ApplyVolMod2_ret	; don't change volume for SFXs
	MOV	Y, BGMVol
ApplyVolMod2:
	MOV	X, #100
	OR	A, #0
	BMI	.minus
	MUL	YA
	DIV	YA, X
	BMI	+	; branch if A >= 128
	BVS	+	; Unlikely, but branch on overflow.
	MOV	X, CurrentTrack
.ret:	RET
; -----------------------------------------------------------------------------
+	MOV	A, #127
	MOV	X, CurrentTrack
	RET
; -----------------------------------------------------------------------------
.minus:
	EOR	A, #-1
	INC	A
	MUL	YA
	DIV	YA, X
	BMI	+	; branch if A >= 128
	BVS	+	; Unlikely, but branch on overflow.
	EOR	A, #-1
	INC	A
	MOV	X, CurrentTrack
	RET
; -----------------------------------------------------------------------------
+	MOV	A, #-128
	MOV	X, CurrentTrack
	RET
; =============================================================================
SetVolumePreset:	; $C83
	MOV	A, (0)+Y
	MOV	VolPreset1_L, A
	INC	Y
	MOV	A, (0)+Y
	MOV	VolPreset1_R, A
	INC	Y
	MOV	A, (0)+Y
	MOV	VolPreset2_L, A
	INC	Y
	MOV	A, (0)+Y
	MOV	VolPreset2_R, A
	JMP	IncAndFinishEvent
; =============================================================================
RestoreEcho:
	CLR6	GlobalFlags

	MOV	DSPAddr, #$4D
	MOV	DSPData, EchoOnShadow	; Restore echo enable flags.

	MOV	X, #7
	MOV	DSPAddr, #$8F	; FIR 8th tap + $10.
	SETC
-	SBC	DSPAddr, #$10
	XCN	A		; Delay.
	XCN	A		; Delay.
	MOV	A, SndFIRShadow+X
	MOV	DSPData, A
	DEC	X
	BPL	-
	RET
; =============================================================================
SetEchoDelay:	; $CA0
	MOV	A, (0)+Y
	AND	A, #$1E
	BEQ	+
	MOV	2, A

	; Clear FIR echo filter taps
	MOV	A, #0
	MOV	DSPAddr, #$F
	CLRC
-	MOV	DSPData, A
	ADC	DSPAddr, #$10
	BPL	-

	MOV	DSPAddr, #$4D
	MOV	DSPData, A	; disable echo input

	MOV	A, 2
	SET5	DSPAddr		; echo buffer location
	ASL	A
	ASL	A
	EOR	A, #-1
	MOV	DSPData, A

	SET4	DSPAddr		; echo delay
	MOV	A, 2
	LSR	A
	MOV	DSPData, A

	; Set a flag in the echo buffer.
	; We will be waiting until it is cleared.
	MOV	A, #1
	MOV	EchoBufEnd, A

	SET6	GlobalFlags

+	JMP	IncAndFinishEvent
; =============================================================================
Jump:	; $CD7
	MOV	A, (0)+Y	; LSB
	MOV	2, A
	INC	Y
	MOV	A, (0)+Y	; MSB
	MOV	1, A
	MOV	0, 2
	MOV	Y, #0
	JMP	FinishEvent
; =============================================================================
CallSub:	; $CE6
	MOV	A, (0)+Y	; repeat count
	MOV	2, A
	INC	Y

CallSub2:
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
; =============================================================================
CallSubOnce:	; $CFF
	MOV	2, #1
	JMP	CallSub2
; =============================================================================
RetSub:	; $D34
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
; Enables default (stored) note/rest duration.
; The LSB value of zero is illegal as it effectively disables the mode.
SetDefaultDuration:	; $D70
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	BBC1	TempFlags, +
	MOV	DfltNoteDur_H+X, A
	INC	Y
	MOV	A, (0)+Y
+	MOV	DfltNoteDur_L+X, A
	JMP	IncAndFinishEvent
; =============================================================================
; Switches back to inline duration mode.
DisableDfltDuration:	; $D8F
	MOV	X, CurrentTrack
	MOV	A, #0
	MOV	DfltNoteDur_L+X, A
	MOV	DfltNoteDur_H+X, A
	JMP	FinishEvent
; =============================================================================
SetPitchSlide_1:	; $D9B
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
SetPitchSlide_2:	; $DA2
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
DisablePitchSlide:	; $DD6
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
DisableVibrato:	; $E05
	MOV	X, CurrentTrack
	MOV	A, #0
	MOV	VibDelta+X, A
	JMP	FinishEvent
; =============================================================================
SetVibrato_1:	; $E11
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
SetVibrato_2:	; $E1A
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
SetADSR_1:	; $E45
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndADSR1+X, A ; ADSR 1
	INC	Y
	MOV	A, (0)+Y
	MOV	SndADSR2+X, A ; ADSR 2
	JMP	IncAndFinishEvent
; =============================================================================
SetVarNote1:	; $E5A
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	VarNote0+X, A
	JMP	IncAndFinishEvent
; =============================================================================
SetVarNote2:	; $E64
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	VarNote1+X, A
	JMP	IncAndFinishEvent
; =============================================================================
Tuning:	; $E71
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndFineTune+X, A
	JMP	IncAndFinishEvent
; =============================================================================
SetTranspose:	; $E7B
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	Transpose+X, A
	JMP	IncAndFinishEvent
; =============================================================================
AddTranspose:	; $E88
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	ADC	A, Transpose+X
	MOV	Transpose+X, A
	JMP	IncAndFinishEvent
; =============================================================================
SetEcho:	; $E97
	MOV	DSPAddr, #$D	; echo feedback
	MOV	A, (0)+Y
	MOV	DSPData, A
	INC	Y

	MOV	DSPAddr, #$2C	; echo left channel
	MOV	A, (0)+Y
	MOV	DSPData, A
	INC	Y

	SET4	DSPAddr		; echo right channel
	MOV	A, (0)+Y
	MOV	DSPData, A

	JMP	IncAndFinishEvent
; =============================================================================
EchoOn:	; $EC4
	SET2	TempFlags
	JMP	FinishEvent
; =============================================================================
EchoOff:	; $EDC
	CLR2	TempFlags
	JMP	FinishEvent
; =============================================================================
EchoFilter:	; $EF6
	MOV	X, #0
	MOV	DSPAddr, #$F	; FIR 1st tap

-	MOV	A, (0)+Y
	MOV	SndFIRShadow+X, A
	BBS6	GlobalFlags, +
	MOV	DSPData, A
+	INC	X
	INC	Y
	ADC	DSPAddr, #$10
	BPL	-

	JMP	FinishEvent
; =============================================================================
SetNoiseFreq:	; $F10
	MOV	A, (0)+Y
	MOV	DSPAddr, #$6C	; DSP flags
	MOV	DSPData, A
	JMP	IncAndFinishEvent
; =============================================================================
NoiseOn:	; $F23
	SET3	TempFlags
	JMP	FinishEvent
; =============================================================================
NoiseOff:	; $F34
	CLR3	TempFlags
	JMP	FinishEvent
; =============================================================================
SetPitchSlide_4:	; $F44
	MOV	X, CurrentTrack
	MOV	A, (0)+Y ; delay
	MOV	PitchSlideDelay+X, A
	INC	Y
	MOV	A, (0)+Y ; portamento interval
	MOV	PitchSlideInterval+X, A
	INC	Y
	MOV	A, (0)+Y ; portamento steps
	MOV	PitchSlideStepsDown+X, A
	ASL	A
	MOV	PitchSlideSteps+X, A
	INC	Y
	MOV	A, (0)+Y ; pitch delta
	EOR	A, #-1
	INC	A
	MOV	PitchSlideDelta+X, A
	JMP	IncAndFinishEvent
; =============================================================================
SetPitchSlide_5:	; $F4E
	MOV	X, CurrentTrack
	MOV	A, (0)+Y ; delay
	MOV	PitchSlideDelay+X, A
	INC	Y
	MOV	A, (0)+Y ; portamento interval
	MOV	PitchSlideInterval+X, A
	INC	Y
	MOV	A, (0)+Y ; portamento steps
	MOV	PitchSlideStepsDown+X, A
	ASL	A
	MOV	PitchSlideSteps+X, A
	INC	Y
	MOV	A, (0)+Y ; pitch delta
	MOV	PitchSlideDelta+X, A
	JMP	IncAndFinishEvent
; =============================================================================
LongDurationOn:	; $F7C
	SET1	TempFlags
	JMP	FinishEvent
; =============================================================================
LongDurationOff:	; $F86
	CLR1	TempFlags
	JMP	FinishEvent
; =============================================================================
SetUpEngine:	; $100B
	BBC5	GlobalFlags, +

	MOV	Timer1, #100

	MOV	Y, #64
	MOV	A, #$C		; Master left volume
	MOVW	DSPAddr, YA
	MOV	A, #$1C		; Master right volume
	MOVW	DSPAddr, YA

	MOV	A, #$5D		; Source directory
	MOV	Y, #SourceDir>>8
	MOVW	DSPAddr, YA

	MOV	A, #$2D		; Pitch modulation which is unused
	MOV	Y, #0
	MOVW	DSPAddr, YA

	MOV	A, #$F		; FIR filter
	CLRC
-	MOVW	DSPAddr, YA
	ADC	A, #$10
	BPL	-

	MOV	A, Y
	MOV	Y, #8
-	MOV	SndFIRShadow-1+Y, A
	DBNZ	Y, -

+	MOV	A, #$5C		; Key-off
	MOV	Y, #-1
	MOVW	DSPAddr, YA

	MOV	DSPAddr, #$6C
	AND	DSPData, #$1F

	MOV	A, #0
	MOV	ControlReg, A
	MOV	Y, A
	MOVW	GlobalFlags, YA		; Also clears CurPreprocTrack.
	MOVW	SndNewPitchOffset, YA	; clear pitch offset for SFX channel #5
	;MOVW	SndPitchOffset, YA
	MOV	SFXCount, #1
	MOV	EchoOnShadow, A
	MOV	Timer0Ticks, #1
	MOV	Timer1Ticks, #1

	MOV	BGMVol, #100

	;mov	A, #0
	MOV	0, #8
	MOV	X, A

-	MOV	A, #1
	MOV	NoteDur_L+X, A	; set delay duration to 1
	MOV	SndFlags+X, A
	MOV	A, (2)+Y
	MOV	TrkPtr_L+X, A
	INC	Y
	MOV	A, (2)+Y
	MOV	TrkPtr_H+X, A
	MOV	A, X
	ASL	A
	ASL	A
	ASL	A
	MOV	SndStackPtr+X, A
	MOV	A, #0
	MOV	NoteDur_H+X, A
	MOV	DfltNoteDur_L+X, A
	MOV	DfltNoteDur_H+X, A
	MOV	SndFlags+8+X, A
	MOV	Transpose+X, A
	MOV	SndFineTune+X, A
	MOV	PitchSlideDelta+X, A
	MOV	VibDelta+X, A

	; set ADSR to $FE-$C1
	MOV	A, #$FE
	MOV	SndADSR1+X, A
	MOV	A, #$C1
	MOV	SndADSR2+X, A

	INC	X
	INC	Y
	DBNZ	0, -

	MOV	A, (2)+Y
	MOV	BGMTempo, A
	RET
;==============================================================================
SetUpSFX:	; $10F7
	; inputs:
	; A: ID of SFX
	; X: number of channel SFX to be played at
	MOV	0, A
	CMP	A, #$60
	BPL	loc_1104	; branch if ID >= $60

	CMP	A, SFX_IndexBound0
	BPL	loc_110D	; out of range if ID >= bound
	JMP	loc_1111
; -----------------------------------------------------------------------------
loc_1104:
	SETC
	SBC	A, #$60
	CMP	A, SFX_IndexBound1
	BMI	loc_1111	; out of range if ID >= bound

loc_110D:
	; if ID is out of range, replace given SFX with "Stop SFX" command
	MOV	0, #0
loc_1111:

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

	; set center volume to -128
	MOV	A, #-128
	MOV	SndVol_L+8+X, A
	MOV	SndVol_R+8+X, A

	; set ADSR to $FE-$C1
	MOV	A, #$FE
	MOV	SndADSR1+8+X, A
	MOV	A, #$C1
	MOV	SndADSR2+8+X, A

	; Arpeggiate composite SFXs
	MOV	A, SFXCount
	INC	SFXCount
	MOV	NoteDur_L+8+X, A

	; set track pointer
	MOV	A, 0
	ASL	A
	CMP	A, #$C0	; $60
	BCS	+
	MOV	Y, A
	MOV	A, SFX_PtrTable0+Y
	MOV	TrkPtr_L+8+X, A
	MOV	A, SFX_PtrTable0+1+Y
	MOV	TrkPtr_H+8+X, A
	RET
; -----------------------------------------------------------------------------
+	SETC
	SBC	A, #$C0
	MOV	Y, A
	MOV	A, SFX_PtrTable1+Y
	MOV	TrkPtr_L+8+X, A
	MOV	A, SFX_PtrTable1+1+Y
	MOV	TrkPtr_H+8+X, A
	RET
; =============================================================================
VoiceBitMask:	; $F95
	DB	1, 2, 4, 8, $10, $20, $40, $80
; =============================================================================
CtrlEventIndex:	; $FA5
	DW	StopTrack		; $00	; individual effect
	DW	SetInstrument		; $01	; individual effect (no rest required)
	DW	SetVolume		; $02	; individual effect (no rest required)
	DW	Jump			; $03	; individual effect (no rest required)
	DW	CallSub			; $04	; individual effect (no rest required)
	DW	RetSub			; $05	; individual effect (no rest required)
	DW	SetDefaultDuration	; $06	; individual effect (no rest required)
	DW	DisableDfltDuration	; $07	; individual effect (no rest required)
	DW	SetPitchSlide_1		; $08	; individual effect
	DW	SetPitchSlide_2		; $09	; individual effect
	DW	DisablePitchSlide	; $0A	; individual effect
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
	DW	NoiseOn			; $1A	; individual effect (no rest required)
	DW	NoiseOff		; $1B	; individual effect (no rest required)
	DW	SetVarNote1		; $1C	; individual effect (no rest required)
	DW	SetVarNote2		; $1D	; individual effect (no rest required)
	DW	SetVolumePreset		; $1E	; global effect
	DW	SetEchoDelay		; $1F	; global effect
	DW	UsePresetVolume1	; $20	; global effect
	DW	CallSubOnce		; $21	; individual effect (no rest required)
	DW	SetVoiceParams		; $22	; individual effect (no rest required)
	DW	SetCentreVolume		; $23	; individual effect (no rest required)
	DW	SetBGMVol		; $24	; global effect
	DW	0			; $25	; global effect
	DW	SetPitchSlide_4		; $26	; individual effect
	DW	SetPitchSlide_5		; $27	; individual effect
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
; =============================================================================
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
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	0	; global effect
	DB	0	; global effect
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
;==============================================================================
PitchTable:
	; this section contains raw pitch values for S-DSP
	DW	0
	DW	64,	67,	71,	76,	80,	85
	DW	90,	95,	101,	107,	114,	120
	DW	128,	135,	143,	152,	161,	170
	DW	181,	191,	203,	215,	228,	241
	DW	256,	271,	287,	304,	322,	341
	DW	362,	383,	406,	430,	456,	483
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
	DW	16383
