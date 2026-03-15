# RhythmFall

Turn your own music into playable rhythm‑game levels. Fully local automatic note generation — no manual charting required.

> **Download:** Pre-built Windows releases with 20 included tracks and sample charts available in [Releases](../../releases).  
> **Note:** This repository contains the Godot client. Server repository (audio analysis & note generation): https://github.com/abletoburntheweb/RhythmFallServer

Languages: English | [Русский](./README.ru.md)

## What It Is
RhythmFall is a Godot‑based rhythm game that analyzes any track you choose and generates a playable note chart beforehand. A local Python server powered by ML models (Essentia, madmom, Discogs400) handles audio analysis and returns ready‑to‑play charts to the client.

## How It Works
- The Godot client sends the audio file path and generation parameters to a local Python server.
- The server estimates BPM, detects drum events, applies genre‑aware patterns, and generates a chart.
- The client saves the result to `user://` — the level is ready to play.

## Key Features
- Automatic note generation from audio (no manual mapping)
- Drum‑focused patterns: `basic` (fast) and `enhanced` (denser, with genre‑aware fills)
- Genre‑aware density and groove: patterns adapt to the track's style
- Optional stems separation for more accurate drum detection
- Fully local workflow: all communication stays on `localhost`

## Quick Start
1. Start the local server (see the separate server repository for setup instructions).
2. Launch the Godot client and open the game scene.
3. In the generation menu, select: instrument `drums`, mode (`basic`/`enhanced`), lane count (3–5), and a track.
4. Wait for generation to complete and play your new level.

## Notes
- Pre-built releases (in [Releases](../../releases)) include 20 tracks and example charts as a `.zip` with `.exe`. The source repository itself does not bundle audio files.
- All analysis and generation run locally on your machine; no tracks are uploaded to external servers.
- Output quality depends on the mix and genre: `enhanced` mode produces more detailed patterns but requires more time and resources.
- Using stems (`use_stems`) improves drum detection accuracy but increases processing time — disable for quick tests.
- Supported formats: MP3, WAV, OGG. Uncommon codecs may not be handled correctly.
- For pipeline details and advanced configuration options, refer to the server repository documentation.
