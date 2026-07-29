# RhythmFall Wrapped — HTML/CSS card renderer

Cards are rendered at **1080×1920** via Playwright (headless Edge/Chrome) and saved as PNG from the in-game share modal.

## One-time setup (dev / play project)

From the server venv or any Python 3.10+:

```powershell
pip install -r scenes/profile/share/html/requirements.txt
playwright install msedge
```

On Windows, Playwright uses **Microsoft Edge** (`channel=msedge`) — no extra Chromium download if Edge is installed.

Python is resolved in this order:

1. `RhythmFallServer-main/.venv/Scripts/python.exe`
2. `worker/windows_python.path` (optional custom path)
3. `python` on PATH

## Flow

```
ProfileShareSnapshot → JSON payload → render_card.py → PNG
```

Godot never opens a browser window; export runs headless via `OS.execute`.

## Files

- `card_shell.html` — page shell
- `cards.css` — Wrapped visual style (glass, neon, grids)
- `cards.js` — builds card DOM from `window.__CARD__`
- `render_card.py` — Playwright screenshot CLI

If HTML render fails, export falls back to the legacy Godot SubViewport cards.
