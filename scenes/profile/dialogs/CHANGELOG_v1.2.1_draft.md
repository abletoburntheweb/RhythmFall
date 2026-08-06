# RhythmFall Client v1.2.1 — draft

Что не вошло в **v1.2.0** / уже начато в коде. Корневой [`CHANGELOG.md`](../CHANGELOG.md) — хронология релизов (EN).

Русская версия ниже. English — further down.

---

## RhythmFall Client v1.2.1 (draft)

Патч: алиасы ключей Rhythm Rating / режимов чарта, «Сыграть снова», установка Windows-сервера, мелкие UI-фиксы справки и достижений, fidelity интро ударных.

### Исправления и улучшения

**Rhythm Rating / ключи чарта**

- `normalize_mode` приводит старые ярлыки (`basic`, `enhanced`, …) к текущему stem (`arcade_standard`, `arcade_dense`, `original`, …) через `GenerationIntents`
- Расширены алиасы инструментов (`ударные`, RU-имена баса, `full mix`) — RU/EN сходятся в один RR-бакет
- Не начисляется второй RR при реплее того же чарта под старым именем режима (например Play again → `basic`, а забег был `arcade_dense`)

**Победа / реплей**

- В результатах сохраняется канонический mode, не сырая legacy-строка
- **Сыграть снова** резолвит mode до перезапуска — следующий забег грузит тот же stem
- GameScreen держит `current_generation_mode` на resolved stem (меньше дрейфа RR/replay)
- Новая строка: `VICTORY_RR_NEW_CHART_FMT` — «RR +N (новый чарт)» при первом бакете

**UI достижений**

- Чипы категории «Показать все» больше не вызывают `release_focus` / pulse до `add_child` (спам `!is_inside_tree()` при rebuild обзора)

**Справка → Настройки**

- Добавлен `HELP_LINK_SETTINGS_CONTROLS` (статья Guitar Hero без сырого ключа)
- Deeplink’и из контекстной справки закрывают оверлей помощи и открывают/фокусируют нужную вкладку Настроек (справка больше не путается с экраном настроек)

**GPU-стек (Настройки → Генерация)**

- В блоке сервера: сегменты Авто / NVIDIA / AMD / CPU; ниже ряд **Сканировать** | **Применить**
- Скан сохраняется в настройках (адаптер / рекомендация / установленное) — без повторного «давай поставим» при каждом заходе
- Авто + уже стоящий рекомендуемый стек → уведомление «уже установлен», без диалога скачивания
- Перед установкой: детект → план; при NVIDIA на AMD (и наоборот) — предупреждение, можно продолжить
- `/health` отдаёт `gpu` (stems / ADTOF); статус «Сейчас: …» в настройках
- Режим LAN: смена стека недоступна (настраивается на хосте)

**Очередь генерации / магазин / профиль**

- Прогресс-бар в очереди снова обновляется для 2-й и следующих песен (row id с путём больше не ломает `NodePath`)
- Из магазина окончательно убраны обложки (`covers_*` / «Волнистый градиент») — не всплывают из старого `user://shop_data.json`; при открытии магазина очистка пишется на диск
- RR Топ-10: одна строка на песню×режим×lanes (разные модификаторы больше не дублируют трек)
- В RR Топ-10 режим показывается переводом («Аркада · Средняя»), а не кодом `arcade_standard`
- Готовность чартов: ряд «Сложности (Аркада)» скрывается, если в целях выбран только Оригинал
- Запуск: boot splash без картинки Godot (`show_image=false`); без LoadingOverlay; FPS/уровень/версия скрыты до конца интро (интро стартует до тяжёлого theme build)
- «Сгенерировать ноты»: диалог «уже есть» показывает готовность чартов, не кнопку «Стиль чарта» (П А Т)
- Offline-баннер: «Отменить» снимает задачу и останавливает авто-ретрай (не ждёт запуска сервера)
- Stage ledger: не падает на numpy `beats` (`truth value of an array is ambiguous`)
- Экспорт Recap: заполняется полоса опыта на странице обзора (`#` у accent в HTML)
- Моды: Half HP старт только 25–50% (нельзя 100% с бонусом); Strict окно ≤100%, Easy ≥100%; Heat max scroll ≥110%; Hidden/Sudden band ≤220px
- Моды Heat/Rush: «Сохранять высоту тона» disabled, пока выкл. «Менять скорость песни»
- Song Select → Плейлисты: убран двойной UI-звук (остался один в `transitions`)
- Пауза → отмотка 3 с: ноты реально откатываются за 3 с (не телепорт + оверлей 1.5 с); без softlock если rewind не стартовал; оверлей ждётся корректно
- Стиль чарта: повторный клик по уже выбранной цели (Оригинал/Аркада) больше не снимает подсветку и не закрывает окно — подтверждение только Enter / «Подтвердить»
- Бесконечная сессия → сводка: убрано дублирование «Вся библиотека» (избранное только при включении; жанры — «Все жанры»)

