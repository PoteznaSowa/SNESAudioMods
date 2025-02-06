; Modified Rare's Donkey Kong Country 2 and 3 sound engine.
; Based on Donkey Kong Country 2 and 3 sound engine disassembly.
; Author: PoteznaSowa.

; Some changes included in the mod:
; - optimised code, unused features removed, data transfer sped up;
; - added preprocessing of sound sequence data in background;
; - music runs at variable SPC timer period instead of
;   using a single fixed-period timer in the original design;
; - improved stereo to mono downmix;
; - improved echo buffer initialisation to fix audible glitches
;   at some occasions


; Page 0 variables
	ORG	0
		skip 6	; scratch RAM for intermediate data
TempFlags:	skip 1
CurrentTrack:	skip 1	; Track number
CurVoiceBit:	skip 1	; S-DSP voice bit
CurVoiceAddr:	skip 1	; S-DSP voice address
KeyOnShadow:	skip 1	; key-on bitmask

NextMsg:	skip 1	; Next message number

; Bit field
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
SndPitchOffset:	skip 2	; Current pitch offset for SFX channel #5
SFXDelay:	skip 1	; Initial SFX length
BGMVol:		skip 1	; current BGM volume
VolPreset1_L:	skip 1	; Global voice volume presets
VolPreset1_R:	skip 1
VolPreset2_L:	skip 1
VolPreset2_R:	skip 1

	ORG	$20

; Array of bit fields
; 0: active
; 1: long duration on
; 2: echo on
; 3: noise on
; 5: overridden by SFX
; 6: ready for key-on
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
Timer2:		skip 1	; $FC	; 1/64 ms (64000 Hz) timer. Unused.
Timer0_out:	skip 1	; $FD	; Number of timer 0 ticks.
Timer1_out:	skip 1	; $FE	; Number of timer 1 ticks.
Timer2_out:	skip 1	; $FF	; Number of timer 2 ticks.


; I had to move the one-sample echo buffer somewhere else but $FF00..$FF03.
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

DfltNoteDur_L:	skip 16	; Current default duration.
DfltNoteDur_H:	skip 16

PitchSlideDelay:	skip 16	; stored pitch slide delay
PitchSlideInterval:	skip 16	; stored pitch slide interval (time between steps)
PitchSlideDelta:	skip 16	; pitch slide pitch delta (linear, signed)
PitchSlideSteps:	skip 16	; stored total pitch slide steps
PitchSlideStepsDown:	skip 16	; pitch slide steps in opposite direction

VibDelay:	skip 16	; stored vibrato delay
VibInterval:	skip 16	; stored vibrato interval (time between steps) 
VibDelta:	skip 16	; vibrato pitch delta (linear, signed)
VibLen:		skip 16	; steps per vibrato cycle

SndEnvLvl:	skip 16	; last measured ADSR envelope level

; Subroutine stack. The maximum nest level is 8.
Stack_PtrL:	skip 128
Stack_PtrH:	skip 128
Stack_RepCnt:	skip 128	; stack repeat count

SndFIRShadow:	skip 8	; contains echo FIR filter coefficients

; DSP register addresses
DSP_VOL =	0
DSP_VOLL =	0
DSP_VOLR =	1
DSP_PITCH =	2
DSP_PITCHL =	2
DSP_PITCHH =	3
DSP_SRCN =	4
DSP_ADSR =	5
DSP_ADSR1 =	5
DSP_ADSR2 =	6
DSP_GAIN =	7
DSP_ENV =	8
DSP_OUT =	9
DSP_MVOLL =	$0C
DSP_MVOLR =	$1C
DSP_EVOLL =	$2C
DSP_EVOLR =	$3C
DSP_KON =	$4C
DSP_KOFF =	$5C
DSP_FLG =	$6C
DSP_ENDX =	$7C
DSP_EFB =	$0D
DSP_PMON =	$2D
DSP_NON =	$3D
DSP_EON =	$4D
DSP_DIR =	$5D
DSP_ESA =	$6D
DSP_EDL =	$7D
DSP_FIR =	$0F

; Locations of external data.

MusicData =		$1300
MusicIndex =		$1312

; Sound data for SFXs $00..$5F
SFXIndexBound0 =	$2410
SFXPtrTable0 =		$2412

; Sound data for SFXs $60..$7F
SFXIndexBound1 =	$2E94
SFXPtrTable1 =		$2E96

SourceDir =		$3100
EchoBufEnd =		$FEFE


	arch spc700
	optimize dp always

	ORG	EngineBase
	base	$4D8
; =============================================================================
EntryPoint:
	MOV	X, #PrgStackBase&$FF
	MOV	SP, X
	MOV	X, #0
	MOV	Port0, X	; Tell SNES we are in this transfer routine
	MOV	DSPAddr, #$7D
	MOV	DSPData, X	; Set echo delay to 0
	INC	X		; X = 1
	SET5	GlobalFlags	; Indicate a cold reset

TransferMode:
	; Reset echo buffer settings.
	MOV	A, #$6D
	MOV	Y, #EchoSample>>8
	MOVW	DSPAddr, YA

