# Sonniss GDC 2026 audio provenance

Source supplied by the user: `C:/Users/invot/Downloads/Sonniss.com-GDC2026-GameAudioBundle`.
Original downloads remain untouched. Twenty-four approved Sonniss-derived game assets are installed.
The manifest also records two approved edits from existing game recordings (critical hit and a boss dread
variation), identified by `source_root: project`; the Sonniss licence does not cover those existing recordings.
The first, longer healing candidate, musical magic-creation candidate, fire whoosh and ice-cracking
attack candidate were rejected and are not included. The 1.85-second critical-hit candidate was also rejected;
its 0.4-second revision was rejected too. A different 0.22-second edit of the original crate-breaking hatch
sound was approved for critical hits. Hatching now uses the approved bird-flute chirp. The proposed one-second
noise-box boss stinger was rejected and is not installed.

Creators, pack names and uses are recorded in `CREDITS.md`. Exact source filenames, SHA-256 hashes and
conversion gain are in `tools/sfx_sources.json`. The converted files live in `assets/audio/sfx/`.

Licence reference: https://sonniss.com/gdc-bundle-license/ (checked 2026-11-08).
The published licence permits modification and incorporation in personal and commercial games without
required attribution. Sound recordings retain their owners' copyright and cannot be supplied as a sound
library. The applicable version is the one published on the original download date; the pack contains no
licence file and that date is not recorded. Earlier versions are available at
https://sonniss.com/gdc-bundle-license/previous-versions/.

Conversion: 44.1 kHz stereo Ogg Vorbis, quality 5, embedded artwork/metadata omitted.
Excerpts, fades and gains match the approved previews and are recorded in the manifest.
Five ambient recordings use the exact approved 12-second loops, with a one-second crossfade at the join.
The gains match the approved previews. All cues use the existing SFX bus: page/open/pickup at -10 dB,
merging/misses/confirmations at -10 dB, physical hits at -8 dB, unavailable actions at -12 dB,
healing and the mechanism at -13 dB, and payments at -14 dB.
Critical hits use -6 dB, hatching/toggles -10 dB, and dialogue/failed attempts -12 dB on the SFX bus.
The merge cinematic's swell, vanish and reveal cues play at -10 dB through that scene's own players on the SFX bus.
Dialogue adds the separately approved three-semitone pitch lift at playback, retaining speaker variation.
Ambient loops use the SFX bus at -18 dB (surf and machines) or -20 dB (forest), with fades between areas.
Both boss variations use -8 dB. Moor and cathedral ambience use -20 dB, with separate loops for each setting.
