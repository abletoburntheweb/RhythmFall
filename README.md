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
- Start the local server ([RhythmFallServer](https://github.com/abletoburntheweb/RhythmFallServer)).
- Launch the Godot client and open the game.
- Generate notes: choose drums, mode (basic/enhanced), and lanes; pick a song.
- Play the newly generated level.

## Windows download (v1.1.10)

Download **`RhythmFall-1.1.10-setup.exe`** from [GitHub Releases](https://github.com/abletoburntheweb/RhythmFall/releases). A portable ZIP (folder with `RhythmFall.exe`) may also be provided.

**Install:** run setup.exe → choose a folder (default: Program Files or Local Programs) → Start menu shortcut, optional desktop icon.

**Uninstall after setup:** Settings → Apps → RhythmFall → **Uninstall** (or “Uninstall RhythmFall” in the Start menu). Windows runs the installer’s own uninstaller — it removes game files from the install folder and deletes shortcuts. It then asks whether to delete saves in `%APPDATA%\RhythmFall\` (default: keep them). `Uninstall-RhythmFall.bat` is not included in the setup; it is only for the portable ZIP.

**Saves and settings** live outside the install folder: `%APPDATA%\RhythmFall\` (progress, generated notes, shop purchases, etc.). Installing a newer setup.exe over an older install keeps your saves.

**Note generation still requires the local Python server** — the downloadable client is the game only.

## Notes
- Your music stays on your machine and is not part of the repository.
- Analysis and generation run locally; tracks are not uploaded anywhere.
- Output quality depends on mix and genre; the enhanced mode is more accurate but slower.
- Stems can improve drum detection but significantly increase processing time — disable for quick tests.
- Common audio formats are supported; niche codecs may have limitations.
- For pipeline details and advanced configuration, refer to the server repository.