--	CMP	X, Port0	; has SNES sent the next data word?
	BNE	--		; branch if no
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
; and sends a message to begin music:
; $7206 $0000 $00FE $00FA
; Each time a word of data is sent, SNES increments word counter at Port 0.
; See GetMessage for more information
; =============================================================================
	base off
	ORG	EngineBase+$88
	base	$560
; =============================================================================
; The table stores SRCNs for up to 256 samples.
; During data transfer, SNES builds it and sends to the engine.
TimbreLUT:
	REP 256 : DB 0
; =============================================================================
; This engine can play additional music without entering transfer routine.
; Get the pointer to a song from the array at $1312 with Y as an index.
PlayIndexedBGM:
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
	MOVW	0, YA
	CALL	SetUpEngine	; set up S-DSP and music

; Check if there's an incoming message from SNES and process it.
; To play a composite SFX (played at more than one channel), SNES sends more
; than a single message.
GetMessage:
	CMP	Port0, NextMsg	; has SNES sent the next data word?
	BNE	MainLoop	; branch if no
	MOVW	YA, Port1	; read message word
	MOV	Port0, NextMsg	; reply to SNES
	INC	NextMsg	; increment message counter
	MOV	X, A	; is the first message byte negative?
	BMI	+	; branch if yes

	CMP	Y, #8
	BCS	GetMessage	; Do not set up a SFX on an invalid channel.
	MOV	CurPreprocTrack, Y
	SET3	CurPreprocTrack
	CALL	PlaySFX
	JMP	GetMessage
; =============================================================================
+	AND	A, #7		; Clear unwanted bits.
	ASL	A
	MOV	X, A
	JMP	(MessageIndex+X)	; Process the message.
; =============================================================================

; Events are strictly prioritised in the following order:
; - messsages from SNES;
; - Timer 0 (BGM) ticks;
; - Timer 1 (SFX) ticks.
; If none is happening at the moment, do one iteration of asynchronous sound
; sequence processing.
MainLoop:
	BBC0	GlobalFlags, GetMessage	; branch if the sound has not started yet
	BBC6	GlobalFlags, +

	; Check if the echo buffer has been cleared.
	; The DSP writes 15-bit samples into the buffer and always clears the
	; rightmost bit of the 16-bit value.
	MOV	A, EchoBufEnd
	LSR	A
	BCS	+
	CALL	RestoreEcho

+	MOV	A, Timer0_out	; has the BGM timer ticked?
	BEQ	SkipBGMUpdate	; branch if no
	BBC1	GlobalFlags, +	; Branch if tempo not halved.
	BBS2	GlobalFlags, SkipBGMUpdate2	; Skip updates every second tick.
+	SET2	GlobalFlags
	MOV	CurrentTrack, #0
	CALL	UpdateTracks
++	JMP	GetMessage
; -----------------------------------------------------------------------------
SkipBGMUpdate2:
	CLR2	GlobalFlags
SkipBGMUpdate:
	MOV	A, Timer1_out		; has the main timer ticked?
	BEQ	PreprocessTracks	; branch if no

	MOV	CurrentTrack, #8
	CALL	UpdateTracks

	MOV	CurrentTrack, #0
	MOV	DSPAddr, #2	; Go to channel #0 pitch

UpdateTracks2:
	MOV	X, CurrentTrack
	MOV	A, SndFlags+X
	AND	A, #$20		; is the channel used by SFX?
	BEQ	+		; branch if no
	SET3	CurrentTrack	; process a SFX channel instead
+	MOV	X, CurrentTrack
	MOV	A, SndFlags+X
	BPL	+
	CALL	UpdateTrack_2	; update pitch bend
+	CLR3	CurrentTrack	; revert to BGM
	INC	CurrentTrack
	CLRC
	ADC	DSPAddr, #$10	; Go to next channel pitch
	BPL	UpdateTracks2

	DBNZ	SFXDelay, GetMessage	; Decrement the initial SFX pre-silence length.
	INC	SFXDelay		; Limit it to 1, though.
	JMP	GetMessage
; -----------------------------------------------------------------------------

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
	CALL	PreprocessTracks2
	JMP	GetMessage
; =============================================================================
PreprocessTracks2:
	CLR4	CurPreprocTrack
	MOV	X, CurPreprocTrack
	INC	CurPreprocTrack

	MOV	A, SndFlags+X	; Load track flags.
	MOV	TempFlags, A
	BBC0	TempFlags, SkipPreproc	; Branch if not active.
	BBS6	TempFlags, SkipPreproc	; Branch if ready for key-on.

	; Prepare the DSP address and voice bitmask variables.
	; Also, read the ENVX register to check if the channel is audible.
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
	BCS	+	; Branch if the envelope is not ramping down.
	MOV	Y, A	; Has it fallen to zero though?
	BNE	+	; Branch if not.
	CLR7	TempFlags	; Clear the "channel audible" flag.

+	MOV	CurrentTrack, X
	MOV	A, TrkPtr_L+X	; load the track pointer
	MOV	Y, TrkPtr_H+X
	MOVW	0, YA
	MOV	Y, #0
	MOV	A, (0)+Y		; read a track byte
	BMI	Preproc_RestOrNote	; branch if this is a note or a rest
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
	JMP	(TrackEventIndex+X)	; run the sound event
