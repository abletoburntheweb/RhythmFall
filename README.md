# RhythmFall

Turn your own music into playable rhythm‑game levels. The project focuses on fully local, automatic note generation from audio — no manual charting required.

Note: This repository contains the Godot client. For the server (audio analysis and note generation), use RhythmFallServer: https://github.com/abletoburntheweb/RhythmFallServer

Languages: English | [Русский](./README.ru.md)

## What It Is
RhythmFall is a Godot‑based rhythm game that analyzes any track you choose and builds a playable note chart on the fly. A lightweight local server handles audio analysis and returns notes to the game.

## How It Works
- The Godot client sends a selected song to a local Python server.
- The server estimates tempo and drum events, applies genre‑aware patterns, and generates a chart.
- The client saves the chart locally and you can play immediately.

## Key Features
- Automatic note generation from audio (no manual mapping)
- Drum‑focused patterns with basic and enhanced modes
- Genre‑aware density and groove
- Optional stems separation for improved detection
- Fully local workflow (talks to localhost)

## Quick Start
- Start the local server (see the separate server repository for setup).
- Launch the Godot client and open the game.
- Generate notes: choose drums, mode (basic/enhanced), and lanes; pick a song.
- Play the newly generated level.

## Notes
- Your music stays on your machine and is not part of the repository.
- Analysis and generation run locally; tracks are not uploaded anywhere.
- Output quality depends on mix and genre; the enhanced mode is more accurate but slower.
- Stems can improve drum detection but significantly increase processing time — disable for quick tests.
- Common audio formats are supported; niche codecs may have limitations.
- For pipeline details and advanced configuration, refer to the server repository.
