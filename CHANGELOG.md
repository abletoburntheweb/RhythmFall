## RhythmFall Client v1.3.0

Patch release focused on Practice and replays, interactive onboarding, Chart Editor, Profile History and playlists, play mode polish, and performance improvements.

### New

**Interactive onboarding — First Steps**

- On first launch the Daily Tasks block on the main menu is replaced by a **First Steps** panel: up to 3 step cards with icons, title, short hint and progress, a **CONTINUE** action and a **Skip** link
- 5 steps, tracked by real player progress: **Library** (add a user song), **BPM** (compute the tempo), **Chart** (generate the first chart), **Run** (complete a level), **Result** (open all three reward details on Victory: currency · XP · accuracy)
- Existing players are credited automatically — already-done steps are re-derived from the library, metadata and stats, so the panel only shows what is still missing; veterans complete it instantly and get the achievement
- Continue opens the right screen for the current step: Settings → Library for the first step, Song Select for the rest; progress is re-checked whenever the main menu is shown
- **Skip** asks for confirmation and shows a hint toast that the tutorial can be replayed from Help
- **Take the tutorial again** button on the Help article «Getting started on first launch» resets the progress and returns to the main menu
- New system achievement **First Steps**, unlocked on completion, fully localized
- After the tutorial is completed, Victory shows a **«First Steps complete!»** card with a single **OK** button — the copy points to Practice in the pause menu; the card does not extend the tutorial
- On the first run the guide shows a **Welcome card** with **START** / **SKIP**, and for each of the 5 steps a numbered **intro card** ("Step N of 5"), a **spotlight** that highlights the exact UI element to interact with (settings scan button → song select BPM → note generation → Victory details), and a **success card**
- The guide highlights the exact UI element for each step and can be hosted on any screen; the Result step completes once all three reward details are opened, with the spotlight targeting only the still-unopened detail rows
- Independent tutorials (calibration, rhythm DNA, generation settings, gameplay, victory, song select tips) are suppressed while the guide is active
- Practice is a standalone feature, not a tutorial step — it has its own one-shot spotlight from Pause; the post-tutorial card on Victory just points to it
- Fully localized (EN/RU)

**Practice mode**