**Генерация ударных (интро / cluster)**

- `detect_drum_section_start` — первый реальный удар в плотном окне (не пустой край сетки)
- Entry recovery подтягивает редкие kick/snare до плотной секции (`drum_entry_preamble_sec` / `preamble_max`) — убирает многосекундные дыры в интро (напр. TTFAF) без выдуманных хэтов
- Stage ledger + `diagnose_layers`: на TTFAF Original дыры оказались **P2 / cluster** (не ADTOF)
- Cluster/flam: BPM-cap чуть ниже 16-й доли — blast-потоки больше не схлопываются в одну цепочку; Original policy чуть мягче (`hit_cluster_window` / `flam_merge`)
- Original|standard difficulty: **documentary passthrough** (раньше Arcade ghost-strip обнулял texture-такты на TTFAF outro); Arcade|standard по-прежнему thin/ratio
- Original: `critic_intro_no_add` выкл; matcher (Arcade) не режет preamble/ADTOF после snap; `section_sparse_keep_all_max=3` не обнуляет/не прореживает уже редкие sparse_block такты
- QA: `scripts/ab_drum_intro.py`, `scripts/diagnose_layers.py`, `scripts/test_cluster_sixteenth_cap.py`, `scripts/test_style_difficulty.py`, `scripts/test_critic_intro_section.py`
- Arcade Medium: **sparse restraint** — groove/loop/backbeat не достраивают такты с ≤2 нотами из плотных соседей (тихие одиночные удары остаются одиночными)
- Arcade lane router: **фразовые раскладки** каждые 4 такта (mirror/rotate) + чуть шире зоны — 4-я линия живёт, kick не залипает в L1 на весь трек; `scripts/test_arcade_sparse_lanes.py`
- **Календарь активности:** день и серия после забега (clear/fail); снимок дня (tracks / Clear / Fail / время / grade / best score / max combo) на 120 дней; модалка из хайлайта «Серия дней» в профиле; boot больше не накручивает streak; модалка крупнее, клетки дат квадратные, левая/правая панели одной высоты
- **Как построить чарт → параметры готовности:** шестерёнка открывает компактную модалку осей готовности (синхрон с Настройки → Генерация), не полный Settings; Esc / Назад закрывают модалку; без `radial_glow` поверх dim
- Модалки / оверлеи: единый `FlatBackButton`; справка поверх UI — плотнее dim, чтобы Назад не сливался
- Нейтральный копирайт в части хинтов настроек / калибровки / session setup (меньше «тапайте / нажмите»)

**Установка Windows-воркера**

- `install_windows_server.ps1` ставит из `requirements.txt` (Windows-стек); на стороне сервера убран сплит `requirements-windows.txt` / `requirements-linux.txt`

### Заметки / ещё открыто (не обещано в 1.2.1)

- Тайминг баса vs DAW-сетка / фаза стема — отложено (`docs/bass_stem_sync_issues.md`)
- Длинный бэклог (очередь после рестарта, Windows toast фоновой ген., маршруты Marathon из плейлиста, Loop Awareness) — вне скоупа

---

## English (same entry)

Patch release focused on Rhythm Rating chart-key aliases, Play again / replay mode resolution, and Windows server install path cleanup.

### Fixes & Improvements

**Rhythm Rating / chart keys**

