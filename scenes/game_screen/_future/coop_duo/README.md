# Локальный co-op (2 игрока) — черновик спецификации

**Статус:** не в сборке. Код split-screen сохранён в `game_screen_coop_duo.gd` как отправная точка.

**Решение по дизайну:** co-op — **отдельный режим / сцена**, не модификатор рана. Модификаторы Wide Lanes и Duo из списка run modifiers **убраны**. Solo-ран остаётся как сейчас (18 модов).

---

## Зачем отдельный режим

| Solo + модификатор | Отдельный co-op |
|--------------------|-----------------|
| Один набор косметики | У каждого игрока свой kick, notes, lane highlight, particles |
| Один счёт / HP | Раздельные score, combo, HP, accuracy, error meter |
| Alt-раскладка = «подсказка» в solo | Alt-раскладка = **управление игрока 2** |
| Нельзя выбрать инструмент P2 | P1 и P2 могут играть разными инструментами |

Принцип разделения чарта — как osu! co-op: карта на все lane, каждый playfield получает **свою половину колонок** (без дублирования нот). Утилиты: `logic/utils/duo_mode.gd` (`split_index`, `queue_for_player`, remap lane для отображения).

---

## Вход в режим (TODO)

Предлагаемый flow:

1. Главное меню или song select → кнопка **«Co-op»** / **«На двоих»**.
2. Выбор трека (как в solo).
3. Экран лобби (опционально): P1/P2 инструмент, превью раскладок, подтверждение.
4. Загрузка `game_screen.tscn` с флагом сессии `coop_session = true` **или** отдельная сцена `game_screen_coop.tscn`.
5. Runtime: `GameScreenCoopDuo` (`session_active = true`) вместо обычного solo runtime.

Модификаторы рана: либо **общие для обоих** (выбор на экране перед co-op), либо co-op без модов на v1 — решить при интеграции.

**Несовместимо с co-op:** Single Lane, Dynamic Lanes, Reverse Scroll, Chart A/B compare (как в archived `can_start()`).

---

## Управление

### Игрок 1 (левое поле)

- Раскладка: **`ControlsBindings.LAYOUT_PRIMARY`**
- Настройки: `SettingsManager.controls_keymap` (lane_0…lane_4)
- Дефолт: `A S D F G`

### Игрок 2 (правое поле)

- Раскладка: **`ControlsBindings.LAYOUT_ALT`**
- Настройки: `SettingsManager.controls_keymap_alt`
- Дефолт: `J K L ; '`

### Где настраивать

**Настройки → Управление:**

| Поле | Ключ в settings |
|------|-----------------|
| Режим раскладки | `controls_layout_mode` — для solo: primary / alt / both; **в co-op игнорировать**, всегда P1=primary, P2=alt |
| Основная раскладка | `controls_keymap` |
| Альтернативная | `controls_keymap_alt` |
| Mediator Up/Down | отдельные scancode для primary и alt (`SettingsManager.build_layout_lane_keymap`, `get_active_mediator_*`) |

В co-op **не показывать** alt-раскладку как «partner hint» в solo — только в сессии co-op.

### Код (archived)

```gdscript
# P1
SettingsManager.build_layout_lane_keymap(ControlsBindings.LAYOUT_PRIMARY, play_lanes)

# P2
SettingsManager.build_layout_lane_keymap(ControlsBindings.LAYOUT_ALT, play_lanes)
```

Pick Mode / Mediator: для каждого `Player` свой keymap и свой `ScoreManager`.

---

## Playfield и HUD

| | P1 | P2 |
|---|----|----|
| Playfield | `Playfield` (слева ~25% центра) | `DuoPartnerPlayfield` (runtime, справа ~75%) |
| Lanes на экране | `SettingsManager.get_play_lanes()` (3–5) | те же `play_lanes` |
| Ноты из чарта | lane `0 … split−1` | lane `split … chart_lanes−1` |
| Score / combo / HP / accuracy / error | свой `ScoreManager` + `RunHealth` | свой набор |
| Judgement | label над своим playfield | label над своим playfield |
| Autoplay | отдельный флаг на сторону (dev) | то же |

Split по ширине: константы `DUO_LEFT_CENTER = 0.25`, `DUO_RIGHT_CENTER = 0.75` в `game_screen_coop_duo.gd`.

---

## Косметика в игре

Каждый игрок использует **свой** `active_items`, не общий профиль.

| Категория | P1 | P2 |
|-----------|----|----|
| Kick / hit sounds | `active_items` | `active_items_p2` (см. ниже) |
| Notes | да | да |
| Lane highlight | да | да |
| Hit particles | да | да |
| Background | общий на сессию **или** split-тема — TBD |

В archived коде P2-ноты дополнительно стилизуются через `DuoMode.apply_note_color()` и настройку `duo_partner_note_style` (warm_cool / tint / outline / none). После per-player skins настройка может стать **fallback**, если у P2 нет своего Notes в магазине.

---

