# Mods of SPC700 sound engines for Super Nintendo
Here is a collection of modded, improved, or fully rewritten sound engines used in their corresponding SNES games.

## Donkey Kong Country SPC engine (RareSPC_alt.asm)
Based on the disassembly of the original design, the audio engine used in Rare’s Donkey Kong Country was almost fully rewritten to add new features, fix bugs, remove dead code, and increase overall performance.
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
- fixed BGM voice echo on/off events interfering with an SFX playing at the same channel.

Removed unused features:
- downmixing stereo to mono, as the game does not even have an option to toggle the stereo/mono mode;
- fading out all sounds, including echo;
- audio score/sequence conditional jump;
- voice volume and ADSR presets.

## Donkey Kong Country 2/3 SPC engine (RareSPC2_base.asm, RareSPC_dkq.asm, RareSPC_dkdt.asm)
Like a previous one, this engine also underwent a high number of improvements in its code.