; -----------------------------------------------------------------------------
Preproc_RestOrNote:
	BBS7	TempFlags, FinishPreproc	; Branch if audible.

	CMP	A, #$80
	BEQ	Preproc_Rest	; Branch if rest.

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
	MOVW	YA, 2
	BNE	+
	INCW	2	; Treat zero duration as one.
+	MOV	A, NoteDur_L+X
	MOV	Y, NoteDur_H+X
	ADDW	YA, 2	; Add the rest length to the current rest duration.
	BCS	+	; Branch if the result does not fit into 16 bits.
	MOV	NoteDur_L+X, A	; Store the result.
	MOV	NoteDur_H+X, Y
	MOV	A, 4
	MOV	Y, #0
	ADDW	YA, 0	; Add the track offset to the pointer.
	MOV	TrkPtr_L+X, A	; store pointer LSB
	MOV	TrkPtr_H+X, Y	; store pointer MSB
+	JMP	FinishPreproc
; =============================================================================
GotoPlayIndexedBGM:
	MOV	0, Y

	; Set all channels to fade out.
	MOV	A, #7
	MOV	Y, #$BF		; Exponential fade-out, rate 15
-	MOVW	DSPAddr, YA
	CLR1	DSPAddr
	CLR7	DSPData
	ADC	A, #$10
	BPL	-

	MOV	Y, 0
	JMP	PlayIndexedBGM
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
MessageF8:	; formerly used to set a BGM mailslot or something?
MessageF9:	; formerly used to set a BGM mailslot or something?
	JMP	GetMessage