## Магазин: переключение на игрока 2

Сейчас один профиль: `PlayerDataManager.data["active_items"]` и `get_active_item(category)`.

### Рекомендуемая схема (один save-файл)

Расширить `user://player_data.json`:

```json
{
  "active_items": { "Kick": "kick_default", "Notes": "notes_default", ... },
  "coop_player_2": {
    "active_items": { "Kick": "kick_default", "Notes": "notes_blue", ... }
  }
}
```

**Валюта и unlock:** на v1 — **общие** (`unlocked_item_ids`, `currency`). Покупка в магазине открывает предмет для обоих; экипировка — отдельно.

### API (TODO в `player_data_manager.gd`)

```gdscript
const COOP_P2_KEY := "coop_player_2"

func get_active_item(category: String, player_idx: int = 1) -> String:
    if player_idx == 2:
        var p2 = data.get(COOP_P2_KEY, {})
        var items = p2.get("active_items", DEFAULT_ACTIVE_ITEMS)
        return str(items.get(category, DEFAULT_ACTIVE_ITEMS.get(category, "")))
    return # текущая логика P1

func set_active_item(category: String, item_id: String, player_idx: int = 1) -> void:
    # P1 → data["active_items"]; P2 → data["coop_player_2"]["active_items"]
```

Миграция при загрузке: если `coop_player_2` нет — скопировать `DEFAULT_ACTIVE_ITEMS`.

### UI магазина

1. Переключатель **«Игрок 1 / Игрок 2»** (только виден вне solo-рана или всегда в shop — на усмотрение UX).
2. Состояние экрана: `shop_context_player: int = 1`.
3. Preview / Equip / Buy вызывают `get_active_item` / `set_active_item` с текущим `shop_context_player`.
4. Карточки «активно» смотрят на active_items выбранного игрока.
5. i18n: `SHOP_PLAYER_1`, `SHOP_PLAYER_2`, `SHOP_EDITING_PLAYER_N`.

Альтернатива (хуже): второй файл `user://player_2_data.json` — больше дублирования логики save/load.

---

## Сохранение прогресса co-op

| Данные | Где хранить | Примечание |
|--------|-------------|------------|
| Экипировка P2 | `coop_player_2.active_items` | см. выше |
| Clear / stats co-op | опционально `coop_player_2.stats` или общие `levels_completed` | TBD: считать ли co-op clear отдельной ачивкой |
| Рекорды трека | `track_stats.json` с ключом `coop` или суффикс `_coop` | если нужен отдельный leaderboard |
| Настройки управления P2 | уже в `settings.cfg` → `controls_keymap_alt` | не в player_data |

Achievements: категория «Co-op clear» — отдельно от modifier clears.

---

## Интеграция в `game_screen.gd` (чеклист)

- [ ] Флаг сессии `coop_session` при переходе из song select / lobby.
- [ ] Preload / child `GameScreenCoopDuo`, `session_active = true` при старте.
- [ ] `_prepare_run_assets()`: split queue через `DuoMode`, не `prune_non_play_lanes` для второй половины.
- [ ] Два `Player`, два input path; autoplay — оба если включён dev-режим.
- [ ] `_apply_run_cosmetics()`: P1 из `get_active_item(_, 1)`, P2 из `get_active_item(_, 2)`.
- [ ] Defeat / victory: агрегировать оба HP или fail если **любой** на 0 — зафиксировать в дизайне.
- [ ] Pause / Esc: один overlay на весь экран.
- [ ] Countdown: **оба** playfield видны на 5-4-3-2-1.

---

## Файлы

| Файл | Назначение |
|------|------------|
| `game_screen_coop_duo.gd` | Split playfield, partner Player/NoteManager/HUD (archived) |
| `logic/utils/duo_mode.gd` | Split chart, lane remap, partner note tint |
| `logic/utils/controls_bindings.gd` | LAYOUT_PRIMARY / LAYOUT_ALT |
| `logic/core/settings_manager.gd` | keymap primary + alt |
| `logic/data/player_data_manager.gd` | active_items (расширить для P2) |
| `scenes/settings_menu/tabs/controls_tab.gd` | UI раскладок |

---

## Что уже есть в archived runtime

- Split playfield 46% + 46%, partner lanes/hit zone/notes container.
- Отдельные score, HP bar, error meter, combo, stats для P2.
- Partner autoplay lane mapping.
- Lane highlight для P2.

## Что доделать

- Entry flow (меню / lobby).
- `coop_player_2` в save + shop toggle.
- Per-player kick / notes / particles из магазина (не только tint).
- Countdown с двумя полями.
- Геймпад P2 (опционально, v2).
- Тесты конфликтов с модификаторами, если co-op + mods разрешены.

---

## История

- **Duo as run modifier** — прототип, затем archived.
- **Wide Lanes** — рассмотрен и **отклонён** (solo all-lanes не shipping).
- **Co-op** — целевой путь: отдельный режим с полноценным P2 профилем.