- **Practice** in Pause — loop a selected section range of the currently running chart right on the track progress bar; the panel opens fully ready on the first click
- Range selection on the section strip: **LMB = start**, **RMB = end**; order auto-normalized; choice persists across panel close/reopen (reset only when a new pause opens)
- Orange range fill with start/end markers drawn on the existing track progress bar (single bar + overlay, no second timeline)
- The range loops until the player leaves: score / combo / accuracy / misses / error meter reset every cycle; **Attempts** counts completed cycles only (exiting mid-cycle adds nothing)
- In-game **Practice HUD** — session-wide Accuracy / Max Combo / Misses / Attempts + persistent **Best Practice** per chart
- Semantic sections for Practice — Verse/Chorus/Bridge/Intro/Outro/Instrumental/Solo with short labels (I/V1/PR/C...) and consistent numbering.
- Works for charts without sections, including charts without Rhythm DNA sections
- Clean start: Practice applies the same pre-roll as a normal run — the first notes of the range approach from off-screen and the music starts exactly at the section (Intro included), instead of notes popping in mid-playfield
- **Section preview** — middle-click (**MMB**) a section marker on the footer progress bar to hear that section without starting a run or touching the selected range; plays from the section start and fades out
- Practice preview length via Settings → Sound → **Practice preview** — **15 seconds** (default) or **Until end of range** (falls back to the clicked section's end when no range is selected)
- Fully localized (EN/RU)

**Replay — Run replays and Replay Player**

- **Settings → Data:** replay save folder + auto-save toggle (default `user://replays/`)
- Auto-save after victory; **Save replay** on victory when auto-save is off
- Victory **Save replay** reflects the real save state: **Replay saved** once the `.rfr` exists (auto-save or a successful manual save), otherwise **Save run replay**; it flips in place right after a successful manual save, and a failed save is never shown as saved
- **Watch Replay from Victory and Results — exact run only:** Victory offers Watch Replay for the run that just finished, and Results offers Watch Replay for the exact result that is open; each opens the replay tied to that specific run
- No fallback to another replay — if the replay file is missing or has been deleted, no other replay is substituted and the option correctly appears as unavailable
- **Open replay** on song select — pick a `.rfr` file (dialog opens in the replay folder from Settings → Data)
- Watch badge: **Replay · Artist — Title · instrument · mode**; lane highlights on playback
- **Transport bar** in Replay Watch mode: Play/Pause, previous/next **section**, a **timeline** with seek by click or drag (live time preview while dragging), section markers drawn on the timeline, current/total time label
- Seek keeps score, combo, accuracy, misses and HP correctly recalculated at the new position.
- **Playback speed** 0.5x / 0.75x / 1x / 1.25x / 1.5x / 2x — applies to audio pitch and note scroll at the same ratio, keeping audio and timeline in sync; a **speed picker window** opens over the player (also from Replay view settings), closes on choice, and the bar button always reads a consistent **1.00x / 1.25x / 2.00x** format
- **Volume slider + Mute** — per-watch volume override; the original global volume is restored when the replay ends
- **Hotkeys** (replay only, gameplay running): `Space` play/pause, `←`/`→` seek ±5 s, `Shift+←`/`Shift+→` jump to previous/next section, `↑`/`↓` volume, `M` mute, **`Esc` opens the pause menu** over the player (second Esc resumes), `F` hides/shows the player
- **Auto-hide player (3 s)** — toggleable in Replay view settings; the bar slides down with a pop animation and the **cursor hides along with it**, reappearing on any input
- Replay view settings: hide interface elements and adjust hit sounds volume, plus auto-hide toggle.
- Space skips countdown, intro, and outro in watch mode; FPS restores after exit
- Viewer needs the same audio in the library plus the generated chart (audio is not embedded)
- Explorer icons for `.rfr` (`rfr.ico` / `rfr.png`)
- Fully localized (EN/RU)

**Victory screen**

- Reward detail modals (currency / XP / accuracy) re-rasterize their icons at high resolution and tint them to the modal accent — gold currency, teal XP and accuracy
- Accuracy detail modal now uses the teal accuracy accent for its title, footer, and border (matches the accuracy stat on Victory), instead of the currency gold
- New **Accuracy · Beta** detail modal on Victory: click the accuracy tile to open a per-section breakdown of your accuracy (each Rhythm DNA section, with the section letter/color and time range, plus the session accuracy in the footer); opens via the same reward-detail modal pattern, closes with ESC/Back, fully localized
- New **RR Breakdown** modal on Victory: click the RR label to see how the run rating was counted — accuracy ×8, chart rating ×92, grade bonus (SS +115 / S +62 / A +24 / B +8), full combo ×150, modifier multiplier (incl. parametric mod scaling), the best RR for this chart config (with NEW RECORD / REPEAT captions) and a collapsible «How RR is counted» panel with the formula and the ideal-run potential; same modal pattern, icons, ESC/Back, localized
- RR Breakdown polish: the Current/Best comparison is a 4-column **table with icons** (accuracy, chart rating tinted by its difficulty tier, grade, full combo, mods) with larger type; the formula panel is split into clear **steps** (base → mods → difficulty scale → «= N RR» result); first Esc closes the formula panel, second Esc closes the breakdown
- New **RR What-if** modal in the RR Breakdown on Victory (button "WHAT IF?"): interactively model the run rating — **two-column layout** (left: Accuracy slider, grade, Full Combo toggle, modifier multiplier slider; right: Current → Simulated RR comparison with delta); every change recomputes through the single real RR formula; chart difficulty stays fixed, no run data is modified
- Currency / XP reward icons now **respond to hover** (tooltip + chevron tint) like the RR row, and reward chevrons re-align on window resize / after the grade reveal
- RR Breakdown **formula modal** redesigned: compact 4-column table (Factor · Value · Contribution · Intermediate) with per-row icons; accuracy shows `%.1f%%`, difficulty multiplier shows the real ×92 weight, running total accumulates correctly, final calculation shows `(base × multiplier) × 0.92 = RR`
- RR Breakdown buttons (**"HOW RR IS COUNTED"**, **"WHAT IF?"**, **"CLOSE"**) share a unified outlined style with back icon on the close button
- **Close button restyled across all victory modals** (accuracy, currency, XP, RR Breakdown, formula, What-If): outlined border with accent tint, font tints to accent on hover, unified 52px height
- **Hover animations removed** from modal buttons for a calmer UI

**Activity calendar and time capsules**

- Day / Week / Month; Today; Monthly Recap and day facts
- Year-ago plaque; library size milestone toasts
- UI time = time spent on tracks
- Hotkeys: Q/E month, 1–3 views, W today; larger footer
- Day facts without anglicisms (“no fails” / Clear / Fail); impersonal memory copy
- Profile **Calendar** button next to Export; streak tile caption points to the calendar; clicking the **calendar card** on Overview opens the full calendar modal
- Closed months saved as time capsules; leftover demo capsules are cleaned up on profile load
- Month view: **How I've changed** compares that month’s capsule with today (level, RR, genre, …)

**Profile History**

- Fullscreen **History**: Feed / Records / Capsules
- Event feed: filters, covers, milestones, streaks; real unlock dates
- Discovery firsts in the feed (not the milestone shelf): first clear per instrument, chart style, modifier and genre group.
- Records: RR top, extremes (zap + rating), marathon/endless, streaks
- Modifier **records** — five run peaks (score / RR / hardest stack / max mods / accuracy)
- Modifier **clears** — clear-count grid only: top 5 + expand up to 5 more
- Genres: collection group icons; one expand control for the whole block
- Capsules: zap + grade letter like difficulty extreme; month compare — each slot opens a picker with the available capsules (+ **Now** for the right slot)
- Ties on accuracy / score / RR: more mods first, then higher score (or RR); rebuilt from history
- Shared profile loading overlay; footer hints

**Diary / living library**

- Living-library lines vary each visit; optional History → Calendar day deep-link (Settings → Library).

**Modifier Discovery · UI redesign**

- Three recommendation cards with per-category color accents: **Fit** (green), **Next** (blue), **Combo** (purple), **Challenge** (orange) — each card shows a category icon + label, modifier names via localization, colored difficulty widget, reason text, and category-specific tags (accuracy, stability, progress, difficulty, combo, hidden)
- New **Tried Recommendations** section — up to 3 cards for previously attempted mods, each showing the modifier icon, localized name, attempt count, average accuracy, and best rating (zap + colored number)
- Help `?` button on the header opens the "Modifier Recommendations" article in Help explaining categories, tags, tried recommendations, and how to use them; button now correctly appears when switching to the Discovery tab
- Difficulty-only recommendations use colored `zap.svg` + rating (not star count); modifier recommendations reuse existing card layout

**What's new, About & file access**

- What's new modal in Settings → System with v1.2.0 highlights.
- Settings → System: **About** — modal (project / third-party credits / Special Thanks) and GitHub / Releases / Server links
- **Open data folder** (Data); **Open** next to songs/notes paths (Library)


**Chart Editor**

- **Gameplay viewport:** Editor now uses the shared gameplay geometry with a fixed viewport instead of a huge vertical canvas; same lane width/boundaries/HitZone/note size/colors/clipping as in-game
- **Timeline/overview:** top ruler is now a full-song overview (measures/beats + note density + selected highlight + playhead); click/drag on ruler seeks, preserving pause/playing
- **Zoom — travel scale only:** fixed viewport with travel scale (50% closer, 100% GameScreen-like, 150% farther), anchored at HitZone; zoom changes only the note travel speed, not BPM, playback, chart or timeline, and never teleports the view
- **Ghost drag:** on drag start original note dimmed, ghost follows cursor/lane, snapped if Snap ON, raw if OFF, disappears on release
- **Click selection:** `LMB` note → select, `Shift+LMB` → toggle, drag → move, `Shift` box, `RMB` empty → add (current instrument + Snap), `RMB` note → delete; no dropdown/play on click
- **Audio feedback:** add plays the user hit sound, delete plays deselect sound, playback crossing HitZone plays hit sound (isolated, no scoring/combo/XP/currency/achievements)
- **Dropdown+Space:** `Space` stays `Play/Pause` after dropdown use; editor focus is restored after snap/drum/quantize changes
- **Dropdown must not play audio:** drum/snap/quantize changes update state/UI only
- **Real quantization:** Quantize now uses the button division (4/8/16/32 → beat/1, /2, /4, /8); Snap vs Quantize are separate states
- **Isolate progression:** undo etc. consume input, no XP/currency/completion/achievements/score/combo/health/mission; editor shortcuts fully owned
- **Play/Pause/Seek model:** seek preserves the previous playing state; timeline scrub respects it
- **Inspector passive:** drum/quantize/delete/copy/paste change chart only, no playback
- Full LMB/Shift/Ctrl/box/RMB selection flow and global shortcuts (Space/Ctrl+Z/Y/Delete/Esc) from any focus.
- **Inspector overhaul:** `Map Info` now always visible at the top (tempo, total length, total notes and lane count); dedicated `Editor Status` shows `Saved`/`Unsaved` and exact `Changes: N` from the undo history; `Timeline` follows the playhead in `MM:SS.mmm`; `Chart Actions` add `Revert` and `Select All` in the Inspector; `Settings` are pinned to the bottom edge of the panel while the upper content scrolls
- **MIDI Patterns browser:** File browser inside `NOTES | MIDI PATTERNS` rooted at your MIDI samples folder — shows folders and `.mid` files, expand/collapse, drag `.mid` directly onto the Playfield to preview and drop
- Left MIDI Browser is resizable by dragging the vertical divider.
- **Test Play for charts:** Right-click **Play** on the Song Select screen to test any `.rf` chart file via the native Windows file picker in the current song's chart folder; preview uses real gameplay and does not save results, records, history, achievements, or replays; enable in **Settings → Experimental → Chart Editor** (off by default)
- **Keybindings (Settings → Controls):** compact `[Action] [Ctrl+Z] [Ctrl+Shift+Z]` without `+`/trash icons
  - `RMB` on a binding opens a menu with **Add binding / Remove binding** (removes that exact binding, last binding deletion disabled)
  - Context menu uses enlarged readable text like dropdowns
  - **Add binding** instantly creates a temporary `...` button vertically under existing ones and enters capture; `Esc` cancels creation and removes `...` without saving
  - Additional bindings stack vertically inside the action, no horizontal overflow, two-column layout preserved
  - Top info block inside `CardPanel` now: **Key Snap / Clicking a key changes its binding. / RMB on a key opens additional actions.**
  - Unified pink/purple palette for categories
- Back button plays deselect sound
- `Esc` in modal no longer blocks `Settings` exit
- `Settings → Experimental → Show generation report button` now correctly hides the library `About generation` button even when a chart exists; `About generation` / `Rhythm DNA` passport beta label removed — out of beta
- **Generated stays unchanged** — the editor works on a copy; first **Save** of an edited Generated chart creates **Corrected v1** as `*_v1.rf` + `*_v1.rfc`; ordinary **Save** updates the current version in place; **Save As Next Version** creates the next version and switches the editor to it
- **Versions keep parent/source provenance** — each `*.rfc` stores the link to the original Generated chart and to its parent, so `Generated → v1 → v2 → …` is traceable and previous versions are preserved
- Correction data in *.rfc stores semantic diff and provenance; .rfc is not required to run the .rf.
- Autosave snapshots with recovery on next open.
- **Recovery prompt, not silent restore** — on next open the editor offers **Restore / Delete / Open saved version**; warns on source hash mismatch, allows standalone restore when the source was deleted, ignores corrupted temps
- **Windows integration** — `*.rfc` registered as **RhythmFall chart correction** with the `rfc` icon; installer and icon builder updated
- **Save / Save As / Revert / Quantize feedback:** these core actions now show notifications, and saving/versioning correctly preserves and restores the open chart

**SongFormer — structure analysis (server, optional, CPU)**

- Optional SongFormer structure analysis refines musical form: intro/verse/chorus/bridge/outro/inst.
- **Local, CPU-only, isolated** — separate venv for SongFormer (`torch` CPU, `transformers`, `muq` etc) — main venv untouched; `CUDA_VISIBLE_DEVICES=""`; `auto→CPU`, `cpu→CPU`
- **Settings → Generation → Structure (SongFormer)** — `OFF` (default, old pipeline) / `ON + Auto` → CPU / `ON + CPU` → CPU
- **Progress:** part of existing `Splitting stems` stage — `Analyzing structure (SongFormer, CPU)...` (indeterminate, no fake %)
- Falls back to the existing structure if SongFormer analysis fails; generation continues.
- **About / Help:** SongFormer now only in `### Audio analysis` as compact list `kuielab (MDX) via audio-separator (MIT)` / `SongFormer (CC BY 4.0)` / `Discogs-EffNet` / `TempoCNN` / `Basic Pitch`

### UI / UX Fixes

**Achievements — Newest sorting**

- Added Newest sorting for achievements in the full list
- Recently unlocked achievements appear at the top, achievements without an unlock date appear at the bottom
- Sorting is available through a single Sort dropdown
- The dropdown appears only in the full list and is not shown in categories or search
- Achievements overview no longer spams errors on “Show all”
- Achievement catalog trimmed; grind duplicates retired from progress

**Profile Records — covers**

- Fixed track cover display in personal record cards
- Bundled tracks now correctly show their embedded artwork when available instead of falling back to placeholders; tracks without embedded artwork still use the placeholder
- Layout and card geometry unchanged

**Victory & song-select polish**

- Victory **Close / Back** buttons (Accuracy, XP, Currency detail panels) no longer shift/jump on hover — the icon is pinned and the button keeps a stable stylebox across hover / pressed / focus states (mirrors the already-fixed RR Details, RR Formula and What-If panels)
- **RR Formula** tab now shows the modifier row as a **count** (`Modifiers  2`) instead of a long comma-separated list that stretched the table
- **Active Modifiers** list on `Modifiers → Overview` now spans the full panel width (rows expand to fill)
- **Modifier Preview** video no longer clips past the card’s rounded corners — the preview is soft-masked with the same rounded-clip as the preview image
- **Achievement Pop-up** now renders as a proper card: rounded panel shell with border, gold achievement title, and the icon wrapped in the shared framed cover (matches `achievement_card`)
- **What-If (RR) panel** open no longer feels frozen — a loading spinner shows during the modal build, then hides once content is ready
- **RR Breakdown clarity** — a one-line takeaway explains that **chart difficulty is the biggest RR factor** and the multiplier scales RR
- **Modifier multiplier** is now labeled **“Reward & RR multiplier”** wherever shown — it scales **both** rewards and RR (previously implied rewards only)
- **Base vs effective rating** — when modifiers are active, RR Breakdown notes RR uses the chart’s own rating and modifiers affect RR through the multiplier (the song-select effective rating is not the RR input)
- **Victory Grade** shows a **“Based on accuracy”** tooltip; **Victory RR** shows a descriptor tooltip and the existing clickable row opens RR Breakdown

**Marathon Run Rules UI**

- Run Rules are shown correctly in the route details, including when Russian is selected
- The Good-limit rule uses the existing `circle-dot` icon in the same card style as other Rules

**Marathon difficulty display**

- Route difficulty is now shown with the existing ZAP difficulty pattern — number of ZAPs and tier colours follow the same scale as chart difficulty (9–10 red, 7–8 yellow, 5–6 purple, etc.)
- The underlying difficulty calculation itself has not changed

**Endless difficulty display**

- Endless difficulty indicators now use lightning-bolt icons instead of star icons, matching the difficulty presentation used elsewhere in RhythmFall

**Library**

- Song Card play count now displays correctly
- Removed redundant Help button from the Library top bar

### Fixes & Improvements

**Play Streak / Login Streak**

- Separated Play Streak and Login Streak
- Play Streak is now correctly calculated from days with real play activity (tracks > 0)
- Login Streak is tracked independently and is no longer overwritten by calendar data
- Both streaks and their best values are correctly persisted between launches
- Added compatibility for saves made before the separation

**Pause navigation & settings**

- Pause → Settings and Pause → Song Select show the same loading spinner and lifecycle as the main-menu equivalents
- Pause stats captions (Score / Accuracy / Combo / Multiplier) are now localized
- **Esc** while Settings is open from pause now closes Settings first; a second **Esc** resumes the run (the Settings overlay blocks the game screen’s pause toggle)

**Navigation — Back / Esc**

- Profile → Records / History → Calendar now closes correctly via Back / Esc and returns to the existing Records / History view without rebuilding it
- Back / Esc behavior on other screens is preserved

**Rhythm Rating & replay**

- Legacy mode/instrument names no longer split the same chart into different RR buckets
- **Play again** relaunches the same chart style without a bogus “new chart” RR
- Victory shows “RR +N (new chart)” only on the first credit for that bucket

**Music structure analysis (server + client)**

- Server-side music structure analysis (A2d) now has a **phrase-aware refinement — method `a2e`** used by Rhythm DNA: it only *adds* internal boundaries inside sections longer than **16 bars**, splitting each at the most musical point (highest novelty / boundary strength on the bar grid)
- **Strict refinement invariant:** `a2e` never removes or shifts an existing A2d boundary — it only inserts new ones, so all previously-correct segments are kept; the legacy `a2d` method is unchanged and still available
- Post-deployment validation on **20 real tracks**: **39 added phrase boundaries**, **0 questionable / 0 false**; 11 tracks already segmented well are byte-for-byte identical between `a2d` and `a2e`
- Result: **all >16-bar and >32-bar sections eliminated** (A2d had 26 >16-bar and 2 >32-bar; A2e has 0), bar alignment improved, A/B/C… timeline follows real phrasing
- Beat-grid caveat: A2e inherits the phase of the supplied beat grid. Current production uses librosa fallback (phase-aligned, safe). If a BPM-derived grid starting at t=0 is used, splits may shift — recommend phase-aligning the grid before phrase-pass.
- Backward compatible: `.rfd` schema (`id` / `start_s` / `end_s`) and the client timeline are untouched; `rhythm_dna` now requests `a2e`
- Rhythm DNA information display improved — Structure vs Pipeline details now show correctly

**Help**

- Added in-article search highlighting, Help navigation history, and contextual Help links throughout relevant sections and modes
- Restored Help content to version 37 with expanded modifier guides and compatibility information
- Reworked the “Incompatible modifiers” guide from a large static table into an expandable list — each modifier now shows its circular icon and localized name, with incompatible modifiers revealed on expand and created only when needed
- The compatibility view now reuses the existing modifier icons for a consistent look and remains fully localized
- **Getting started:** linear flow Song → BPM → Notes → Play, RhythmFallServer.exe in Help and Settings → Generation
- **Generation Scope:** localized, scheme without emojis Scope → Preset → Generate Notes → Available Charts → Chart Style → Run, rows instruments/goals/difficulties from Settings → Generation
- **Modifier recommendations:** 3 demo cards Fit → Next → Combo → Challenge + Tried section, ? → Help
- **Endless / Marathon / Library:** showcases with zap.svg for difficulty (no stars), chart_files for .rf/.rfd/.rfr, rack_medals for medals
- **Track medals:** rack_medals showcase from Library (8 cells, zap + number)
- **Hotkeys:** verified with Controls — Library ↑↓/Enter, Game A S D F, Help 1–7/↑↓/[/], Settings 1–9/Space
- **Help structure:** 11 sections in two groups — Guide (Getting Started, Chart Creation, Gameplay, Modifiers, Training, Progress & Shop, Play Modes) and Reference (Files & Charts, Controls & Audio, Metrics, How the Game Works) — same Sidebar + Article layout with group separators, no second level
- **.rfr/.rf/.rfc / Chart Editor:** new questions What is a replay (.rfr)?, What is a chart (.rf)?, Chart Editor, What is .rfc?, How do .rf and .rfc interact?
- **Rhythm DNA:** expanded intro/verse/chorus/bridge/outro/inst/solo + sections.rfd sidecar with rating/health showcases
- **Technical pipeline:** added Section Detection (A/B/C) between Grid and Genre
- **Windows Server:** RhythmFallServer.exe + Generation Scope/Presets difference, Auto/Manual/LAN + GPU option
- **Visuals:** help_showcase 18 kinds via MarkdownLabel
- Help links open the right Settings page
- Help **Rhythm Rating** rewritten — explains per-run RR first (chart difficulty dominant; accuracy, grade, full combo and the multiplier contribute; the multiplier boosts RR *and* rewards), then Profile RR (best per config), and points to the Formula screen

**Server & generation (client)**

- Generation queue progress updates for jobs after the first
- **BPM Cancel now truly cancels** — cancelled job never emits `bpm_completed` / never applies BPM; offline banner `Cancel` now correctly clears the active task, so new BPM can be started immediately after Cancel; `BPM Cancelled` notification shown for 3s
- Offline banner Cancel abandons the wait
- Chart readiness hides Arcade difficulties when only Original is selected
- Readiness gear opens a compact modal, not full Settings
- Boot: no extra Godot splash / loading overlay before the menu
- Stems: unused models trimmed; default drums/bass via **kuielab** (Demucs fallback). Ear QA still pending

**Modifier presets & generation UI**

- “Generation presets” dialog title centered
- Sharper modifier icons in preset slots (20–22 px strip, more frame padding)
- Multi-select presets

**Mods & UI**

- **Single Lane modifier layout:** Fixed the playfield layout when playing with the Single Lane modifier set to one lane. The playfield no longer shrinks and the top progress bar, score display, and health bar no longer crowd or overlap the field. The single lane now appears as a centered wide lane at the normal playfield width.
- **Metronome Only — play stems if available:** Added an option to play the drums stem when it is available. When enabled and a stem is found for the current song, the run plays the stem instead of the metronome. If no stem is found, the game falls back to the metronome. Reuses the same stem detection as the Chart Editor and keeps the stem in sync with the current song position.
- **Silence — source during silence:** Silence gaps can now play the drums stem, the metronome, or remain silent. You can choose the source in the modifier's parameters. If Stems is selected but no drums stem is available, the game falls back to the metronome. Stems play from the current song position, not from the start.
- Safer caps for Half HP / Strict / Easy / Heat / Hidden·Sudden
- Heat/Rush pitch lock only when song-speed change is on
- Pause rewind (3 s) smoothly moves notes again (no teleport / softlock)
- Re-clicking the active Original/Arcade goal no longer clears the selection

**Run Modifiers**

- Added concise parameter descriptions for configurable Run Modifiers in Overview and Presets.
- Fixed rounded video preview frames so the video no longer covers the frame corners/glow.

**Modifier screen & RR**

- Modifier toggles (Combo Escalation pool, per-modifier parameter switches) keep their focus outline on hover
- Active Modifiers list in the run summary now matches the Modifier Presets window: rows reach the scrollbar and show the modifier name + description with live parameters; long text is clipped with an ellipsis like in presets
- **RhythmDNA category hint:** The RhythmDNA category now uses the standard hint with the available actions and controls, like the other categories. This follows the removal of the beta label in this version.

**Profile Recap**

- Five cards: Overview / Records / Statistics / Music / Play Modes; taglines, feed story, hall of fame, KPI deltas, NEW/growing + discoveries
- KPI chips style A (top stripe); deltas in chips; zap + rating color for difficulty
- Records card: 4 milestone slots by prestige; no duplicate hardest-mod hall row; RR 02–03 dropped; 3 mod peaks on the share card
- Preview: one Playwright batch for all five; full CSS size then downscale
- Playwright in the generation-server venv (build install); player repair: **Settings → Data → PNG export (Recap)**
- Export modal only hints to open Settings (no install button there)

**Profile shell**

- Subtitle: “Progress, collection, and history”
- Footer “Q–E charts” only on the Statistics tab

**Free Play**

- Last-track cover stretches to the full block above “Your progress”

**Main menu hub**

- Last Track: square cover via `UiFramedCover` (rounded + border on top)
- Achievement cards / Nearest / profile Recent: same icon frame
- Daily quests: icons no longer clipped; slightly roomier card/panel padding
- Zap + grade/difficulty colors match the library; larger grade letter
- Activity now highlights your latest meaningful progress — a major milestone, a new genre mastery level, or hitting an RR or library size threshold — instead of repeating the last personal record

**Audio**

- After a long minimize, menu / victory / defeat music no longer stalls restarting from the start: resume without full reload; OGG/MP3 native loop
- Focus restore actually calls MusicManager (mute gate ran after `_focused = true` and skipped resume)
- Game tracks no longer loop at the end — the run transitions to Victory/results instead of the song restarting; menu and ambient music keep looping

**Settings shell**

- Back button full sidebar width again
- In-page action buttons tint to the page accent (teal on Sound, etc.); danger stays red
- Icons on key primary actions (calibration, library folders)
- Shade variations within the page accent (not one flat color); segmented pickers (FPS / quality) stay untinted
- Button/checkbox clicks use `modifier_select` / `modifier_deselect`; checkboxes follow section accent (amber on Library, …)
- Data: async Playwright probe (“checking…”) without UI freeze; clearer PNG-export status copy
- Profile open keeps LoadingOverlay spinner through first paint (no blank lag after switch)
- History: “To song” inline with the title row; pointing-hand cursor; TextureButton cursors too

**Playlists**

- Hub cards with cover mosaic, tags, and run stats
- Faster editor (search / expand charts without freezes)
- Original + Arcade together; no bogus Original difficulties; bass in the filter
- Empty-editor and double-SFX fixes

**Performance**

- Improved game startup performance by reducing redundant work during launch
- Improved Shop responsiveness when loading and displaying content
- Improved Achievements screen performance by reducing redundant per-achievement processing
- Improved Help responsiveness when viewing modifier compatibility
- Improved Profile performance by reducing repeated profile data loading, reusing cached media, and limiting refresh work to visible tabs
- Improved Profile Tabs performance by avoiding unnecessary work on hidden tabs and reducing repeated data processing
- Improved Profile Export (Share) performance by caching rendered cards, removing unnecessary renderer delays, and reusing cached previews on subsequent opens
- Improved Library / Song Select performance by reducing repeated loading work, improving song list population, and speeding up cover and note-readiness checks
- Improved Run Modifiers performance by caching translation data, removing duplicate locale work, and reusing modifier card visuals more efficiently
- Optimized Playlist Hub song-list loading to reduce repeated filesystem work when checking available charts
- Optimized Playlist Hub song-list loading to reduce repeated filesystem work when checking available charts

**Hit effects**

- Hit effects now have clearer, more distinct shapes and are easier to recognize during gameplay; the different variants are easier to tell apart, with ring-style effects gaining an additional ring visual. Existing physics, colors, and overall behavior are preserved.

**Endless & Marathon**

- Playlist start no longer fails with an empty pool
- Series setup hints + stable mods block; preview audio stays put
- Marathon auto-widens chart style when the pool is too small; both styles pick the best chart per track
- Missing interaction sounds in Endless setup now play correctly, including when changing how modifier conflicts are handled
- Endless setup and the track picker now open without the previous multi-second stalls — scope counting and track-source selection are substantially faster while preserving the existing behavior
- Marathon opens and refreshes routes noticeably faster — route availability is resolved without repeated heavy scans; preview and selection stay responsive
- Marathon catalog: route-set cards now wrap their title and subtitle (autowrap), preventing long route names from stretching the left panel and pushing the center off-center
- Marathon: added missing Russian translation for the modifier-details placeholder
- Mode-select cards: the top hero watermark animation was nearly invisible — boosted the line / dot / ring opacity and width on all three cards (Library, Endless, Marathon) so the animation is clearly visible again, matching the Marathon route-line + dots look
- Fixed how songs are matched to Genre Groups — secondary genres no longer cause a song to be counted for the wrong group
- Fixed fallback between Genre Groups — the route title now matches the actually selected/fallback group

**Drum charts (quality)**

- Denser, fairer intros with fewer early gaps
- Original stays closer to the audio; Arcade stays playable without stripping kick/snare skeleton
- More varied 4K lane layouts; fewer blast streams glued into one chain

**Settings & data**

- Save cleanup: drop unused `mod_records.per_mod` writes/backfill; Recap PNG cache prunes stale hashes after preview; demo month capsule off for release

**Library, shop, copy**

- History → track via cover click: details panel shows art again (no `update_details` race)
- Shop: category order (currency → achievements → level → daily → medals), unlock-ready items first within a category
- Achievements / help: shorter ACH 175–180 mod-category lines; “Metadata order”; fewer anglicisms (shadow notes, Hard, hold / multi-lane / Shuffle); bass help copy
- Arcade difficulty IDs `easy` / `medium` / `hard` (was relaxed/standard/dense); old stem aliases still read; one-shot file migrator removed after the cutover
- Intro: early skip no longer leaves looping intro BGM over the main menu
- Stale cover packs removed from the shop / old save data

**Localization and status messages**

- Mass fix for missing translation keys
- Fixed several cases of unsafe string formatting with translation keys
- ETA and status messages improved for clarity

**Other**

- Modifier presets: up to 10 slot icons; active list shows parameters
- Song select: Bass readiness follows bass charts, not drums
- Shared Back button on modals; denser help dim
- Windows worker install uses a single `requirements.txt`
- Hotkeys: profile **4–6** (Calendar / History / Export); achievements **Q–E** filters · **1–2** view · **/** search; help **/** · **[ ]** topics; playlists **N** / ↑↓ / Enter and editor **/** · **F** · Enter; shop **←→** (hold to repeat) · **Space** preview · Enter; mods **←→** cards · Enter toggle; victory **C/X** reward details. Item focus only after keyboard use (clears on mouse). Song Select letter hotkeys removed.
- Menu BGM: leaving Settings / shop / library no longer flashes the track from the old position — clean `fade_in` from the start; while a screen is intentionally silent, volume is not applied to the stream
- Playlists: control hints in the screen footer (hub / editor), not under the title; average-rating tag without ★
- Toast on chart ID copy; Recap PNG save/copy success uses toast instead of a blocking modal (errors still modal)
- **Achievement notifications:** unified via `StatusDock` — `trophy.svg` tinted with category accent, header + title only, block/icon sizes reverted to 1.2.0 main
- **Rhythm DNA beta removed (new in 1.2.1):** BETA badge/label removed from About generation and Rhythm DNA, moved to Chart Editor as Editor • BETA inside button

**Console**

- Improved console command consistency by removing obsolete duplicate commands and standardizing command naming
- Added new debug console tools for testing progression, Activity states, and chart section seeking

**Rhythm DNA availability**

- Rhythm DNA is now available by default for charts with full Rhythm DNA data
- The option to disable Rhythm DNA in Settings is preserved
- Charts without a complete DNA set remain correctly unavailable with an explanatory state

**Pause**

- Actions on the left; Now Playing on the right (cover, chart style, live stats)
- Footer keeps the track progress bar and clock
- Series runs show streak / track progress and finish-after-this-track

**Song results**

- New left “With this song” passport; right best run + history
- Medals; favorite style/instrument in generation colors

**Generation (client)**

- Settings → Generation: stem **GPU stack** (Auto / NVIDIA / AMD / CPU) with scan + apply

**Marathon Run Rules**

- New Run Rules for Marathon routes: **Good limit** — at most N Good hits for the whole route, and **Minimum streak** — at least N combo on each track
- Controlled variation of Run Rules between routes — the same archetype can appear with a different allowed set of Rules on different days
- Run Rules are shown in the route details as part of the route card

**Persistent drum stems**

- Drum and bass stems generated on the server are now kept on the client as MP3 files in a dedicated stem library. The library folder is configurable in Settings → Library and each chart keeps its own stems, so the correct take is always found.
- Stems are identified by the source track and the model that created them; the on-disk layout follows the chart, so different models for the same song do not overwrite each other.
- After generation the stem is downloaded once and stored persistently. The temporary download is removed after the MP3 is saved. The editor, gameplay and the metronome fallback now prefer a persistent stem before checking older locations — existing libraries continue to work as a fallback with no migration needed.
- New retention setting for the persistent library in Settings → Generation: **Delete after generation**, **Keep 15 minutes**, **Keep last 10**, **Never delete**. The setting applies only to the persistent MP3 library. Temporary files on the server are always removed after the job and do not depend on this setting. Notes and `.rf` charts are never affected.

## RhythmFall Client v1.2.0

Patch release focused on bilingual UI, redesigned menus, play modes (Library / Endless / Marathon), Original/Arcade chart goals with Bass beta, run modifiers and Rhythm DNA, generation queue, Windows-native server, and profile RR/share.

### Refactor

- Client codebase reorganized — platform, UI, i18n, and domain layers; song select, profile, and shop split into feature modules with slimmer screen orchestrators

### New

**Localization**

- Full **English / Russian** UI switch in Settings → System; menus, dialogs, generation status, shop, achievements, profile, help, HUD, victory/defeat
- First launch picks Russian when keyboard/OS locale is Russian, else English
- Server pipeline steps localized on the client; unknown server status strings may still appear in English

**Keyboard navigation**

- Shared `UiScreenHotkeys` — digit keys `1`–`6` work on any keyboard layout
- Main menu `1`–`6`; play modes `1`–`3`; song library double-click start; genre picker ↑↓ + Enter
- Generation params — Q/W goals, E/R/T difficulty, A/S/D lanes, Z advanced; modifiers/pause/victory hotkeys
- Pause `1`–`5`; victory/defeat `R` replay, `M` song list, `N`/`Enter` next track
- Settings `1`–`9` pages; Profile `1`–`4` tabs + Statistics chart metrics `1`–`3`
- F10 in-game generation QA report; metadata editor Enter save when not typing

**Main menu**

- Variant E layout — left nav with Lucide icons, centered logo and daily quests, right **hub** (stats, last track with **Play again**, recent activity, nearest achievement, tip of the day)
- Ambient wash + drifting particles; per-screen color profile; footer Help + GitHub
- **Play** opens the play modes hub (not straight into song library)
- Daily quest cards with tinted icons; last track resolves title/artist from session → library → tags → filename
- Hub stats and activity timestamps with timezone-aware parsing; deferred card load for faster startup

**Play modes hub**

- Three mode cards — **Library** (green), **Endless** (purple), **Marathon** (gold); mode-colored borders and focus wash
- Unlock economy (level + medals + diamonds); unlock dialog with checklist; pulsing **Unlock** when ready
- Card zones — last played, unlock progress, accent hints; hotkeys `1`–`3`, Enter, Esc
- Endless card — best streak badge, nearest achievement, last run replay, **Same setup** (blocked if pool empty)
- Marathon card — **Daily Marathon**, rotation countdown, routes cleared in current set; daily zone pulses until cleared
- Deferred card stats for faster open; main-menu music continues on enter

**Song library (song select)**

- Card-style details panel, larger cover, track medals grid (8 per song), scrollable metadata
- Filters — title, artist, year, BPM buckets, duration, **difficulty** (decimal stars), **notes ready**, most played; search persists between visits
- Duration groups round up to whole minutes; notes-ready groups by current generation scope
- Toolbar Lucide icons; mint highlight when notes ready for current chart style
- Dedupe protection when adding/scanning library; favorite star pop animation; double-click to start when notes ready
- Confirmations before BPM recalc or note regen (toggle in Settings → Generation)
- Two-column metadata editor; **genre picker** (see below); F10 QA; Rhythm DNA dialog after server bake
- Incremental list highlight refresh on generation queue updates (no full rebuild in difficulty filter)
- ↑/↓ always move list selection and sync the details panel (after regen confirm, focus returns to the list so the next track is not skipped); modifier UI sounds on overlays open/close

**Track preview**

- Settings → Sound → **15 s highlight** (default) or **Full track**
- Snippet picks loudest 15-second window (WAV RMS scan; MP3 hook near ~35%); fade in/out; loops while track stays selected

**Victory track recommendation**

- After clear — next track suggestion (similar BPM, genre group, harder chart when possible) with reason line
- **Next track** launches with same instrument, style, lanes, modifiers; hotkeys **N** / **Enter**

**Genre picker**

- Two-column modal — left: **server recommendations**, right: searchable 200-tag catalog
- **Top 5 EffNet predictions** (percent bars, genre icons, one-click select); cached in track metadata; **Refresh** re-runs analysis
- Confirm / reset footer; keyboard ↑↓ + Enter; status lines during upload/analysis

**Generation parameters** (new full-screen)

- Primary choice is **goal** — **Original** / **Arcade** (Q/W); **Original** hides the difficulty row (uses standard documentary bake); **Arcade** keeps Easy / Medium / Hard density tiers (E/R/T)
- Instrument grid — **Drums** and **Bass (beta)**; lane count, collapsible advanced sliders (fill, groove, density, grid, genre strength, critic, hi-hats, groove completion, raw ADTOF)
- Live preview panel with per-setting rows and note-status for current config
- **User generation presets** — 10 slots, per-slot custom charts (`drums_custom_pNN.rf`), dirty `*` marker, ✓/⚠ chart-ready badges; Generate while dirty asks save/temp/cancel
- Hotkeys — Q/W goals, E/R/T Arcade difficulty, A/S/D lanes, Z advanced, Enter confirm, Shift+R reset
- **Include hi-hats** checkbox sent to server as `include_hi_hats`
- Help article / showcase for chart goal updated (no obsolete «map difficulty» icon rows for Original)

**Chart goals (Original / Arcade)**

- **Original** = documentary fidelity (closer to detector; minimal invented fill); difficulty row hidden in UI
- **Arcade** = playable groove + densify + ergonomic lane router; **Easy / Medium / Hard** still selectable
- Filenames: Original → `drums_original.rf` / `bass_original.rf`; Arcade → `drums_arcade_{relaxed|standard|dense}.rf` (and bass equivalents); legacy `drums_original_standard` / `drums_groove` / `drums_sparse` still load
- Toolbar shows **instrument · goal · (Arcade difficulty) · lanes**; Settings → Generation → **Chart readiness** — icon rows for instruments, goals, and difficulties; drives green «ready» + mass generation
- Advanced sliders layer on top (groove completion / raw ADTOF goal-gated)

| Goal | Tier (when shown) | Feel | Policy (summary) |
|------|-------------------|------|------------------|
| **Original** | *(standard bake)* | Documentary | Detector-led; difficulty UI hidden |
| **Arcade** | Easy | Simple patterns | Groove completion + light densify |
| **Arcade** | Medium | Rhythm-game groove | Full arcade stack at standard density |
| **Arcade** | Hard | Maximum density | Highest completion/density caps |

**Bass mode (beta)**

- Second playable instrument — **Bass** in generation UI and library toolbar; charts as `bass_{goal}_{difficulty}.rf` under the same Original / Arcade goals as drums
- Note vocabulary — **tap**, **hold**, **slide** (one chart entity with `lane_end`, not two taps); multi-lane accents via `lane=1,4`; optional **ghost** notes (quiet short taps ~12% amp, +250 bonus, no miss penalty; stripped on Original, capped ~8% on Arcade)
- Server — Demucs **bass stem**, Spotify **Basic Pitch** (default) or pyin fallback; stem silence-gate, peak-lock (prefer earlier plucks), half-bar downbeat sanity, bar-template pattern fill for monotone riffs; `POST /generate_bass`
- Post-pass — same-lane micro-stacks spread across frets; Arcade densify only where stem is audible
- Client — BassTap / BassHold / BassSlide; **one kick SFX** for simultaneous multilane chord hits (35 ms dedupe); Rhythm DNA mods off for bass in v0
- Scope — library generation and play; Endless/Marathon bass parity still in progress

**Rhythm DNA**

- **`.rfd` sidecar** written with drum chart generation (passport: sections, energy, density); Explorer icon via installer (`rfd.ico`)
- **8 DNA run modifiers** (Energy pulse, Density focus, Phrase shift, Groove lock, Adaptive, Groove addiction, Energy balance, …) — need `.rfd`; bass charts do not ship DNA yet
- Modifiers screen tab **Rhythm DNA · Beta**; conflicts UX disables DNA-locked pairs; Help covers DNA category + `.rf` / `.rfd` storage
- Experimental song-card report after bake; structure segments coalesce to **≥4 bars** so mods do not flip every ~2 s

**Chart readiness (Settings → Generation)**

- Icon toggles (same visual language as Endless chart style) — **Instruments** → **Goals** → **Difficulties**; hover tooltips; cannot clear the last icon in a row
- Ready / mass-gen set = selected instruments × goals × difficulties; defaults to current single chart; presets stay on tagged files and ignore this setting
- Replaces the old dropdown (current / goal-all-diffs / diff-all-goals / all six)

**Generation queue panel**

- StatusDock notification → modal queue: active job with stage progress, pending FIFO, cancel / promote / demote, grouped rows per track (six style chips), recent history (last 10), offline pause banner + **Retry**
- Mass queue in Settings — BPM for all library + generate notes for all (respects notes-ready scope); duplicate enqueue toast **Already in queue**
- Incremental dialog refresh — full rebuild only when queue structure changes; **Queued (N)** on library buttons matches real FIFO position
- Quit with active queue — **Cancel** (keep generating) or **Clear queue and quit**

**StatusDock**

- Stacked panels bottom-left — primary (long tasks) + secondary (short toasts); themed cards, stage-aware icons
- Click or hover hint opens generation queue during BPM/notes jobs; **Space — cancel** when visible
- Settings → Generation → status **Full** / **Compact** / **Off**; taskbar attention when batch completes while minimized (exclusive fullscreen throttle context)
- Used for settings save, library scan, dedupe warnings, F10 confirmation, generation QA toasts

**Run modifiers (36)**

- Full-screen osu-style rules before play — tabs **Overview**, **Easing**, **Hardening**, **Special**, **Rhythm DNA · Beta** / **· Бета**, **Parameters**
- **Rhythm DNA (beta)** — sidebar/page label; footer callout warns section mods still need polish; requires `.rfd` sidecar from **drum** generation
- Detail panel — loop **video preview** per mod, Overview/Description toggle, per-mod sliders (HT/DT speed, EZ/ST ms windows, Heat peak/step/max %, Memory phases, Time warp curve, Dynamic lanes interval, Combo Escalation pool modal, Single lane count 1–10)
- **Conflicts UX** — two-click cards, dashed rings (gold active, blue preview, red conflict); DNA-locked mods disabled; HelpCallout footer for reward stacking
- **Reward multiplier** in summary; harder stacks → more reward (except Special)
- **Easing** — No Fail, Easy windows, Half Time (75%)
- **Hardening** — Strict, empty-lane miss, Sudden Death, Hidden, Sudden, Double Time (150%), Half HP (+8% reward), **Heat** (scroll speed rises with combo; max % at peak combo; optional song speed + preserve pitch; smooth steps; **+N%** notices)
- **Special** — fixed scroll, Autoplay (0★, no XP/currency/save), Single lane, Time warp, Pick mode, Reverse scroll, Progressive memory (fade to blind), Dynamic lanes 3–5, Mirror / Shuffle / Random, Combo escalation, Metronome only, Last Chance, **Spotlight** (dim field outside hit band), Silence, Rush
- **Rhythm DNA** (needs `.rfd`) — Energy pulse, Density focus, Phrase shift, Groove lock, Adaptive, Groove addiction, Energy balance
- **User modifier presets** — 10 slots; Mine/Favorites; **LMB** select, **RMB** preview slot, double-click / Load / Enter apply; row icon chips (5 + overflow); Esc auto-saves draft
- **In-game HUD** — active mod icon strip above combo; polls once per 60 Hz tick
- **Combo Escalation** — full-screen pool modal with mod icons and custom order
- Spotlight overlay skips relayout when hit band unchanged; Heat/Rush default scroll-only with optional song-speed toggles

**Per-track medals**

- Eight medals per song — first clear, SS rank, Hidden clear, 2+ mods, Sudden Death clear, Hard Mode clear, Grinder (3 clears), Speed Run (DT or Sudden)
- Legacy overlapping medals dropped on load; unseen medals pulse until hover
- Profile collected summary; medal-priced shop items unlock when enough medals collected — medals are **not spent**
- Medal rewards use same **Open** flow as level/achievement/daily rewards

**Chart difficulty**

- Static rating **1–10+** from note density and chord load; **decimal stars** (e.g. 7.4/10) with meter bar and tier colors
- **Effective difficulty with mods** — live base → effective on song select and victory; tooltip shows density and overflow above 10; compact ×N / +N% on modifiers row
- Song select density line shows average and peak when they differ; DT/HT scale density; hardening mods adjust stars; drum stacks count 3+ simultaneous hits
- Mastery achievements for clearing hard charts

**Health bar and defeat**

- Vertical **health bar** right of playfield — misses drain HP, good hits restore a little
- At **0 HP** without No Fail → defeat overlay with animated stats; **Replay** keeps modifiers, **Back to song list** returns to library
- **No Fail** — violet pulse at 0 HP instead of ending the run; **Sudden Death** still one-miss restart (independent of HP)
- **Last Chance** — one extra life at 0 HP (same optional 3 s resume rewind as pause); bar freezes gray at 0 until second miss

**Game screen**

- Corner HUD — combo, accuracy, score; playfield border glow by combo; configurable playfield width per lane count (70–150%)
- Vertical health bar; live **new record** flash (same chart scope as victory PB); error meter (last 20 hits)
- Music-reactive visuals toggle (experimental FFT tint); dynamic background bleed by combo
- **Auto-pause** on window unfocus in **exclusive fullscreen** only (minimize / alt-tab opens pause menu)
- Chart compare (Tab A↔B or split ghost lane); timing debug overlay

**Pause & resume**

- Redesigned pause menu — hotkeys 1–5; F1 help overlay; settings from pause
- **3 s resume rewind** (optional) — Settings → Graphics → **Rewind 3 s with animation after unpause** (default **on**); chart and audio rewind with `resume_rewind` SFX and playfield overlay; **off** = resume exactly where you paused; same rewind flow for **Last Chance** first HP zero
- Esc from pause → main menu restores menu music reliably

**Victory & defeat**

- Redesigned layout — cover poster, grade card (reserved size), RR, medals, reward breakdown panels (bar rows + Lucide icons), vs-last deltas, accuracy chart, lane statistics, modifier icons (10 + overflow)
- Dedicated victory/defeat BGM loops at menu-music volume; deferred save/achievements after intro animation
- **Personal best** — banner and deltas when score/accuracy/combo/RR improve vs same chart + modifier scope; no false PB on repeat identical runs
- **Lane statistics** — per-lane hit-rate bars; weakest lane highlighted below 90%
- **Currency/XP breakdown** — variant B detail panels; vs last run under score/accuracy when modifier set matches previous attempt
- Optional spotlight tutorial (grade, rewards, chart, replay) — once per profile
- Defeat overlay with animated stats; **Next track** row with N / Enter hotkey

**First-visit tutorials**

- **Song library** — 5-step spotlight (list → generation → modifiers → generate → play)
- **Shop** — 3 steps (categories → items → collection progress)
- **Run modifiers** — 5 steps (tabs → cards → gear → Parameters → Confirm)
- Back, ←/→, Space/Enter, Esc skip; once per screen flags

**Hit particles and shop**

- **Hit particles** category — burst presets unlocked with medals; click preview to burst in card
- Kick cards draw **real waveform**; **Listen** animates playhead
- Four collections — **Forest**, **Synthwave**, **Sunset**, **Sakura**; medal-priced kicks, palettes, lane highlights
- Shop remembers last category tab; in-game bursts stay calm CPU particles (no card-only glow in gameplay)

**Profile**

- Four tabs — Overview, Statistics, Genres (15 collections / 200 tags), Records; category nav like shop/settings (no double hover)
- **Rhythm Rating (RR)** — per chart config from accuracy, difficulty, grade, full combo, mods; best RR in milestones
- Overview — favorite track, KPI tiles, track medals, genre portrait + recent achievements in one row (marathon/mod summary lives in Records only)
- Statistics — insight card, stat grids, grade tiles, session chart; unified teal accent on chart line and metric toggles; chart color per metric (blue/gold/purple)
- **Genres** — 15 balanced collections; X/Y discovery + mastery bar (cap 20); expand row syncs both cards; Lucide icons per collection
- Records — RR Top 10, milestones, extremes, mod clears (list rows + tooltips), Endless/Marathon sections
- **Recap share** — five PNG cards (Overview, Statistics, Music, Records, Play modes), cached snapshot, per-frame preview, HTML export; Export under category bar (not over XP HUD); share hotkeys 1–5; local timezone footer date
- Locale and queue refresh without full Overview rebuild; faster open with deferred heavy sections

**Achievements**

- **165 achievements** — new **Modifiers** category, **Play modes** 152–165 (Endless + Marathon), genre mastery/collector, RR milestones, generation counters, system 129–132
- Redesigned cards; category filter; unlock popup (StatusDock-style slide/fade)
- Daily quests reference modifier clears; infinitive task wording in Russian; Autoplay runs do not count toward modifier goals

**Settings** (nine sidebar pages)

- **Sidebar redesign** — Lucide icons, title + description, per-page accent borders; left nav + scrollable content card
- **Sound** — volumes, mute, track preview mode (15 s / full), calibration (offset, latency, tap test)
- **Graphics** — quality, FPS counter, brightness, **playfield width** 3/4/5 lanes, **optional 3 s pause resume rewind**, ambient particles, reduce resources while minimized (30 FPS + mute in exclusive fullscreen only)
- **Controls** — key bindings, alternative layout, **Guitar Hero** preset (XInput frets, strum, pause/skip); layout mode primary / alt / both
- **System** — language EN/RU, update check on startup
- **Generation** — server Auto/Manual/LAN; **Chart readiness** icon rows (instruments → goals → difficulties); mass BPM+notes queue; stem retention; confirm before regen; notify when gen finishes while minimized; status Full/Compact/Off
- **Library** — songs/notes folders, chart ID toggle, scan timestamp
- **Data** — backup tools
- **Experimental** — console, chart compare (Tab A↔B or split ghost), experimental chart tag, timing/drum debug, Rhythm DNA button on song card
- **Danger zone** — profile/settings reset
- Deferred **Apply** / **Space**; Esc unsaved-changes dialog; hotkeys 1–9; instant-save exceptions for library scan and songs-folder migration

**Ambient menu backgrounds**

- Shared layer — soft color washes + drifting dot particles behind menu screens; motion pauses on gameplay
- Per-screen profiles — main menu, song library, play modes (library/endless/marathon focus), victory, defeat, profile, shop, achievements, help, settings, modifiers
- Settings → Graphics → **Ambient menu particles** toggles dots (washes stay on)

**UI polish**

- **Framed elements** — smoother corner radius on icon frames and inset panels (song library generation cards, shop item cards, achievement cards, modifier sidebar tabs, preview rows)

**Experimental settings** (ninth page)

- **Chart compare** — Tab swap (one playfield, Tab toggles A/B) or split screen (production left, variant ghost right); variant tag suffix for `*_tag.rf`
- **Experimental generation** — server `RFALL_CHART_VARIANT` writes tagged charts without overwriting production
- **Timing & drum debug** — hit log CSV, on-screen signed ms overlay, drum class colors when `.rf` has drum column
- **Console** — `~` + Shift when enabled; flags persist in settings.json

**Background behaviour while minimized**

- Exclusive fullscreen only — 30 FPS cap + Master mute on alt-tab/minimize; borderless and windowed keep full FPS and audio
- Taskbar flash once when queued generation batch completes in background (not a Windows toast)
- Does not throttle RhythmFallServer stem separation while notes generate

**Endless mode**

- **Session setup** — random / selected playlist, difficulty & duration filters, mod policy, genre groups; config in `endless_session_last`
- Filter chips open own panels; double-tap chip collapses; favorites-only; **unique songs** (no path repeats); mod conflict strategy (Reshuffle / guaranteed / strict random)
- **Chart style** — Original / Arcade goal icons always visible (no All / Selected policy buttons); pool = selected goals × all three generation difficulties; rating-tier icons same pattern when shown
- **Playlist manager v2** — hub (list + create) + editor (search, filter modal, pinned chart stem per entry); entry tags auto-assigned; schema v2 with legacy migration
- **No series RR** — Endless awards XP/coins only; RR stays Library (+ Marathon deltas)
- **Gameplay** — multi-track series on one game screen; Song N reveal; score/accuracy/combo carry; pause shows streak and tracks left
- **Progressive Memory** — notes fade to invisible (not faint ghost); reveal window shrinks over song progress
- **Summary** — streak, accuracy, rewards; **Play again** same config; profile Records section; achievements **152–158**
- Play modes card — best streak, last run replay, **Same setup**

**Marathon mode**

- Fixed route list built once from library; win by clearing last track or fail on rules/HP/exit (vs Endless: «where do tracks come from?»)
- **Unlock** — level 22, 55 medals, 7500 diamonds; achievement **159 Route runner**
- **Catalog** — 8 rotation archetypes + Daily; rotation every 3 days; hero + rules + badges + preview
- **Locked routes stay visible** — honest **«Not enough matching songs. At least N required.»** + disabled Start (no padded routes); **Refresh pool**; auto-refresh when library grows or notes complete; re-open refreshes preview cache
- **Setup lock tiers** — Sprint/Standard open → Ultimate fully locked (lanes, chart style, mods scale by archetype)
- **Duration-first builder** — `target_duration_minutes` ±20%; flexible track count; unique songs; **finale boss** track last
- Per-route settings — chart style icons (goals), mod pool, track order, lanes; saved per route id; no legacy intent auto-expand (`original`→`sparse`)
- **Run rules** — hp recovery, max misses, min accuracy gates; **route badges** bronze→legend per season route version
- **Daily route** — seeded per calendar day; play modes card zone + catalog tab
- Same multi-track game screen as Endless; finish screen persists XP, route completion, badges; achievements **159–165**
- Summary — rules panel, mods panel (**No mods** uses `ban.svg` chip), route badges, audio preview, progress panel

| Archetype | Role | ~Time | Tracks |
|-----------|------|-------|--------|
| Sprint | Quick run | 10 min | 3–4 |
| Standard | Classic climb | 20 min | 5–7 |
| Boss Rush | Hard + finale boss | 20 min | 4+1 |
| Precision | Accuracy gate 92% | 15 min | 4–5 |
| Survival | HP/miss limits | 35 min | 8–10 |
| Chaos | Random locked mod | 15 min | 4–6 |
| Journey | Long + finale boss | 30 min | 7–8+1 |
| Ultimate | Longest set | 60 min | 12–15 |
| Daily | One route per day | 15 min | 3–5 |

**Rhythm DNA — generation report**

- Experimental button on song card after server bake; fetches `.rfd` sidecar
- Full-screen dialog — confidence %, track structure timeline, pipeline steps, action cards, track genes, warnings
- Structure segments coalesce to **≥4 bars** minimum so DNA mods do not flip every ~2s on fast BPM
- **Weak percussion** badge when `percussion_viable` is low

**RhythmFallServer & generation pipeline**

- **Windows-native** — `RhythmFallServer.exe` with bundled venv; BPM (TempoCNN), EffNet genres, stems offline; WSL deprecated
- **ADTOF** default drum hit detection (`adtof_fast`); heuristic fallback if missing
- **Genre profiles** + augment JSON; style→difficulty pipeline (Original documentary vs Arcade playable); section pass; critic drum-entry recovery
- **Bass generation (beta)** — pyin on bass stem + goal×difficulty transforms; density-aware hold→tap / grid snap; separate stem cache from drums
- **Arcade ergonomic lane router** — cost-based lanes (kick low, snare mid, hats flow); Original keeps weighted-random
- Six goal×difficulty bundles via `resolve_goal_difficulty`; GenRecap logs stem labels
- Auto-managed worker on port 5000; stops on game exit; genre detection once per track in mass queue
- GPU optional (CUDA/DirectML/CPU); stem cache TTL; hash-keyed `temp_uploads/`

**Chart format & library tech**

- Human-readable **`.rf`** (RFC v1); charts in `{chart_id}/` folders; one file per instrument + goal×difficulty stem
- Legacy flat JSON and old stem names still load; dedupe blocks duplicate adds; bundled duplicate hidden when user copy exists
- Worker prewarm after launch; FIFO queue one active job; next task starts immediately after previous finishes

**Help**

- Two-column redesign — sidebar accordion, flow diagrams, UI showcases, callouts with Lucide icons
- F1 from pause; deep links from settings; keyboard 1–6 sections + arrow navigation
- Articles for modifiers (36), presets, generation scope, Marathon, Endless, GH controller, profile export

**Client version**

- HUD build label; Settings → Check for updates; optional startup notice

### Removed

**Shop cover gallery & selectable covers**

- **Cover gallery** overlay removed (`cover_gallery` scene/flow from the shop) — packs no longer open a dark modal grid to browse numbered cover variants
- **Click-to-select covers** gone — cosmetics that previously shipped multi-image folders (`images_folder` / `images_count`) no longer let you pick an alternate cover; the shop shows the item’s primary preview only (behavior from v1.1.10 gallery rework)

**Replaced elsewhere (no longer in the old form)**

- Legacy **Chart readiness** dropdown (`Current` / goal-all-diffs / diff-all-goals / all six) — replaced by instrument × goal × difficulty icon rows (see **Chart readiness** under New)
- Combined **Misc** settings dump — split across Generation, Library, Data, Experimental, and Danger (nine-page sidebar)
- Release **WSL** server path — Windows-native `RhythmFallServer` worker is the supported launch path (WSL kept only as deprecated/legacy; see Notes)

### Fixes & Improvements

**Settings, chart readiness & mass generation**

- Settings → Generation: expanded chart readiness selection (instruments → goals → difficulties) using icon-grid axes; mass generation respects the selected axes set.

**UI polish**

- Improved SVG icon rasterization/scaling to reduce pixelation on icon-heavy screens.

**Achievements & profile**

- Achievements screen/category redesign polish (visual consistency with updated progress/tiles layout).

**Song library & metadata**

- **Song select** — fixed `notes_ready_for_scope` cache key (`%s` formatting error blocked song select and generate)
- **Song library** — metadata save updates the selected row in place without replaying the list slide animation

**RhythmFallServer (shared with 1.1.x deployments)**

- Restored missing `salience_recap_line` import (generation could return HTTP 500 after recap changes)

### Notes

- Note generation still requires RhythmFallServer (bundled for Windows; rebuild exe after pulling launcher changes)
- Autoplay earns no XP/currency and is not saved to per-track results
- Legacy `drums_original` / `drums_groove` / `drums_sparse` charts still load; regenerate for six goal×difficulty stems
- **Chart folder layout:** drums → `drums_original.rf` or `drums_arcade_{relaxed|standard|dense}.rf` plus paired `.rfd`; legacy names (`drums_original_standard`, `drums_groove`, `drums_sparse`, `drums_basic_lanes*`) still load; **bass** → `bass_original.rf` / `bass_arcade_*.rf` only after generating with **Bass** — **no `.rfd`**
- WSL deprecated for release — auto-start uses hidden Windows worker
- GPU and ADTOF optional — CPU fallback works; run install script for GPU/ADTOF packages
---

## RhythmFall Client v1.1.11

Patch release focused on library management, results display, shop reward visibility, metadata and genre picker UI, debug tooling, and song-select fixes.

### New

**Shop category badges for new rewards**

- Category tabs in the shop show how many reward items you have not opened yet (level milestones, achievements, daily quest rewards — not currency purchases)
- Same red badge style as the main menu Shop button; the All tab shows the total across categories
- Counts update when you press Open on an item card

**Metadata and genre picker UI refresh**

- Edit metadata uses the same card-based layout as other menu screens: header, subtitle, labeled fields, save action below the card
- Genre picker matches that layout — search and scrollable list inside the card, with Reset genre at the bottom of the card

**Delete track from library**

- Delete on the song select screen removes a user-added track from the library after confirmation
- Built-in bundled tracks cannot be deleted
- Removes the audio file from disk, generated notes, and saved results for that track
- Delete button stays correctly enabled or disabled after note generation finishes (no longer stuck until you re-select the track)

**Results show generation mode**

- Per-song results list displays instrument and generation mode (for example Drums · Basic)
- Older entries without a saved mode show a dash in the mode slot

### Fixes & Improvements

**Song library and results**

- Song select screen works again after a script parse error had blocked the whole screen
- Per-song results sorted by date and time (newest first), not by score
- Session history keeps the 20 most recent runs in chronological order

**Debug console**

- `game.win` respects the accuracy argument instead of always reporting 100%

**Shop performance**

- Opening the shop no longer lags — unseen reward checks no longer scan the full catalog for every item card

### Notes

- Track deletion is irreversible for user-imported files; built-in bundled songs remain protected
- Generation mode appears in new results after playing with current settings; replay a track to backfill older entries if needed
- Shop category badges and main menu shop notification use the same unopened-reward rules — currency purchases are never counted

---

## RhythmFall Client v1.1.10

Patch release focused on UI polish across shop, achievements, and main menu, help screen redesign and onboarding, first-run server notice, cover gallery rework, Lucide currency and XP icons, grade color system, unified menu interaction, achievement synchronization, settings tab theming, debug autoplay timing, Windows installer, and catalog data sync on update.

### New

**Redesigned Help screen**

- Scrollable layout with accordion expand/collapse per item
- Categories as toggle buttons that group related questions
- Content and color palette loaded from external JSON — edit text and colors without rebuilding the game
- Getting Started section at the top for new players (first launch, RhythmFallServer, audio calibration, controls, adding songs, grades, progress after the first song)
- Bundled help version field — client refreshes user copy when a newer help file ships with the build
- Question cards nested under categories: darker inset panels, left indent, muted borders — visually distinct from category headers

**First-run server setup notice**

- Welcome dialog on first main menu visit explains RhythmFallServer and the path: install server → Settings → Misc → BPM → generate → play
- Open repository button links to RhythmFallServer; Got it dismisses and remembers the choice
- Notice can show again after a full profile statistics reset

**Cover gallery reworked**

- Modal overlay darkens the shop screen behind the gallery
- Fixed four-column grid with cells that resize from narrow to wide based on window width
- Numbered badges, hover effect, click-to-select
- Asynchronous cover loading with placeholder fallback

**Shop visual refresh**

- Screen header and category/filter rows styled like other menu screens, with unlock progress bar
- Item cards: category accent borders, icon frames, active and unlocked glow
- Card pop animation on Buy, Use, and Open only — not on hover
- Tuned name and status font sizes; long names clip cleanly

**Shop notifications for new reward items**

- Main menu shop button shows a count of unopened reward items (achievements, level milestones, daily quest milestones)
- Currency purchases are not counted — only items newly unlocked as rewards
- In the shop, unopened rewards get a gold card border and a yellow Open button instead of Use
- Counter and highlight clear only after Open is pressed (same apply sound as Use)

**Achievements visual refresh**

- Screen header and filter row match shop and menu styling
- Achievement cards: category accents, icon frames, unlocked glow, enlarged title, description, and progress text

**Main menu refresh**

- Daily quests panel: mint-accent shell, card-style quest rows, themed progress bars
- Completed quests show gold border and progress fill
- Diamond icon beside daily quest currency reward
- Shop new-rewards badge in the scene layout
- Title color aligned with shop and achievements headers
- Menu buttons keep their familiar embedded styling

**Lucide icons (currency and XP)**

- Diamond icon for HUD currency, daily quest rewards, and victory currency row
- Gauge icon for HUD level row and victory XP row

**Grade display and SS colors**

- Letter grades use consistent colors everywhere (victory, song select, profile)
- First SS clear on a track shows gold; repeat SS clears on the same track show green
- SS clear count tracked per track permanently — not lost when recent-results history rolls over
- Recent results keep the correct repeat-SS color for older entries

**Unified interaction system**

- Shared cursors and button hover effects across menu UI
- Pointer on buttons, spin boxes, lists, and other interactive controls; resize cursors on sliders; I-beam on text fields
- Button hover uses live theme colors
- Applied on screen open and for dynamic overlays (victory currency/XP, shop cover previews)

**Windows installer**

- Pre-built Windows distribution via Inno Setup — Start menu shortcut, optional desktop icon, uninstall through Windows Settings → Apps
- On uninstall, optional prompt to delete saves in AppData (default: keep saves)
- Portable ZIP variant with a separate uninstall helper for folder-only installs

**Catalog sync on update**

- On each launch, bundled catalog JSON next to the game is merged into the user data folder so shop, help, quests, genres, and achievements can update without wiping progress
- Player progress and song metadata are never overwritten by the sync

### Fixes & Improvements

**UI polish**

- Achievements list no longer clipped; scroll area expands correctly
- Removed stray tab characters from Back button labels across menu screens

**Shop**

- Removed duplicate in-shop currency chip (HUD already shows balance)
- Currency pulse on purchase targets the HUD label only
- In use and Default status labels display correctly again after layout fixes

**Settings screen polish**

- Outer margins and consistent navigation header (back button, title, subtitle)
- Tab bar keeps per-tab accent colors; active vs inactive state via modulate only
- Controls tab reset action uses the pink accent to match the tab
- Misc tab section panels show colored borders again
- Content card wrapper with solid background, rounded corners, and shadow
- Setting panels use themed section styles (teal Volume, blue Display, mint Gameplay, and so on)
- Calibration and action buttons receive hover like the rest of the menu UI

**Main menu and cover gallery adaptive layout**

- Main menu buttons and header anchored to window size (no fixed 1920px width)
- Title and subtitle no longer clipped on narrow screens
- Cover gallery adjusts cell size while keeping four columns

**Pause menu**

- Pointer cursor and accent hover via the shared interaction helper
- **Restart** button icon tinted to match **FlatGenerateButton** (mint), same as other pause actions with accent icons

**Victory screen**

- Recommendation UI uses a crisp disc icon (no cover RAM cache); artist and title visible in the recommendation row
- Hint for currency and XP detail view appears only after the grade reveal animation finishes
- No overlap with the counting animation; reward lines are not clickable until the hint appears

**Profile screen**

- Favorite-track cover no longer looks blurry or compressed at thumbnail size
- Same high-quality scaling as song select — proper filtering and aspect-fit cropping
- Recent sessions and song details use the same grade colors as victory

**Achievement synchronization**

- Playtime achievements use exact seconds from total play time
- Full unlock sync on game start and when opening the shop when progress was met but the flag was missing
- Shop unlock state and achievement tooltips stay in sync
- Debug achievement unlock updates player progress from the main menu immediately

**Debug console**

- Daily quest complete-all command correctly finishes genre-group quests (for example jazz or soul play tasks)

**Debug autoplay timing**

- Autoplay hits when the note reaches the hit line (chart time and geometry), not on stale pixel crossing
- Note positions updated before autoplay each frame to match audio clocks
- Hold notes keep the lane pressed for the full hold duration
- Lane highlight timing aligned with chart time
- Timing debug overlay shows line-average delta during autoplay
- Console: `game.autoplay` toggles autoplay; `timing.autoplay.windows` uses the same windows as manual play

### Notes

- **`logic/` layout** — scripts grouped into `core/` (engine, transitions, settings, gameplay session), `data/` (library, player, achievements, milestones), `services/` (generation, music, updates), `utils/` (stateless helpers)
- Cover gallery uses a fixed four-column layout with resizing cells across common resolutions
- Shared interaction helper bridges runtime theme onto controls that use local or embedded scene themes
- Main menu buttons keep embedded styling; other refreshed screens use the global app theme
- Time-based achievement rewards unlock reliably even when progress and unlock flags were previously out of sync
- Autoplay is a debug and testing tool; with a negative timing offset in settings, hit-minus-note average reflects that offset — use the line-average overlay to verify visual rhythm
- Note generation still requires the separate RhythmFallServer — not bundled with the client installer
- Installing a new build over an older one keeps saves in AppData; catalog JSON updates apply on the next launch

## RhythmFall Client v1.1.9

Patch release focused on network resilience, replay consistency, and major UI redesign for Settings, Profile, and Victory screens.

---

### New

- **Resilient note generation over slow / VPN connections**
  - 404 “unknown task” is no longer treated as a fatal error during remote generation
  - Client now polls patiently until the server registers the task after full file upload
  - Fixes false failures over Radmin VPN, high‑latency Wi‑Fi, and slow uplinks

- **Replay preserves generation settings**
  - “Replay” button on victory screen restarts the song with the same:
    - Generation mode (minimal / basic / enhanced / natural / custom)
    - Lane count (3 / 4 / 5)
  - No more unexpected resets to default 4 lanes + basic mode

- **Complete UI redesign for Settings screen**
  - Tab‑based layout (Sound / Graphics / Controls / Misc) with improved spacing
  - Sound tab: grouped sections (“Volume” and “Timing calibration”), paneled sliders (min width 320px)
  - Graphics tab: “Display” and “Gameplay” panels, fixed‑size controls (260×50)
  - Controls tab: scrollable key binding table with headers, reset button, inline hint
  - Misc tab: three logical blocks (Generation, Songs, Data), dangerous actions in a 2‑column grid
  - Consistent styling with other screens (panel containers, centered content, accent headers)

- **Profile screen redesigned as a dashboard**
  - Favorite track card (horizontal layout: cover + title/artist/genre)
  - Four‑tile highlight row: Level/XP with progress bar + playtime / accuracy / levels completed
  - Dynamic statistics grid (value + label) with color coding (hits, misses, streak, currency)
  - Grade tiles (SS / S / A / B) with large values instead of plain labels
  - Achievements compactly placed in the right column below grades
  - Compact accuracy chart (green line, ~190px height)
  - No empty columns, better vertical space usage

- **Victory screen redesigned with adaptive layout**
  - Responsive design (no more hardcoded 1920×1080 positioning)
  - Prominent grade (SS/S/A/B/C) at the top (72px)
  - Two‑column statistics grid with color coding:
    - Score, combo, accuracy, currency, XP, max combo, hits, misses
  - Horizontal action buttons (Continue / Menu / Replay)
  - XP and currency detail dialogs use modal‑style cards with colored bonus rows and clear totals

---

### Fixes & Improvements

- **Network & generation**
  - Note generation over slow connections no longer fails with “unknown task”
  - Polling logic for remote servers now correctly distinguishes “not yet registered” from fatal errors

- **Gameplay & replay**
  - “Replay” button preserves generation mode and lane count
  - Default values (4 lanes, basic mode) used only when song_info lacks saved parameters

- **UI & layout**
  - Settings screen fully reorganized into logical sections with panel containers
  - Profile dashboard replaces scattered labels with dynamic tiles and compact layout
  - Victory screen now scales across all resolutions without clipping elements
  - XP / currency detail dialogs redesigned as modal cards with distinct accent colors

---

### Notes

- The 404 “unknown task” fix makes note generation reliable over VPN, mobile hotspots, and any connection with high upload latency
- Replay now respects the exact generation settings that were used to complete the level — no more surprise resets
- Settings, Profile, and Victory screens now share a unified visual language (panels, tiles, accent colors, adaptive layout)

## RhythmFall Client v1.1.8

Patch release focused on queue stability, data integrity, visual feedback, metadata editing UX, help system flexibility, sub‑frame audio synchronization, and externalized daily quests.

---

### New

- **Hit particles & central judgment label**
  - Particle burst on PERFECT/GOOD hits — colored burst matching lane color (white‑tinted for PERFECT)
  - Central judgment label with pop animation:
    - Larger font (68px) with dark outline for readability
    - Pop‑in animation (scale 1.4 → 1.0) with spring curve
    - Shows PERFECT (yellow), GOOD (blue), and MISS (red)
    - Miss shown for both timing errors and missed notes (false presses remain silent)

- **Unified metadata editor**
  - Single full‑screen modal dialog for all fields:
    - Title, Artist, Year, Genre, BPM (SpinBox 90–400)
  - Replaces multiple separate popups
  - Double‑click any field in edit mode opens the same window
  - Only actually changed fields are saved (no accidental placeholder overwrites)
  - Visual hint: editable fields have a light blue tint when edit mode is enabled

- **Externalized help content**
  - All help screen text and colors moved to `data/help_content.json`
  - Edit without recompiling or rebuilding the game
  - Supports named color tokens (`[color=#{primary}]...[/color]`)
  - File is copied to `user://` on first open for easy customization

- **Externalized daily quests**
  - Daily quests pool loaded exclusively from `data/daily_quests.json`
  - Add new quests, change conditions or rewards without touching code
  - File is copied to `user://` on first launch
  - All trigger types (accuracy, combo, playtime, genre, stats) verified and working

- **Sub‑frame audio synchronization**
  - Game time is now based on precise audio playback position (accounts for last mix time)
  - Note movement and hit registration use the same audio‑driven clock
  - Fully independent of frame rate — no drift between visuals and sound

---

### Fixes & Improvements

- **Queue deduplication & cancellation**
  - BPM and note tasks cannot be added twice for the same song/parameters
  - Cancel is instantaneous (UI updates immediately, no waiting for server response)
  - Delete button unlocks right after cancel — no need to switch songs back and forth
  - Cancel clears only the selected song from queue; other songs continue processing

- **Data integrity & atomic saves**
  - JSON saving now uses atomic swap (`.tmp` → original → `.bak` cleanup)
  - Prevents data loss on power failure or write errors
  - Shop double‑buy protection (currency not deducted twice for the same item)

- **Gameplay fixes**
  - Notes are never counted twice (no duplicate miss/hit registration)
  - False key presses during intro (before first note appears) are completely ignored — no miss sound, no combo break
  - Note movement and hit detection are now frame‑rate independent (no drift at 64+ FPS)
  - Perfect/Good timing windows align with what the player actually hears

- **Metadata & UI locking**
  - Manual edits survive ID3 scanning and game restarts
  - Path normalization fixes duplicate song entries on Windows
  - Editing and delete buttons are disabled while generation/BPM is running (visual greying out)
  - Lock state is consistent across all actions and task types

- **Animation system**
  - Shop card pop animation on purchase/apply
  - Currency label flash when spending
  - Song details panel: smooth fade transition when switching tracks
  - Status buttons (BPM / Generate) pop briefly on successful completion

---

### Notes

- Sub‑frame audio synchronization ensures that note visuals and hit registration are perfectly aligned regardless of frame rate
- Help content and daily quests can now be updated without touching code or rebuilding the game
- The unified metadata editor centralizes all song information in one place
- Atomic JSON save guarantees that progress and settings are safe even if the game crashes mid‑write
- All animation systems now share a consistent “pop” aesthetic across screens

## RhythmFall Client v1.1.7

Patch release focused on network stability, metadata persistence, UI feedback, and full cancellation support.

---

### New

- **Network resilience — stable generation over VPN / NAT**
  - Server-side result caching: generation results are now stored by `task_id` and retrieved via `GET /task_result`. Fixes dropped POST connections over unstable networks (Radmin VPN, high‑latency Wi‑Fi).
  - Fire-and-Forget + polling: for remote servers, the client no longer relies on reading the POST response body. After starting a task, it polls `GET /task_result` until the result is ready.
  - Robust HTTP body reading: fixed premature exit on empty chunks during large JSON response parsing. Eliminates `"Error: 200"` errors and truncated note data.

- **Metadata editing protection**
  - Lock editing during generation: title, artist, BPM, genre, and cover cannot be edited while a task (BPM or note generation) is active for that song. Locked fields are visually greyed out. Other songs remain editable.
  - Preserve manual edits from ID3 and seed data: ID3 tags and seed metadata now only fill empty or placeholder fields (`"Unknown"`, `"Untitled"`, etc.). User changes are never overwritten automatically.
  - Path normalization: all song paths are stored with unified slashes (`/`). Fixes duplicate metadata entries on Windows and cross‑platform path mismatches.

- **UI & progress feedback**
  - Detailed progress bar: bottom notification now shows queue position `(N/M)`, stage number `(K/T)`, percentage bar `[█████░░░░░]`, and human‑readable stage name.
  - Clean BPM notifications: removed generation parameter suffix from BPM messages — BPM is independent of note generation settings.
  - Consistent stages: BPM — 7 steps, Notes — 11 steps. Fully mapped on the client side.

- **Full cancellation support**
  - Server‑side cancellation: `Cancel` now sends `GET /cancel_task?task_id=...`. The generation process on the server is actually stopped — no wasted resources.
  - UI instantly reflects cancellation: buttons are re‑enabled, progress disappears, and a clear `"Cancelled"` message is shown (not an error).
  - Cancel clears queues: removes the cancelled task from the generation queue and proceeds to the next pending song.

---

### Fixes & Improvements

- Remote server mode now uses polling instead of a single long‑lived POST connection. Fallback to `GET /task_result` even when POST parsing fails on localhost. No more truncated JSON or hanging progress indicators.
- Manual edits no longer lost after ID3 scanning or game restart.
- Duplicate entries caused by mixed slashes in paths are gone. UI always shows the actual saved data after editing.
- BPM button no longer stuck on `"Analyzing…"` after task completion.
- Cancel during BPM or note generation properly resets UI. Progress bar and queue position update without desync.
- Disabled editing for busy songs prevents data inconsistency between client and server.

---

### Notes

- Servers must implement `GET /task_result` to benefit from the new polling mode. Old servers still work via the legacy POST body reading (localhost only).
- Percentage is updated **per stage**, not continuously inside long phases (e.g., stem separation). Smooth intra‑stage progress requires server‑side `progress` field in `/task_status`.
- Cancellation during stem separation or model inference stops at the next safe checkpoint, but the server will eventually abort the task.

## RhythmFall Client v1.1.6

Patch release focused on generation server configuration, UI behavior in settings, and input validation improvements.

---

### New

- **Generation server configuration (localhost / LAN)**
  - Added ability to switch between local server and another PC in the network
  - New settings:
    - `generation_server_use_lan_host` — toggle between localhost and LAN
    - `generation_server_lan_host` — server IP or hostname
    - `generation_server_port` — server port (default: 5000)
  - Settings are saved to `user://settings.json` and persist between sessions

- **Settings UI — Generation Server section**
  - New section: “Generation Server (Flask)” in Settings → Misc
  - OptionButton with modes:
    - Local (127.0.0.1)
    - Network (another PC)
  - Host input field (LineEdit):
    - Visible only in LAN mode
  - Port input (SpinBox):
    - Consistent styling with other settings
  - Changes are applied and saved immediately

---

### Fixes & Improvements

- **Network settings & UI behavior**
  - Correct visibility handling for host input field when switching modes
  - UI state properly restored when reopening settings tab
  - Improved consistency with other settings tabs (fonts, spacing, controls)

- **Input validation (host & port)**
  - IPv4 validation:
    - Up to 4 octets (0–255)
    - Auto-insertion of dots for continuous numeric input
  - Hostnames supported:
    - Non-numeric input is preserved as entered
  - Input constraints:
    - Max length: 253 characters
    - Basic normalization for IPv4-like input (trimming extra dots/spaces)
  - Port is validated and clamped to valid range (1–65535)

- **HTTP client behavior**
  - All API requests now use unified `_api_host()` and `_api_port()` logic
  - Fallback to `ProjectSettings` is used when `SettingsManager` is unavailable
  - Connection timeout errors now include actual `host:port` (for generation endpoints)

- **UI & behavior**
    - Fixed HintLabel positioning in `game_screen.tscn` (incorrect anchors):
      - Anchored to bottom edge across screen width
      - Text wrapping prevents overflow

---

### Notes

- The update introduces configurable server connection without requiring code changes  
- LAN mode allows using a remote generation server within the same network  
- Fallback to Project Settings ensures basic functionality even if user settings are unavailable  
- Validation reduces common input errors but does not restrict custom hostnames

# **RhythmFall Client v1.1.5**

Patch release focused on start-of-level synchronization, timing stability, and note queue reliability.

---

## **Fixes & Improvements**

- **Start synchronization (single timing domain)**
  - Fixed desync between first notes and music at level start
  - Removed dual-timer setup (`game_timer` + `SceneTreeTimer`)
  - Music now starts strictly when `game_time >= 0` inside the main update loop
  - Music start is aligned with the same frame as `game_time` update and note spawning

- **Pre-delay handling stability**
  - Introduced `pending_game_music_path` for delayed music start
  - Removed external scheduling — playback is now controlled entirely by game time
  - Pause before music start behaves correctly:
    - No premature playback
    - No invalid resume attempts

- **Note queue consistency**
  - `note_spawn_queue` is now always sorted by time after loading
  - Prevents incorrect spawn order with unordered JSON data
  - `get_earliest_note_time()` now scans the full queue instead of relying on the first element

- **First-frame timing stability**
  - Removed forced sync of `game_time` to audio position on playback start
  - Eliminates timing jumps on the first frame
  - Time progression remains continuous from the internal game timer

- **General timing robustness**
  - Synchronization with music (`_sync_game_time_with_game_music`) only applies after playback starts
  - Stable behavior across restarts and scroll speed changes
  - No dependency on external delay timers

---

## **Notes**

- Eliminates common early-note desync caused by parallel use of `SceneTreeTimer`  
- Delayed music start is now tied to the main game loop and game time  
- Note queue is always ordered by `time`, and earliest-note calculation is resilient to unordered JSON  
- Hit windows and judgement logic remain unchanged  

## RhythmFall Client v1.1.4

Patch release focused on adaptive UI behavior across supported resolutions, improved window mode handling, and removal of fixed-resolution dependencies in core gameplay systems.

---

### New

- **Adaptive UI layout improvements**
  - Main screens partially migrated to anchors / Full Rect layout approach
  - UI now scales correctly across supported resolutions:
    - 1280×720
    - 1600×900
    - 1920×1080
  - Reduced reliance on hardcoded pixel positions in critical UI areas
  - HUD and playfield layout now derived from viewport and playfield dimensions

- **Window mode system**
  - Replaced fullscreen checkbox with dropdown selector:
    - Windowed
    - Exclusive Fullscreen
    - Borderless Fullscreen
  - Settings are applied immediately and persisted between sessions

- **Window resolution presets**
  - Added fixed resolution presets:
    - 1280×720
    - 1600×900
    - 1920×1080
  - Window size is explicitly set via selected preset
  - Window is automatically clamped to the usable screen area

---

### Fixes & Improvements

- **Gameplay resolution independence**
  - Removed hardcoded 1080px dependency from note logic
  - Note spawn and despawn are now based on actual playfield height
  - Consistent behavior across all supported resolutions

- **Window behavior**
  - Window size is clamped to the screen usable rect (taskbar-aware area)
  - Fixed UI clipping issues in 1920×1080 windowed mode
  - Improved window centering within usable display area

- **Track cover loading**
  - Fixed race condition in asynchronous cover loading
  - Fallback covers can no longer override valid track covers
  - Ensures correct cover always matches selected track

- **UI behavior**
  - Improved scaling behavior across all major screens during resolution changes
  - Reduced edge cases where UI elements were partially clipped
  - More consistent HUD and menu layout during window/resolution changes

- **Display settings system**
  - Resolution selection disabled in borderless mode
  - Unified handling of window mode + resolution combination
  - Centralized application of display settings via SettingsManager

---

### Notes

- This update focuses on **UI scalability and window mode consistency within supported resolutions**
- Core gameplay systems (notes, timing) are no longer tied to fixed pixel values
- Base rendering logic still uses 1920×1080 as a design reference resolution
- Game behavior is now stable across window mode and resolution changes

## RhythmFall Client v1.1.3

Patch release focused on generation improvements, preset architecture, note stability, and minor UI enhancements.

---

### New

- **Preset system — declarative architecture**
  - Generation presets are now fully defined on the server as structured data
  - All modes (`minimal`, `basic`, `enhanced`, `natural`, `custom`) are described through a unified preset configuration
  - Generation behavior is now driven by preset parameters instead of hardcoded logic
  - `Natural` — remains a “clean” mode without server-side pattern enhancements
  - `Basic` — the only mode with section-based timing correction
  - `Custom` — allows client-side parameter overrides (`fill`, `groove`, `density`)

- **Improved note variants generation**
  - `notes_variants` (3 / 4 / 5 lanes) are generated in a single pass
  - Additional variants are created via fast lane redistribution
  - More efficient mass generation workflow

- **Note visual accent setting**
  - New graphics option: **“Lane approach accent”**
  - Available modes:
    - None
    - Lighter
    - Darker
    - More saturated
  - Effect depends on note distance to the hit zone
  - Applied in real time and saved between sessions

---

### Fixes & Improvements

- **Generation & balance**
  - Added density guardrails:
    - Minimum spacing between notes
    - Limits on notes per time interval
  - Behavior across modes is now more consistent and predictable

- **Lane assignment**
  - Improved note-to-lane distribution:
    - Prevents duplicate notes on the same lane at the same moment
    - Enforces: one lane — one note per time instant
    - Introduced anti-spam weighting:
      - Time-based penalties
      - Previous note repetition penalties
      - Recent assignment window penalties
  - Better handling of dense sections and simultaneous hits

- **Generation performance**
  - One heavy generation pass + fast lane redistribution instead of multiple requests
  - Reduced server load during mass generation
  - Faster overall note generation workflow

- **UI & interaction**
  - Fixed songs folder dialog behavior:
    - “Remove from metadata” button now properly closes the dialog
  - Improved ConfirmationDialog interaction handling

---

### Notes

- This update focuses on **internal generation architecture and stability**, without major visual changes  
- Generation is now more predictable and resilient to edge cases  
- Improved lane assignment enhances readability and gameplay comfort  
- New visual setting allows fine-tuning note appearance  

## RhythmFall Client v1.1.2

Patch release focused on generation pipeline improvements, server-client architecture, and performance optimization.

---

### New

- **Server-driven generation presets**
  - Generation presets are now centralized on the server
  - Added unified preset system: `minimal`, `basic`, `enhanced`, `natural`, `custom`
  - Server defines generation balance instead of client-side sliders
  - New `preset_id` parameter introduced for cleaner API communication
  - Backward compatibility with `generation_mode` preserved

- **Improved generation workflow**
  - Non-custom modes now ignore manual sliders — behavior is fully defined by presets
  - More predictable and consistent generation results across sessions

- **Notes variants system**
  - Server now returns note variants for **3, 4, and 5 lanes** in a single response
  - Client stores all variants at once (`notes_variants`)
  - Eliminates the need for separate generation requests per lane configuration

---

### Fixes & Improvements

- **Generation performance**
  - Reduced number of HTTP requests during mass generation:
    - 1 request per mode instead of multiple per lane
  - Faster overall generation workflow and response time
  - Reduced server load and network overhead

- **Generation stability & balance**
  - Added density guardrails:
    - Minimum spacing between notes (floor)
    - Caps on notes per second / per bar
  - Prevents extreme note spam or overly empty patterns

- **Audio analysis optimization**
  - Improved stem cache lookup logic
  - Fewer cache misses → less unnecessary heavy audio separation
  - More consistent performance during repeated generations

- **Client-server contract**
  - Cleaner and more predictable communication via `preset_id`
  - Reduced reliance on manual parameter transfer
  - More stable behavior across different generation modes

---

### Notes

- This update focuses on **internal architecture and performance**, without major visual changes  
- Generation is now more consistent and easier to balance centrally on the server  
- Fewer requests and improved caching result in faster and smoother generation workflow  
- The new system lays the foundation for future generation features and improvements  

## RhythmFall Client v1.1.1

Patch release focused on performance optimization, smoother UI responsiveness, and improved uninstall experience.

---

### New

- **Performance optimization — smoother UI and faster loading**
  - Async audio loading with caching (`load_audio_stream_async`) — no UI freeze on first playback
  - Custom hit sounds now load in background — instant response on first use
  - Split SFX preload:
    - Critical sounds — loaded immediately
    - Deferred sounds — loaded gradually over frames

- **Startup warmup improvements**
  - Step-by-step scene warmup instead of heavy one-frame load
  - Lightweight startup warmup for shop textures and active covers
  - Full warmup available as a separate option
  - Reduced CPU/IO/GPU spikes during initial launch

- **Texture loading improvements**
  - Removed blocking fallback (`ResourceLoader.load`) during threaded loading
  - Added per-frame completion limit (`MAX_COMPLETIONS_PER_FRAME`)
  - Prevents frame drops during heavy batch loading

- **Shop & cover gallery optimization**
  - Reduced UI batch creation size (24 → 8)
  - Cover requests are now distributed across frames
  - Smoother first-time opening with lower load spikes

- **SongLibrary — async metadata processing**
  - Removed synchronous duration calculation during library load
  - Background worker for:
    - Track duration
    - ID3 metadata
  - Public async requests:
    - `request_duration_update`
    - `request_id3_update`
  - Library loading no longer blocks on audio decoding

- **Song details — async operations**
  - Track preview uses async audio loading
  - Missing duration (00:00) resolved in background
  - ID3/tag reading moved to background
  - Covers (embedded/sidecar) loaded asynchronously
  - Reduced UI freezes when selecting tracks

- **Graphics quality settings**
  - New option: **Low / Medium / High**
  - Saved in settings and applied instantly at runtime
  - Runtime rendering presets:
    - Low — no MSAA, no AA, minimal filtering
    - Medium — 2x MSAA, moderate filtering
    - High — 8x MSAA, FXAA, higher anisotropy
  - Settings fully integrated into UI (moved from misc tab)

---

### Fixes & Improvements

- **General performance**
  - Removed blocking operations from critical UI paths
  - Async loading for audio, textures, metadata
  - Reduced disk I/O during startup (theme is no longer saved every launch)
  - Improved responsiveness across menus and screens

- **Startup & rendering**
  - Reduced initial load spikes with staged warmup
  - Default rendering settings aligned with medium preset
  - Runtime application of graphics settings is stable

- **Uninstaller — full removal**
  - `Uninstall-RhythmFall.bat` now removes:
    - User data folders:
      - `%APPDATA%\Godot\app_userdata\RhythmFall`
      - `%APPDATA%\RhythmFall`
    - Entire game installation directory
  - Confirmation prompt before deletion (Y/N)
  - Uses background PowerShell to allow self-deletion
  - Fully removes all files — no leftovers

- **Uninstaller — UTF-8 support**
  - Added `chcp 65001` to enable UTF-8 in Windows console
  - Russian text now displays correctly (no encoding issues)

---

### Notes

- This update focuses on **performance and responsiveness**, especially in UI-heavy areas (shop, library, song selection)  
- Async systems significantly reduce freezes and improve overall smoothness  
- Graphics quality can now be adjusted in real time depending on hardware  
- Uninstaller now supports **complete removal of the game and all associated data**  

## RhythmFall Client v1.1.0

Major update focused on generation control, gameplay accuracy, and overall UX improvements.

---

### New

- **Generation system — full control and new modes**
  - Added new modes: **minimal, natural, custom**
  - **Minimal** — simplified generation with reduced density and fewer events
  - **Natural** — generation “as-is” without artificial modifications
  - **Custom** — full manual control over all generation parameters
  - Presets + adjustable parameters (`fill`, `groove`, `density`, `grid`, `accent`, `genre`)
  - Sliders with percentage-based dynamic labels
  - Genre detection and stems options moved to the generation screen (checkboxes)
  - Custom preset is saved and restored between sessions

- **Interactive Knowledge Base (Help Screen)**
  - New help screen with accordion-style categories
  - Sections: server, generation, gameplay, library, progression
  - Technical overview of the pipeline (Demucs, BPM, RNN, etc.)
  - Content fully synchronized with actual project logic

- **Extended generation settings**
  - New `generation_notes_ready_scope` parameter (4 readiness modes)
  - Flexible logic: “all lanes / single lane / all modes”
  - Batch generation for missing modes

- **Improved audio calibration**
  - Increased to 20 taps (was 10)
  - First taps ignored as warm-up
  - Median-based offset calculation (more stable than average)
  - Output latency is now taken into account

- **UI & settings**
  - Volume sliders now display percentages
  - Unified popup font size for all `OptionButton` menus
  - Confirmation dialog when changing songs folder:
    - Metadata cleanup (prune) option
    - Optional notes deletion
  - Scan results dialog showing number of added tracks

---

### Fixes & Improvements

- **Gameplay accuracy & synchronization**
  - `game_time` synchronized with actual audio playback position
  - More precise PERFECT/GOOD hit timing calculation
  - Output latency accounted for in all timing logic
  - Autoplay uses the exact same timing logic as manual play

- **Generation**
  - Generation queue and status updates are now stable
  - Faster note generation (~40–60% improvement due to pipeline optimization)

- **UI/UX**
  - “Play” button now depends only on current mode and lane
  - Track highlighting correctly reflects actual file availability
  - Deferred UI updates after generation (no file visibility issues)
  - Sequential status updates (no skipped steps)
  - Notifications correctly reflect modes and scope

- **Profile & statistics**
  - Total stats now include all hits (PERFECT + GOOD)
  - Metrics are properly separated (PERFECT still used for achievements)

- **Connection stability**
  - Switched from `localhost` to `127.0.0.1` — near-instant local connection
  - Added connection timeout with proper error feedback
  - Fixed delays during “Connecting to server…” stage
  - BPM and generation statuses are now separated (no overlap)

- **Text & clarity**
  - Fixed formulas and labels in reward screens (currency / XP)
  - Descriptions now match actual calculation logic

---

### Notes

- When updating to v1.1.0, data from the old folder is **not migrated automatically** — copy files manually if needed  
- The generation system is now more flexible and fully customizable  
- Gameplay accuracy has been improved — hit detection matches what the player actually hears  
- UI is more consistent and stable, with fewer desync issues and edge-case glitches  

## RhythmFall Client v1.0.2

Patch release focused on data handling fixes and storage structure improvements.

### New

- **Dedicated `RhythmFall` data directory** — the game now stores all data in its own folder:
  - Windows: `%APPDATA%\RhythmFall`
  - Linux: `~/.local/share/RhythmFall`
  - macOS: `~/Library/Application Support/RhythmFall`
  - Benefits: isolation from other Godot projects, transparent location, simplified uninstall

### Fixes

- **Profile reads achievements only from user storage** — fixed desync: profile now uses `user://achievements_data.json`, consistent with the rest of the app
- **Achievements and Shop read data only from `user://`** — removed `res://` fallbacks, all screens use a single source of player data
- **"In the Groove" achievement progress saves in real-time** — perfect hits counter updates in the achievements file on every change, not only upon unlock
- **Removed stray confirmation dialog from Shop scene** — `ResetAllSettingsConfirmDialog` removed from `shop_screen.tscn`; settings reset available only in Misc Tab

### Notes

- **Updated `Uninstall-RhythmFall.bat` script** — now removes both possible data folders:
  - Old path: `%APPDATA%\Godot\app_userdata\RhythmFall`
  - New path: `%APPDATA%\RhythmFall`
  - Script checks for folder existence, requests confirmation, and deletes both if present
- When updating to v1.0.2, data from the old folder is **not migrated automatically** — copy files manually if needed
- After running the uninstall script, the game will create fresh `achievements_data.json`, `shop_data.json`, etc. in the active `user://` folder on next launch
- All progress files (`achievements_data.json`, `player_data.json`, `shop_data.json`, `settings.json`, etc.) now reside in a single, easy-to-find `RhythmFall` folder

## RhythmFall Client v1.0.1

Patch release focused on UI/UX improvements, settings stability, and quality-of-life enhancements.

### New

- **Exit confirmation on Esc** in main menu — dialog prevents accidental game closure
- **Windows uninstall script** (`Uninstall-RhythmFall.bat`)
  - Shows target data path (`%APPDATA%\Godot\app_userdata\RhythmFall`) before deletion
  - Requests confirmation before removing files
  - Deletes only RhythmFall user data, leaving external song folders untouched

### Fixes & Improvements

- **Esc key now works in Shop** — fixed issue where shop screen blocked global Esc handling
- **Calibration UI hints** — displays remaining taps count, current key binding for lane 0, and Esc to exit
- **Audio settings** — updated default values (volume, fullscreen), applied immediately on launch
- **Instant UI refresh** after resetting settings — no need to reopen settings menu
- **Confirmation dialogs** for dangerous actions in settings (reset, delete notes, clear paths)
- **Metadata normalization** — removed trailing whitespace and newlines, fixed track selection lag
- **BPM display** — empty values now show as `N/A` consistently

### Notes

- `Clear all cache` button removed — replaced with `Clear user paths` for targeted cleanup
- Debug console disabled by default in release builds
- Uninstall script: close the game before running; run as Administrator if files are locked
- External song libraries (if moved from the project root) are not affected by the uninstall script

## RhythmFall Client v1.0.0

First stable release of the RhythmFall client.

### Features

- Drum gameplay mode (kick / snare based charting)
- Two chart generation modes:
  - **Basic** — standard drum pattern chart
  - **Enhanced** — increased chart density (+10–15% additional notes)
- Dynamic lane layout supporting **3–5 lanes**
- **20 built-in songs** with pre-generated charts
- Support for generating charts for **custom audio tracks** via the analysis server

### Notes

- Audio analysis and chart generation are handled by **[RhythmFallServer](https://github.com/abletoburntheweb/RhythmFallServer.git)**
- Custom tracks are analyzed on the server and then played locally in the client
