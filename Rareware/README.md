# SNES sound engines used in Rareware games

## Donkey Kong Country SPC engine (RareSPC.asm)
Based on the disassembly of the original design, the audio engine used in Rare’s Donkey Kong Country was almost completely rewritten to add new features, fix bugs, remove dead code, and increase overall performance.

Added features:
- score data processing in the background when being idle;
- smooth BGM timer ticks by running an SPC700’s timer at a variable period;
- echo feedback fadeout on entering the transfer mode (to load score data and samples);
- softer key/note releases by using S-DSP’s GAIN per-voice registers instead of KOF;
- faster data transfers from SNES;
- faster processing of messages from SNES;
- lower latency of sound effects.

Bug fixes:
- voice pitch value will no longer get out of bounds, especially when processing pitch bends;
- if a song does not initialise ADSR parameters, default ones will be used;
- fixed BGM voice echo on/off events interfering with an SFX playing on the same channel.
- reduced some audio clipping/distortion caused by too high L/R levels.

Removed unused features:
- downmixing stereo to mono, as the game does not even have an option to toggle the stereo/mono mode;
- fading out all sounds, including echo;
- audio score/sequence conditional jump;
- voice volume and ADSR presets.

Known issues:
- some samples missing in sample sets (not a bug in the engine).

TODO:
- reduce SFX latency even further;
- refactor code comments.

## Donkey Kong Country 2/3 SPC engine (dkq_spc.asm, dkdt_spc.asm)
Like a previous one, this engine also underwent many improvements in its code.

Added features:
- score data processing in the background when being idle;
- smooth BGM timer ticks by running an SPC700’s timer at a variable period;
- echo FIR filter fadeout on entering the transfer mode (to load score data and samples);
- softer key/note releases by using S-DSP’s GAIN per-voice registers instead of KOF;
- faster data transfers from SNES;
- faster processing of messages from SNES;
- lower latency of sound effects;
- echo buffer initialisation using S-DSP itself.

Bug fixes:
- voice pitch value will no longer get out of bounds, especially when processing pitch bends;
- if a song does not initialise ADSR parameters, default ones will be used;
- fixed BGM voice echo on/off events interfering with an SFX playing at the same channel;
- fixed a noticeable stall when SNES sends a message to play a subsong;
- the echo buffer is set up correctly to avoid audible glitches;
- removed a minor race condition which would make a pitch modifier for SFX at channel #5 inconsistent from time to time;
- voice L/R volume is correctly scaled even by very high values of BGM volume;
- fixed a crash due to messages from SNES to play SFX at an invalid channel in Castle Crush;
- fixed the echo buffer overwriting a $FF00..$FF03 memory region used by the Nuts and Bolts sample set;
- reduced some audio clipping/distortion caused by too high L/R levels.

Removed unused features (possible leftovers from Rareware games before DKC2):
- processing messages $F8 and $F9 which have totally no effect;
- tremolo processing, as there is no way to enable it.