## RhythmFall Client v1.1.10

Patch release focused on UI polish, shop/achievements/main menu visual refresh, help screen redesign, cover gallery rework, Lucide currency/XP icons, grade color system, unified interaction system, achievement synchronization, settings tab theming, and debug autoplay timing.

### New

**Redesigned Help screen**

- Scrollable layout with accordion-style expand/collapse for each item
- Categories as toggle buttons (`FlatMenuSongButton`) that group questions
- Content loaded from `data/help_content.json` (text and color palette)
- Colors externalized — edit the palette without recompiling

**Cover gallery reworked**

- Modal overlay (opacity ~0.71) darkens the shop screen
- Fixed 4-column grid; cells resize from 140px to 350px based on window width
- Numbered badges (1–7), hover effect, click-to-select
- Asynchronous texture loading with placeholder fallback

**Shop visual refresh**

- Screen header and category/filter rows styled like other menu screens, with unlock progress bar
- Item cards: category accent borders, icon frames, active/unlocked glow — styling in `shop_screen.tscn`, `item_card.tscn`, and `item_card.gd` (removed separate `shop_visual_polish.gd`)
- Card pop animation on **Buy**, **Use**, and **Open** only — not on hover
- Item name (22px) and status (20px) font sizes tuned; long names clip cleanly with `clip_text`

**Shop notifications for new reward items**

- Main menu shop button shows a count of unopened reward items (achievements, level milestones, daily quest milestones)
- Purchases with currency are not counted — only items newly unlocked as rewards
- In the shop, unopened reward items get a gold card border and a yellow **Open** button instead of **Use**
- Counter and highlight clear only after **Open** is pressed (same apply sound as **Use**)

**Achievements visual refresh**

- Screen header and filter row match shop/menu styling
- Achievement cards: category accents, icon frames, unlocked glow — styling in `achievements_screen.tscn`, `achievement_card.tscn`, and `achievement_card.gd` (removed separate `achievements_visual_polish.gd`)
- Enlarged card fonts (title, description, progress)

**Main menu refresh**

- Daily quests panel: mint-accent shell, card-style quest rows, themed progress bars
- Completed quests show gold border and progress fill
- Lucide **diamond** icon beside daily quest currency reward (`RewardRow` in scene)
- Shop new-rewards badge (`NewRewardsBadge`) authored in the scene — not created at runtime
- Title color aligned with shop/achievements headers
- Menu panel wrapper kept transparent; main menu buttons keep their embedded theme (`Theme_1ur2m`) for familiar button styling

**Lucide icons (currency & XP)**

- **diamond** (`assets/icons/diamond.svg`) — HUD currency, daily quest rewards, victory currency row
- **gauge** (`assets/icons/gauge.svg`) — HUD level row (icon to the right of the label, same layout as currency), victory XP row (icon to the left of the label)
- Victory `CurrencyRow` / `XPRow` in `victory_screen.tscn`; HUD `LevelRow` / `CurrencyContainer` in `game_engine.tscn`

**Grade display & SS colors**

- Letter grades use consistent colors everywhere (victory, song select, profile) via `grade_display.gd`
- First SS clear on a track shows gold; repeat SS clears on the same track show green
- SS clear count tracked per track permanently — not lost when recent-results history rolls over
- Recent results list stores `ss_repeat` so older entries keep the correct color

**Unified interaction system**

- `UiInteractionApplier` applies cursors and button hover effects across menu UI
- Bridges runtime theme from `GameEngine` (`app_theme.gd`) onto controls that use local or embedded scene themes
- Cursor types:
  - pointer on buttons, `SpinBox`, lists, and other interactive controls
  - `HSIZE` / `VSIZE` on horizontal and vertical sliders
  - I-beam on `LineEdit` and `TextEdit`
- Button hover uses live theme colors (frame / background highlight)
- Applied via `GameEngine`, `BaseScreen`, screen transitions, and explicit calls on dynamic overlays
- Main menu and pause menu call `UiInteractionApplier.apply_from_engine()` on open
- Victory currency/XP labels and shop cover previews use manual hand-cursor setup where needed

### Fixes & Improvements

**UI polish**

- Achievements list no longer clipped (scroll container expands correctly)
- Removed stray tab characters from “Back” button labels across menu screens
- `AchievementCard` script correctly extends `PanelContainer`