; =============================================================================
; Change pitch modifier for SFX at channel #5.
; Used to adjust pitch of the sound of riding a vehicle in DKC2 (Skull Cart)
; and DKC3 (various vehicles from Funky's Rentals).
; Offset=Argument*8
AdjustSFXPitch:
	BBC7	SndFlags+8+5, ++	; Do not bother if the SFX inaudible.

	; Sign-extend and multiply by 8.
			; Y: s6543210
	MOV	2, Y	; offset: ???????? s6543210
	MOV	A, #0
	ASL	2	; offset: ???????? 6543210-
	BCC	+	; A = ssssssss
	DEC	A
+	ASL	2	; offset: ???????? 543210--
	ROL	A	; A: sssssss6
	ASL	2	; offset: ???????? 43210---
	ROL	A	; A: ssssss65
	MOV	3, A	; offset: ssssss65 43210---

	MOVW	YA, 2
	SUBW	YA, SndPitchOffset
	MOVW	0, YA
	MOVW	YA, 2
	MOVW	SndPitchOffset, YA

	MOV	DSPAddr, #$52
	CALL	WritePitchDelta		; Apply changes.
++	JMP	GetMessage
; =============================================================================
; Change the volume of SFX at channel #5.
; Volume = Volume * Modifier / 100
AdjustSFXVol:
	MOV	0, Y
	MOV	DSPAddr, #$50
	MOV	X, #100
	MOV	A, DSPData
	CALL	MulDiv2
	MOV	DSPData, A
	INC	DSPAddr
	MOV	Y, 0
	MOV	X, #100
	MOV	A, DSPData
	CALL	MulDiv2
	MOV	DSPData, A
	JMP	GetMessage
; =============================================================================
; Start processing music and sound effects.
StartEngine:
	MOV	ControlReg, #0

	;MOV	ControlReg, Y
	;MOVW	Timer0, YA	; Set timers 0 and 1 to 32 ms.

	MOV	A, #$6C
	MOV	Y, #0
	MOVW	DSPAddr, YA

	MOV	A, #192
	MOV	Y, A
	MOVW	Timer0, YA	; Set timers 0 and 1 to 24 ms.

	MOV	ControlReg, #3	; Start timers 0 and 1.
	CALL	TempoToInterval2
	MOV	Timer1, #100	; Set timer 1 to 12.5 ms.
	SET0	GlobalFlags
	JMP	GetMessage
; =============================================================================
; Stop the engine and enter transfer mode.
GotoTransferMode:
	; Set all channels to fade out.
	MOV	A, #7
	MOV	Y, #$BF		; Exponential fade-out, rate 15
-	MOVW	DSPAddr, YA
	CLR1	DSPAddr
	CLR7	DSPData
	ADC	A, #$10
	BPL	-

	; Fade out FIR filter taps.
	MOV	DSPAddr, #$F
-	MOV	A, DSPData
	BPL	+
	INC	DSPData
	BNE	-
+	BEQ	+
	DBNZ	DSPData, -
+	ADC	DSPAddr, #$10
	BPL	-

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
MessageIndex:
	DW	MessageF8, MessageF9		; $F8, $F9
	DW	SetMonoFlag, GotoPlayIndexedBGM	; $FA, $FB
	DW	AdjustSFXPitch, AdjustSFXVol	; $FC, $FD
	DW	StartEngine, GotoTransferMode	; $FE, $FF
; =============================================================================
; Set the current channel to fade out.
; It takes up to 676 samples to fade to silence.
SoftKeyRelease:
	BBS5	TempFlags, +	; Skip if channel in use by SFX.
	BBS6	TempFlags, +	; Skip if a note is ready for key-on.
	MOV	A, CurVoiceAddr
	OR	A, #7
	MOV	Y, #$BF		; Exponential fade-out, rate 15
	MOVW	DSPAddr, YA
	CLR1	DSPAddr
	CLR7	DSPData
	MOV	A, #1
	MOV	SndEnvLvl+X, A	; The ADSR envelope will be ramping down.
+	RET
; =============================================================================
TempoToInterval2:
	MOV	A, BGMTempo

; Convert BGM tempo at register A to a timer period.
; Period=25600/Tempo
TempoToInterval:
	CLR1	GlobalFlags	; Clear the ‘halve BGM tempo’ flag.
	MOV	2, Y	; Preserve Y.
	MOV	X, A
	MOV	A, #0
	MOV	Y, #$64	; YA = 25600
	DIV	YA, X
	BVC	+	; branch if quotient < 256
	BEQ	+	; branch if quotient = 256
	SETC
	ROR	A	; A = (A >> 1) | $80
	SET1	GlobalFlags	; Set the ‘halve BGM tempo’ flag.
+	MOV	Timer0, A
	MOV	Y, 2
	RET
; =============================================================================
UpdateTracks:
	; Initialise variables for channel #0.
	MOV	A, #1
	MOV	Y, #0
	MOVW	CurVoiceBit, YA	; Also initialises CurVoiceAddr
	MOV	KeyOnShadow, Y
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
	DEC	Y
	BPL	+
	DEC	NoteDur_H+X
	JMP	ContinueNote
; -----------------------------------------------------------------------------
+	MOV	A, NoteDur_H+X
	BNE	ContinueNote
	DBNZ	Y, FetchNextEvent
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

	; Wait a little bit to work around a buggy SPC dumper in Snes9x.
	MUL	YA

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
	JMP	(TrackEventIndex+X)	; Run an event handler.
; =============================================================================
SetInstrument:
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndTimbre+X, A	; Store the logical instrument index.

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
	MOV	SndEnvLvl+X, A	; The ADSR envelope will be ramping up.

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
	MOV	A, NoteDur_L+X
	OR	A, NoteDur_H+X
	BNE	+
	INC	NoteDur_L+X	; Treat zero duration as one.
+	MOV	A, TempFlags
	MOV	SndFlags+X, A
	JMP	FinishTrackUpdate
; =============================================================================
PrepareNote:
	MOV	DSPAddr, #$5C
	MOV	DSPData, CurVoiceBit	; Key-off the channel.

	; Note event ranges:
	; $81..$DB - normal note
	; $E0 - variable note 1
	; $E1 - variable note 2
	CMP	A, #$E0
	BCC	+++
	BEQ	+
	MOV	A, VarNote1+X
	JMP	++
; -----------------------------------------------------------------------------
+	MOV	A, VarNote0+X
++	CLRC
+++	ADC	A, #36	; Three-octave adjustment
	ADC	A, Transpose+X
	ASL	A

	; Fine-tune the note using the following formula:
	; P = ⌊Pb+(Pb*T/1024)⌋, where:
	; P is the result pitch value;
	; T is signed fine-tune offset;
	; Pb is the base pitch value from the LUT.
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
	MOV	A, PitchTable+1+X	; read MSB of seed pitch value
	MOV	Y, A
	MOV	A, PitchTable+X	; read LSB of seed pitch value
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
	MOV	A, PitchSlideDelay+X		; delay
	BNE	+
	MOV	A, PitchSlideInterval+X		; interval
+	MOV	t_PitchSlideTimer+X, A
	MOV	A, PitchSlideSteps+X		; total up/down steps
	MOV	t_PitchSlideSteps+X, A

	; Copy initial vibrato parameters.
	MOV	A, VibDelta+X
	BPL	+	; Δ = abs(Δ)
	EOR	A, #-1
	INC	A
	MOV	VibDelta+X, A
+
	MOV	A, VibLen+X			; cycle length
	LSR	A				; halve it
	MOV	t_VibSteps+X, A
	MOV	A, VibInterval+X		; interval

	; Now, I doubt both DKC2 and DKC3 ever have any vibrato parameters
	; where the sum of delay and step interval reaches 256. However, just
	; in case, I will write here some code which works around it.
	;BEQ	+				; branch if 256
	CLRC
	ADC	A, VibDelay+X			; delay
	;BCC	+
	;MOV	A, #0				; limit to 256
;+	
	MOV	t_VibTimer+X, A

	; write current sound parameters into DSP
	MOV	DSPAddr, CurVoiceAddr
	MOV	A, SndVol_L+X
	BBC4	GlobalFlags, ++	; Branch if stereo.

	; Downmix stereo to mono.
	; Vol = ⌊(abs(Vol_L)+abs(Vol_R)+1)/2⌋
	BPL	+	; Vol = abs(Vol)
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
	;EOR	A, #-1
	;INC	A
	CALL	MulDiv
	MOV	DSPData, A	; Left channel level
	JMP	+++
; -----------------------------------------------------------------------------
++	CALL	MulDiv
	MOV	DSPData, A	; Left channel level
	MOV	A, SndVol_R+X
	CALL	MulDiv
+++	INC	DSPAddr
	MOV	DSPData, A	; Right channel level
	INC	DSPAddr
	MOV	DSPData, 2	; LSB of pitch value
	INC	DSPAddr
	MOV	DSPData, 3	; MSB of pitch value
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
; Updates pitch slide and vibrato for a track.
UpdateTrack_2:
	MOV	A, #0
	MOV	Y, A
	MOVW	0, YA	; Set the initial delta to 0.

	MOV	A, t_PitchSlideSteps+X
	BEQ	DoVibrato
	DEC	t_PitchSlideTimer+X
	BNE	DoVibrato
	MOV	A, PitchSlideInterval+X
	MOV	t_PitchSlideTimer+X, A

	;MOV	Y, #0
	MOV	A, PitchSlideSteps+X
	SETC
	SBC	A, t_PitchSlideSteps+X
	CMP	A, PitchSlideStepsDown+X
	MOV	A, PitchSlideDelta+X	; get pitch offset
	BCS	+

	EOR	A, #-1		; negate it
	INC	A
+	BPL	+		; sign-extend it
	DEC	Y
+	MOVW	0, YA		; Store the delta.

	DEC	t_PitchSlideSteps+X

DoVibrato:
	DEC	t_VibTimer+X
	BNE	WritePitchDelta
	MOV	A, VibInterval+X
	MOV	t_VibTimer+X, A

	MOV	Y, #0
	MOV	A, VibDelta+X
	BPL	+
	DEC	Y
+	ADDW	YA, 0
	MOVW	0, YA

	DEC	t_VibSteps+X
	BNE	WritePitchDelta
	MOV	A, VibLen+X
	MOV	t_VibSteps+X, A
	MOV	A, VibDelta+X
	EOR	A, #-1		; Δ = -Δ
	INC	A
	MOV	VibDelta+X, A

WritePitchDelta:
	; Now add the delta to the current pitch value at the DSP.
	; Limit the pitch to the valid range of $0000..$3FFF.
	MOV	A, DSPData
	INC	DSPAddr
	MOV	Y, DSPData
	ADDW	YA, 0
	BMI	++
	CMP	Y, #$40
	BCS	+	; branch if pitch is out of range
	MOV	DSPData, Y
	DEC	DSPAddr
	MOV	DSPData, A
	RET
; -----------------------------------------------------------------------------
	; Set the maximum possible pitch.
+	MOV	DSPData, #$3F
	DEC	DSPAddr
	MOV	DSPData, #$FF
	RET
; -----------------------------------------------------------------------------
	; Set the minimum possible pitch. It may result in a DC bias, though.
++	MOV	DSPData, #0
	DEC	DSPAddr
	MOV	DSPData, #0
	RET
; =============================================================================
EndOfTrack:
	MOV	X, CurrentTrack
	DEC	Y
	MOV	A, Y
	MOV	Y, #0
	ADDW	YA, 0
	MOV	TrkPtr_L+X, A	; store pointer LSB
	MOV	TrkPtr_H+X, Y	; store pointer MSB
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
SetVoiceParams:
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndTimbre+X, A	; instrument
	INC	Y
	MOV	A, (0)+Y
	MOV	Transpose+X, A	; transpose
	INC	Y
	MOV	A, (0)+Y
	MOV	SndFineTune+X, A	; fine tune
	INC	Y
	MOV	A, (0)+Y
	MOV	SndVol_L+X, A	; left volume
	INC	Y
	MOV	A, (0)+Y
	MOV	SndVol_R+X, A	; right volume
	INC	Y
	MOV	A, (0)+Y
	MOV	SndADSR1+X, A	; ADSR 1
	INC	Y
	MOV	A, (0)+Y
	MOV	SndADSR2+X, A	; ADSR 2
	JMP	IncAndFinishEvent
; =============================================================================
SetVolume:
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndVol_L+X, A
	INC	Y
	MOV	A, (0)+Y
	MOV	SndVol_R+X, A
	JMP	IncAndFinishEvent
; =============================================================================
SetCentreVolume:
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndVol_L+X, A
	MOV	SndVol_R+X, A
	JMP	IncAndFinishEvent
; =============================================================================
UsePresetVol1:
	MOV	X, CurrentTrack
	MOV	A, VolPreset1_L
	MOV	SndVol_L+X, A
	MOV	A, VolPreset1_R
	MOV	SndVol_R+X, A
	JMP	FinishEvent
; =============================================================================
UsePresetVol2:
	MOV	X, CurrentTrack
	MOV	A, VolPreset2_L
	MOV	SndVol_L+X, A
	MOV	A, VolPreset2_R
	MOV	SndVol_R+X, A
	JMP	FinishEvent
; =============================================================================
SetBGMVol:
	MOV	A, (0)+Y
	CMP	A, BGMVol
	BEQ	+
	MOV	BGMVol, A

	; Invalidate all asynchronous note preparations.
	MOV	X, #7
-	MOV	A, SndFlags+X
	AND	A, #$BF
	MOV	SndFlags+X, A
	DEC	X
	BPL	-

+	JMP	IncAndFinishEvent
; =============================================================================
MulDiv:
	; Calculate sound volume using the following formula:
	; ⌊(Volume*Modifier+68)/133⌋
	; Then, clip the result to [-128;127].
	MOV	Y, BGMVol
	CMP	X, #8
	BCC	+		; don't change volume for SFXs
	MOV	Y, #100
+	MOV	X, #133		; Vol ≈ Vol * 3 / 4
	OR	A, #0
MulDiv2:
	CLRC
	BMI	.minus
	MUL	YA
	ADC	A, #68
	BCC	+
	INC	Y
+	DIV	YA, X
	BMI	+	; branch if A >= 128
	BVS	+
	MOV	X, CurrentTrack
	RET
; -----------------------------------------------------------------------------
+	MOV	A, #127
	MOV	X, CurrentTrack
	RET
; -----------------------------------------------------------------------------
.minus:
	EOR	A, #-1
	INC	A
	MUL	YA
	ADC	A, #68
	BCC	+
	INC	Y
+	DIV	YA, X
	BMI	+	; branch if A >= 128
	BVS	+
	EOR	A, #-1
	INC	A
	MOV	X, CurrentTrack
	RET
; -----------------------------------------------------------------------------
+	MOV	A, #-128
	MOV	X, CurrentTrack
	RET
; =============================================================================
SetVolumePreset:
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

	MOV	X, #7
	MOV	DSPAddr, #$8F	; FIR 8th tap + $10.
-	SETC
	SBC	DSPAddr, #$10
	MUL	YA		; 9-tick delay.
	MOV	A, SndFIRShadow+X
	MOV	DSPData, A
	DEC	X
	BPL	-
	RET
; =============================================================================
SetEchoDelay:
	MOV	A, (0)+Y
	AND	A, #$1E		; clear out garbage bits
	BEQ	+
	MOV	2, A

	; Clear FIR echo filter taps
	MOV	A, #0
	MOV	DSPAddr, #$F
	CLRC
-	MOV	DSPData, A
	ADC	DSPAddr, #$10
	BPL	-

	MOV	A, 2
	MOV	DSPAddr, #$6D	; echo buffer location
	ASL	A
	ASL	A
	EOR	A, #-1		; Make sure it ends at $FEFF.
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
JumpTrack:
	MOV	A, (0)+Y	; LSB
	MOV	2, A
	INC	Y
	MOV	A, (0)+Y	; MSB
	MOV	1, A
	MOV	0, 2
	MOV	Y, #0
	JMP	FinishEvent
; =============================================================================
CallSub:
	MOV	A, (0)+Y	; Read the repeat count.
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
CallSubOnce:
	MOV	2, #1
	JMP	CallSub2
; =============================================================================
RetSub:
	MOV	X, CurrentTrack

	MOV	Y, SndStackPtr+X
	MOV	A, Stack_PtrL-1+Y	; LSB
	MOV	0, A
	MOV	A, Stack_PtrH-1+Y	; MSB
	MOV	1, A

	MOV	A, Stack_RepCnt-1+Y
	DEC	A	; Decrement repeat count.
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
DefaultDurOn:
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	BBC1	TempFlags, +		; Branch if long duration mode is off.
	MOV	DfltNoteDur_H+X, A
	INC	Y
	MOV	A, (0)+Y
+	MOV	DfltNoteDur_L+X, A
	JMP	IncAndFinishEvent
; =============================================================================
; Switches back to inline duration mode.
DefaultDurOff:
	MOV	X, CurrentTrack
	MOV	A, #0
	MOV	DfltNoteDur_L+X, A
	MOV	DfltNoteDur_H+X, A
	JMP	FinishEvent
; =============================================================================
SetPitchSlide_1:
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
; Same as SetPitchSlide_1 but the delta is negated.
SetPitchSlide_2:
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
PitchSlideOff:
	MOV	X, CurrentTrack
	MOV	A, #0
	MOV	PitchSlideSteps+X, A
	JMP	FinishEvent
; =============================================================================
SetTempo:
	MOV	A, (0)+Y
	MOV	BGMTempo, A
	CALL	TempoToInterval
	JMP	IncAndFinishEvent
; =============================================================================
AddTempo:
	MOV	A, (0)+Y
	ADC	A, BGMTempo
	MOV	BGMTempo, A
	CALL	TempoToInterval
	JMP	IncAndFinishEvent
; =============================================================================
VibratoOff:
	MOV	X, CurrentTrack
	MOV	A, #0
	MOV	VibDelta+X, A
	JMP	FinishEvent
; =============================================================================
SetVibrato_1:
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
SetVibrato_2:
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
SetADSR_1:
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndADSR1+X, A ; ADSR 1
	INC	Y
	MOV	A, (0)+Y
	MOV	SndADSR2+X, A ; ADSR 2
	JMP	IncAndFinishEvent
; =============================================================================
SetVarNote1:
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	VarNote0+X, A
	JMP	IncAndFinishEvent
; =============================================================================
SetVarNote2:
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	VarNote1+X, A
	JMP	IncAndFinishEvent
; =============================================================================
SetFineTune:
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	SndFineTune+X, A
	JMP	IncAndFinishEvent
; =============================================================================
SetTranspose:
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	MOV	Transpose+X, A
	JMP	IncAndFinishEvent
; =============================================================================
AddTranspose:
	MOV	X, CurrentTrack
	MOV	A, (0)+Y
	ADC	A, Transpose+X
	MOV	Transpose+X, A
	JMP	IncAndFinishEvent
; =============================================================================
SetEchoParams:
	MOV	DSPAddr, #$D	; echo feedback
	MOV	A, (0)+Y
	MOV	DSPData, A
	INC	Y

	MOV	DSPAddr, #$2C	; echo left channel
	MOV	A, (0)+Y
	LSR	A
	ADC	A, (0)+Y	; Vol = ⌈Vol * 1.5⌉
	MOV	DSPData, A
	INC	Y

	SET4	DSPAddr		; echo right channel
	MOV	A, (0)+Y
	LSR	A
	ADC	A, (0)+Y	; Vol = ⌈Vol * 1.5⌉
	MOV	DSPData, A

	JMP	IncAndFinishEvent
; =============================================================================
EchoOn:
	SET2	TempFlags
	JMP	FinishEvent
; =============================================================================
EchoOff:
	CLR2	TempFlags
	JMP	FinishEvent
; =============================================================================
SetFIR:
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
SetNoiseFreq:
	MOV	A, (0)+Y
	MOV	DSPAddr, #$6C	; DSP flags
	MOV	DSPData, A
	JMP	IncAndFinishEvent
; =============================================================================
NoiseOn:
	SET3	TempFlags
	JMP	FinishEvent
; =============================================================================
NoiseOff:
	CLR3	TempFlags
	JMP	FinishEvent
; =============================================================================
; Same as SetPitchSlide_5 but the delta is negated.
SetPitchSlide_4:
	MOV	X, CurrentTrack
	MOV	A, (0)+Y ; delay
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
; Set a back-and-forth pitch slide.
SetPitchSlide_5:
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
LongNoteOn:
	SET1	TempFlags
	JMP	FinishEvent
; =============================================================================
LongNoteOff:
	CLR1	TempFlags
	JMP	FinishEvent
; =============================================================================
SetUpEngine:
	BBC5	GlobalFlags, +	; skip some init on warm reset

	MOV	Y, #96
	MOV	A, #$C		; Master left volume
	MOVW	DSPAddr, YA	; = 96
	MOV	A, #$1C		; Master right volume
	MOVW	DSPAddr, YA	; = 96

	MOV	A, #$5D		; Source directory
	MOV	Y, #SourceDir>>8
	MOVW	DSPAddr, YA

	MOV	A, #$2D		; Pitch modulation which is unused
	MOV	Y, #0
	MOVW	DSPAddr, YA

	MOV	A, #$F		; FIR filter
	CLRC
-	MOVW	DSPAddr, YA	; Clear a FIR tap.
	ADC	A, #$10
	BPL	-		; Repeat for each of 8 FIR taps.

	MOV	A, Y
	MOV	Y, #8
-	MOV	SndFIRShadow-1+Y, A
	DBNZ	Y, -

+	MOV	BGMVol, #100
	MOV	A, #0
	MOV	Y, A
	MOVW	GlobalFlags, YA		; Also clears CurPreprocTrack.
	MOV	SFXDelay, #1

	MOV	Y, #16
	MOV	A, (0)+Y
	MOV	BGMTempo, A
	MOV	X, #7

-	DEC	Y
	MOV	A, (0)+Y
	MOV	TrkPtr_H+X, A
	DEC	Y
	MOV	A, (0)+Y
	MOV	TrkPtr_L+X, A
	MOV	A, X
	ASL	A
	ASL	A
	ASL	A
	MOV	SndStackPtr+X, A

	MOV	A, #1
	MOV	NoteDur_L+X, A	; Set delay duration to 1.
	MOV	SndEnvLvl+X, A	; The ADSR envelope will be ramping down.
	DEC	A	; A = 0
	MOV	NoteDur_H+X, A
	MOV	DfltNoteDur_L+X, A
	MOV	DfltNoteDur_H+X, A
	MOV	SndFlags+8+X, A
	MOV	Transpose+X, A
	MOV	SndFineTune+X, A
	MOV	PitchSlideSteps+X, A
	MOV	VibDelta+X, A

	MOV	A, #$81
	MOV	SndFlags+X, A

	; Set default ADSR parameters:
	; Attack = 14
	; Decay Rate = 7
	; Sustain Level = 6
	; Sustain Rate = 1
	MOV	A, #$FE
	MOV	SndADSR1+X, A
	MOV	A, #$C1
	MOV	SndADSR2+X, A

	DEC	X
	BPL	-

	RET
; =============================================================================
PlaySFX:
	; inputs:
	; A: ID of SFX
	; Y: the channel number the SFX is to be played at
	MOV	0, A
	CMP	A, #$60
	BPL	+	; branch if ID >= $60

	CMP	A, SFXIndexBound0
	BPL	++	; out of range if ID >= bound
	JMP	+++
; -----------------------------------------------------------------------------
+	SETC
	SBC	A, #$60
	CMP	A, SFXIndexBound1
	BMI	+++	; out of range if ID >= bound

	; If ID is out of range, replace given SFX with "Stop SFX" command.
++	MOV	0, #0

+++	MOV	A, Y
	MOV	X, A
	XCN	A
	OR	A, #7
	MOV	DSPAddr, A
	MOV	DSPData, #$BF	; Exponential fade-out, rate 15
	CMP	SFXDelay, #1
	BNE	+
	CLR5	DSPData		; Linear fade-out, rate 15
+	CLR1	DSPAddr
	CLR7	DSPData
	MOV	A, #1
	MOV	SndEnvLvl+8+X, A	; The ADSR envelope will be ramping down.

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
	MOV	VibDelta+8+X, A
	MOV	PitchSlideSteps+8+X, A

	; Set volume to 127 at centre.
	MOV	A, #127
	MOV	SndVol_L+8+X, A
	MOV	SndVol_R+8+X, A

	; Set default ADSR parameters:
	; Attack = 14
	; Decay Rate = 7
	; Sustain Level = 6
	; Sustain Rate = 1
	MOV	A, #$FE
	MOV	SndADSR1+8+X, A
	MOV	A, #$C1
	MOV	SndADSR2+8+X, A

	; Arpeggiate composite SFXs.
	MOV	A, SFXDelay
	INC	SFXDelay
	MOV	NoteDur_L+8+X, A

	; Set track pointer.
	MOV	A, 0
	ASL	A
	MOV	Y, A
	CMP	Y, #$C0	; $60
	BCS	+
	MOV	A, SFXPtrTable0+Y
	MOV	TrkPtr_L+8+X, A
	MOV	A, SFXPtrTable0+1+Y
	MOV	TrkPtr_H+8+X, A
	RET
; -----------------------------------------------------------------------------
+	MOV	A, SFXPtrTable1-$C0+Y
	MOV	TrkPtr_L+8+X, A
	MOV	A, SFXPtrTable1+1-$C0+Y
	MOV	TrkPtr_H+8+X, A
	RET
; =============================================================================
VoiceBitMask:
	DB	1, 2, 4, 8, $10, $20, $40, $80
; =============================================================================
TrackEventIndex:
	; See https://loveemu.hatenablog.com/entry/20130819/SNES_Rare_Music_Spec for details
	DW	EndOfTrack	; $00	; individual effect
	DW	SetInstrument	; $01	; individual effect (no rest required)
	DW	SetVolume	; $02	; individual effect (no rest required)
	DW	JumpTrack	; $03	; individual effect (no rest required)
	DW	CallSub		; $04	; individual effect (no rest required)
	DW	RetSub		; $05	; individual effect (no rest required)
	DW	DefaultDurOn	; $06	; individual effect (no rest required)
	DW	DefaultDurOff	; $07	; individual effect (no rest required)
	DW	SetPitchSlide_1	; $08	; individual effect
	DW	SetPitchSlide_2	; $09	; individual effect
	DW	PitchSlideOff	; $0A	; individual effect
	DW	SetTempo	; $0B	; global effect
	DW	AddTempo	; $0C	; global effect
	DW	SetVibrato_1	; $0D	; individual effect
	DW	VibratoOff	; $0E	; individual effect
	DW	SetVibrato_2	; $0F	; individual effect
	DW	SetADSR_1	; $10	; individual effect (no rest required)
	DW	0		; $11	; global effect
	DW	SetFineTune	; $12	; individual effect (no rest required)
	DW	SetTranspose	; $13	; individual effect (no rest required)
	DW	AddTranspose	; $14	; individual effect (no rest required)
	DW	SetEchoParams	; $15	; global effect (but async)
	DW	EchoOn		; $16	; individual effect (no rest required)
	DW	EchoOff		; $17	; individual effect (no rest required)
	DW	SetFIR		; $18	; global effect (but async)
	DW	SetNoiseFreq	; $19	; global effect
	DW	NoiseOn		; $1A	; individual effect (no rest required)
	DW	NoiseOff	; $1B	; individual effect (no rest required)
	DW	SetVarNote1	; $1C	; individual effect (no rest required)
	DW	SetVarNote2	; $1D	; individual effect (no rest required)
	DW	SetVolumePreset	; $1E	; global effect
	DW	SetEchoDelay	; $1F	; global effect (but async)
	DW	UsePresetVol1	; $20	; global effect
	DW	CallSubOnce	; $21	; individual effect (no rest required)
	DW	SetVoiceParams	; $22	; individual effect (no rest required)
	DW	SetCentreVolume	; $23	; individual effect (no rest required)
	DW	SetBGMVol	; $24	; global effect
	DW	0		; $25	; global effect
	DW	SetPitchSlide_4	; $26	; individual effect
	DW	SetPitchSlide_5	; $27	; individual effect
	DW	0		; $28	; global effect
	DW	0		; $29	; global effect
	DW	0		; $2A	; global effect
	DW	LongNoteOn	; $2B	; individual effect (no rest required)
	DW	LongNoteOff	; $2C	; individual effect (no rest required)
	DW	0		; $2D	; global effect
	DW	0		; $2E	; global effect
	DW	0		; $2F	; global effect
	DW	EchoOff		; $30	; individual effect (no rest required)
	DW	UsePresetVol2	; $31	; global effect
	DW	EchoOff		; $32	; individual effect (no rest required)
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
	DB	-1	; global effect (but async)
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	-1	; global effect (but async)
	DB	0	; global effect
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	-1	; individual effect (no rest required)
	DB	0	; global effect
	DB	-1	; global effect (but async)
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
; =============================================================================
PitchTable:
	; This section contains raw pitch values for S-DSP.
	; Real SNES hardware tends to have a slightly, although not usually
	; audibly, higher audio sample rate than the nominal one of 32000 Hz.
	; Hence, the values here should be rounded down.
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