- `normalize_mode` maps legacy mode labels to canonical chart stems via `GenerationIntents`
- Broader instrument aliases so RU/EN names share one RR bucket
- Fixes double RR when “Play again” relaunches under a legacy mode string for the same chart

**Victory / replay**

- Results persistence and **Play again** use the canonical mode
- GameScreen stores the resolved stem for the run
- `VICTORY_RR_NEW_CHART_FMT` for first RR on a chart bucket

**Achievements UI**

- Overview “Show all” chips: no `release_focus` / pulse before `add_child` (`!is_inside_tree()` spam)

**Help → Settings links**

- Controls link string + contextual help deeplinks open the correct Settings page

**GPU stack (Settings → Generation)**

- Segmented Auto / NVIDIA / AMD / CPU; Scan + Apply on the row below
- Scan result persisted; Auto skips install when the recommended stack is already present
- Pre-flight GPU detect + mismatch warning; LoadingOverlay while installing
- `/health` includes `gpu` status for the settings readout

**Queue / shop / profile**

- Generation queue progress bar updates for jobs after the first (safe row node names)
- Cover packs (`covers_*` / wavy gradient) purged from stale `user://shop_data.json` (persisted on shop open)
- RR Top-10 collapses to one row per song×mode×lanes (modifiers no longer duplicate the track)
- RR Top-10 shows localized mode («Arcade · Medium»), not raw `arcade_standard`
- Chart readiness: hide Arcade difficulties row when only Original is selected
- Boot: no Godot splash / boot LoadingOverlay; hide FPS/XP chrome until intro → menu; intro starts before theme build
- Generate notes confirm cites Chart readiness, not the Chart style button
- Offline banner Cancel abandons the wait (no auto-retry after server starts)
- Stage ledger: no crash on numpy `beats` truth-value
- Recap export: XP progress fill on overview page (accent CSS hex)
- Modifiers: Half HP start capped 25–50%; Strict windows ≤100%, Easy ≥100%; Heat max scroll ≥110%; Hidden/Sudden band ≤220px
- Heat/Rush: pitch toggle disabled until «Change song speed too» is on
- Song Select → Playlists: no duplicate UI click sound
- Pause resume rewind: chart lerps back over 3s (was teleport + 1.5s overlay); softlock/await fixes
- Chart style: re-clicking the active goal (Original/Arcade) no longer clears the highlight or closes the dialog — confirm via Enter / Confirm only
- Endless session summary: drop duplicate «All library» wording (favorites row only when on; genre policy → «All genres»)

**Drum generation (intro / cluster)**

- Section start uses first real hit in the dense window; preamble kick/snare recovery before dense groove
- Stage ledger showed TTFAF Original holes as **P2 / cluster**, not ADTOF miss
- Cluster/flam BPM cap below a 16th so blast streams no longer chain-merge; softer Original policy windows
- Original|standard difficulty is documentary passthrough (was wrongly applying Arcade ghost-strip); Arcade|standard still thins
- Original disables intro strip; section sparse blocks keep already-sparse measures; Arcade intro matcher tolerates snap
- `scripts/ab_drum_intro.py`, `diagnose_layers.py`, `test_cluster_sixteenth_cap.py`, `test_style_difficulty.py`, `test_critic_intro_section.py`, `test_arcade_sparse_lanes.py`
- Arcade Medium sparse restraint (no densify of ≤2-note bars from dense neighbors / metal backbeat)
- Arcade phrase lane router: mirror/rotate every 4 bars so 4K layouts vary and lane 4 gets use
- Activity calendar: day/streak after a run (clear/fail); 120-day snapshots (tracks / Clear / Fail / time / grade / best score / max combo); modal from Day streak highlight in Profile; boot no longer advances streak; larger modal, square day cells, equal-height panels
- Chart builder gear → compact chart-readiness modal (synced with Settings → Generation), not full Settings; GlowLayer/`radial_glow` hidden while open
- Modal overlays: shared FlatBackButton; denser help dim so Back stays readable
- Neutral copy pass on selected settings / calibration / session hints

**Windows worker install**

- Install script uses single `requirements.txt`

### Notes / still open

- Bass stem / grid-phase timing — deferred
- Queue persist, OS toast, Marathon playlist routes, Loop Awareness — backlog only