**Shop**

- Removed duplicate in-shop currency chip (HUD already shows balance)
- Currency pulse on purchase targets the HUD label only
- **In use** / **Default** status labels display correctly again after layout fixes (removed conflicting `clip_text` / expand flags on status label)

**Settings screen polish**

- Outer margins and consistent navigation header (`FlatBackButton` + title + subtitle)
- Tab bar: each tab keeps its accent `theme_type_variation` (teal / blue / pink / purple); active vs inactive state uses modulate only
- Controls tab uses `FlatExitButton` (pink accent) to match the intended tab color
- Misc tab section panels show colored borders again (root no longer uses a stale embedded theme copy that blocked `SectionPanel*` styles)
- Tab container with active / inactive visual states
- `ContentCard` wrapper (solid background, rounded corners, shadow)
- Setting panels use themed section styles (Teal for Volume, Blue for Display, Mint for Gameplay, etc.)
- Calibration and other action buttons receive hover via `UiInteractionApplier` like the rest of the menu UI

**Theme assets**

- `app_theme.tres` extended with `SectionPanel*` / `SectionHeader*` variants for editor preview
- `tools/enrich_app_theme_tres.py` patches accent button hovers and section styles when Godot rebuild is unavailable

**Main menu & cover gallery adaptive layout**

- Main menu buttons and header anchored to window size (no fixed 1920px width)
- Title and subtitle no longer clipped on narrow screens
- Cover gallery adjusts cell size (140–350px) while keeping 4 columns

**Pause menu**

- Layout unchanged from original; only `UiInteractionApplier` added for pointer cursor and accent hover

**Victory screen**

- Hint label for currency/XP detail view appears only after `_reveal_grade()` (when counters finish)
- No longer overlaps the counting animation
- Currency and XP reward lines are not clickable until the hint appears

**Profile screen**

- Favorite-track cover (including the default shop cover when no track is set) no longer looks blurry or compressed at thumbnail size
- Cover preview uses the same high-quality scaling as song select — proper texture filtering and aspect-fit cropping
- Recent sessions and song details use the same grade colors as victory

**Achievement synchronization**

- Playtime achievements use exact seconds via `get_total_play_time_seconds()`
- `sync_unlocked_achievements_to_player_data()` runs on game start and when opening the shop
- `is_achievement_unlocked()` performs a full unlock when progress is met but the flag was missing
- Shop unlock state and achievement tooltips stay in sync
- Debug achievement unlock command updates player progress from the main menu (shop reward checks work immediately)

**Debug console**

- `player.dailies.complete_all` correctly finishes genre-group quests (e.g. jazz/soul play tasks)

**Debug autoplay timing**

- Autoplay now hits when the note reaches the hit line (chart time + geometry), not on stale pixel crossing
- `update_notes()` runs before autoplay each frame so note positions match audio clocks
- Autoplay passes the target note directly into `check_hit()` — no silent miss when the note is outside the ±50px Y gate
- Hold notes keep the lane pressed for the full hold duration
- Lane highlight timing uses chart time (`get_song_time()`), aligned with visual hits
- Timing debug overlay shows line-average delta during autoplay — visual offset without user timing offset (separate from hit-minus-note average, which still includes offset from settings)
- Console: `game.autoplay` toggles autoplay; `timing.autoplay.windows` uses the same ±50 / ±150 ms windows as manual play

### Notes

- Help content remains fully externalized in `data/help_content.json` — editable without rebuilding
- Cover gallery uses a fixed 4-column layout; cells resize across common resolutions
- Many scenes still assign theme per control (`ExtResource` or embedded `SubResource` copies); `UiInteractionApplier` is required so hover and cursors stay consistent with `app_theme.gd` at runtime
- Main menu buttons keep their embedded theme; other refreshed screens use `app_theme.tres`
- Shop/achievement card styling lives in `.tscn` + screen/card scripts — edit there to adjust look
- Time-based achievement rewards unlock reliably even when progress and unlock flags were previously out of sync
- Autoplay is a debug/testing tool (console); with a negative timing offset in settings, hit-minus-note average will reflect that offset even when hits look correct on the line — use the line-average overlay metric to verify visual rhythm
