# scenes/help/help_screen.gd
extends BaseScreen

const HC := {
	"primary": "6b91d1",
	"accent": "6b91d1",
	"teal": "61c7bd",
	"play": "61c7bd",
	"sky": "84c2eb",
	"pink": "db84b8",
	"mint": "9edbb7",
	"purple": "a894db",
	"slate": "ccdbf0",
	"danger": "d94d57",
	"muted": "ebf0fa",
	"perfect": "ffff00",
	"good": "00ffff",
	"skin": "84c2eb",
	"kick": "61c7bd",
	"cover": "db84b8",
	"lines": "9edbb7",
	"cat_ach": "faa34c",
	"cat_lvl": "a894db",
	"cat_daily": "ccdbf0",
}

const SECTION_SERVER := "Сервер и анализ аудио"
const SECTION_GENERATION := "Генерация нот"
const SECTION_GAMEPLAY := "Геймплей и настройки"
const SECTION_LIBRARY := "Библиотека треков"
const SECTION_PROGRESS := "Прогресс и магазин"

@onready var help_list: VBoxContainer = $ContentContainer/HelpScroll/ScrollBottomMargin/HelpList
@onready var back_button = $MainVBox/BackButton

var help_card_template: HelpCard


func _ready():
	_reparent_help_template_out_of_list()
	help_card_template = $HelpCard as HelpCard
	assert(help_card_template != null, "Нужен узел HelpCard на корне HelpScreen (скрипт help_card.gd).")
	_setup_help_items()


func _reparent_help_template_out_of_list() -> void:
	var hl: Node = help_list
	for i in range(hl.get_child_count() - 1, -1, -1):
		var c: Node = hl.get_child(i)
		if c is HelpCard:
			hl.remove_child(c)
			add_child(c)
			c.visible = false
			c.name = "HelpCard"
			break


func _execute_close_transition() -> void:
	if transitions:
		transitions.open_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _setup_help_items() -> void:
	var rows: Array = _build_help_rows()
	var current_section: String = ""
	var section_inner: VBoxContainer = null
	for row in rows:
		var sec: String = row["section"]
		if sec != current_section:
			current_section = sec
			section_inner = _add_help_category(sec)
		_create_help_item_in(section_inner, row["title"], row["content"])


func _build_help_rows() -> Array:
	return [
		{"section": SECTION_SERVER, "title": "Как работает архитектура сервера?", "content": "RhythmFall использует клиент-серверную архитектуру. Локальный сервер на Python (Flask) отвечает за тяжёлые вычисления: [color=#%s]определение BPM[/color], [color=#%s]разделение стемов[/color] и [color=#%s]генерацию паттерна нот[/color]. Клиент Godot отвечает за интерфейс, отрисовку и обработку ввода в реальном времени." % [HC.primary, HC.teal, HC.sky]},
		{"section": SECTION_SERVER, "title": "Технологический пайплайн анализа", "content": "Обработка трека идёт по цепочке:\n1. [color=#%s]Stem Separation[/color]: модель Demucs отделяет ударные от микса.\n2. [color=#%s]Tempo Analysis[/color]: TempoCNN оценивает BPM.\n3. [color=#%s]Beat Tracking[/color]: сеть строит тактовую сетку.\n4. [color=#%s]Genre ID[/color]: Discogs400 подсказывает жанр для правил генерации.\n5. [color=#%s]Synthesis[/color]: сборка нот с квантованием и назначением по линиям." % [HC.primary, HC.teal, HC.sky, HC.purple, HC.mint]},
		{"section": SECTION_SERVER, "title": "Нужен ли локальный сервер для BPM и генерации?", "content": "Да. И [color=#%s]определение BPM[/color], и [color=#%s]генерация нот[/color] выполняются локальным сервером (Python, Flask). Запускайте его из поставки [color=#%s]RhythmFallServer[/color]. Клиент по умолчанию подключается к [color=#%s]localhost:5000[/color] — порт должен совпадать с запущенным сервером. Без работающего процесса анализ и генерация не завершатся." % [HC.teal, HC.primary, HC.muted, HC.teal]},
		{"section": SECTION_SERVER, "title": "Что такое «стемы» в настройках генерации?", "content": "[color=#%s]Стемы[/color] — это разделение полного микса на дорожки (например, только ударные). Если включено [color=#%s]«Разделение на стемы»[/color], генерация ориентируется на изолированный барабанный трек, что для ритма обычно точнее, чем анализ всего микса целиком." % [HC.sky, HC.teal]},

		{"section": SECTION_GENERATION, "title": "В чём различие между режимами генерации?", "content": "В окне параметров генерации задаются пресеты (их можно уточнить в [color=#%s]«Расширенных настройках»[/color]):\n· [color=#%s]Минимал[/color]: мало заполнения, умеренная живость и плотность, сильнее привязка к сетке — сухой, читаемый паттерн.\n· [color=#%s]Базовый[/color]: сбалансированные значения по умолчанию.\n· [color=#%s]Усложнённый[/color]: больше нот и «живости», выше плотность, слабее жёсткая сетка — насыщеннее рисунок.\n· [color=#%s]Натуральный[/color]: слабее принудительная сетка и жанровый шаблон — ближе к естественному ритму дорожки.\n· [color=#%s]Пользовательский[/color]: слайдеры и чекбоксы вручную; удобно, когда нужен точный контроль." % [HC.primary, HC.mint, HC.primary, HC.pink, HC.sky, HC.purple]},
		{"section": SECTION_GENERATION, "title": "Что такое «Расширенные настройки» генерации?", "content": "Это [color=#%s]раскрывающийся блок[/color] в окне параметров генерации (кнопка с префиксом [color=#%s]>[/color] или [color=#%s]v[/color]): внутри — слайдеры и чекбоксы, задающие, как сервер строит паттерн. Значения сохраняются в настройках. Режим [color=#%s]Пользовательский[/color] использует именно эти поля, как вы их выставили." % [HC.primary, HC.play, HC.play, HC.purple]},
		{"section": SECTION_GENERATION, "title": "Как работают «Расширенные настройки» генерации?", "content": "Параметры уходят на сервер и влияют на правила сборки паттерна:\n1. [color=#%s]Заполнение[/color]: насколько плотно ноты заполняют сетку (больше — насыщеннее паттерн).\n2. [color=#%s]Живость[/color]: вариативность рисунка и отход от «сухой» сетки.\n3. [color=#%s]Плотность[/color]: общая ожидаемая плотность нот (учитывается в лимитах на сервере).\n4. [color=#%s]Привязка к сетке[/color]: сила квантования к сетке BPM — выше, тем ровнее ритм.\n5. [color=#%s]Сила жанрового шаблона[/color]: насколько сильно учитываются жанровые правила при генерации.\n6. [color=#%s]Акцент сильной доли[/color]: усиление долей, совпадающих с сильной долей такта.\n7. [color=#%s]Определение жанров[/color]: включать ли анализ жанра для выбора правил (если выключено, пайплайн может упроститься).\n8. [color=#%s]Разделение на стемы[/color]: использовать ли отдельную дорожку ударных (Demucs) вместо полного микса — обычно точнее для ритма." % [HC.teal, HC.sky, HC.mint, HC.purple, HC.pink, HC.primary, HC.slate, HC.kick]},
		{"section": SECTION_GENERATION, "title": "Сохраняются ли «Расширенные настройки» генерации?", "content": "Да. [color=#%s]Слайдеры и чекбоксы[/color] записываются в настройки и восстанавливаются при следующем открытии окна генерации. Сохраняются также последний выбранный режим, инструмент и число линий (если вы их меняли)." % HC.primary},

		{"section": SECTION_GAMEPLAY, "title": "Как начать играть?", "content": "Обычный порядок:\n1. [color=#%s]BPM[/color]: если темп неизвестен, сначала вычислите его.\n2. [color=#%s]Параметры генерации[/color]: выберите инструмент, один из режимов ([color=#%s]Минимал[/color] … [color=#%s]Пользовательский[/color]) и число линий (3–5).\n3. [color=#%s]Играть[/color]: после успешной генерации нот запустите уровень." % [HC.teal, HC.primary, HC.mint, HC.purple, HC.play]},
		{"section": SECTION_GAMEPLAY, "title": "Влияет ли BPM на скорость падения нот?", "content": "Прямого влияния нет — скорость падения задается настройкой [color=#%s]'Скорость прокрутки'[/color]. Однако высокий BPM делает ритмическую сетку плотнее, из-за чего геймплей ощущается быстрее и интенсивнее." % HC.primary},
		{"section": SECTION_GAMEPLAY, "title": "Как настроить скорость и задержку?", "content": "Если ноты летят слишком быстро или медленно, измените [color=#%s]Скорость прокрутки[/color] в настройках графики. Если вы не попадаете в ритм из-за задержки звука, используйте [color=#%s]Калибровку оффсета[/color] в настройках звука." % [HC.primary, HC.teal]},
		{"section": SECTION_GAMEPLAY, "title": "Как рассчитываются очки и комбо?", "content": "Очки начисляются за каждое попадание в зависимости от точности: [color=#%s]PERFECT[/color] или [color=#%s]GOOD[/color]. Комбо увеличивает ваш множитель очков каждые 10 успешных нажатий (до x4.0). Любое несвоевременное нажатие или пропуск ноты (MISS) полностью сбрасывают серию комбо." % [HC.perfect, HC.good]},

		{"section": SECTION_LIBRARY, "title": "Как пользоваться режимом редактирования?", "content": "В списке песен нажмите [color=#%s]«Редактировать»[/color], чтобы включить режим (кнопка покажет [color=#%s]«Редактировать (ВКЛ)»[/color]). Пока он активен, [color=#%s]двойной щелчок[/color] по названию, исполнителю, году, BPM, основному жанру или обложке открывает правку. Изменения записываются в метаданные трека в библиотеке." % [HC.primary, HC.teal, HC.sky]},
		{"section": SECTION_LIBRARY, "title": "Как добавить свою музыку?", "content": "Вы можете добавить любые MP3, OGG или WAV файлы в папку с песнями. Путь к этой папке можно изменить в настройках [color=#%s]'Прочее'[/color]. После добавления файлов нажмите кнопку [color=#%s]'Сканировать'[/color] в том же меню, и новые треки появятся в библиотеке." % [HC.slate, HC.primary]},

		{"section": SECTION_PROGRESS, "title": "Что дают уровни и опыт (XP)?", "content": "За каждое прохождение вы получаете [color=#%s]опыт[/color]. Повышение уровня профиля открывает доступ к новым предметам в магазине ([color=#%s]скины нот[/color], [color=#%s]звуки кика[/color], [color=#%s]обложки[/color], [color=#%s]подсветка линий[/color]). Максимальный уровень в игре — 100." % [HC.purple, HC.skin, HC.kick, HC.cover, HC.lines]},
		{"section": SECTION_PROGRESS, "title": "Зачем нужна внутриигровая валюта?", "content": "Валюта зарабатывается за прохождение песен и выполнение ежедневных заданий. Её можно потратить в [color=#%s]Магазине[/color] на покупку новых [color=#%s]скинов для нот[/color], [color=#%s]обложек[/color], [color=#%s]подсветки линий[/color] или альтернативных звуков [color=#%s]кика[/color], которые будут звучать при успешном попадании." % [HC.primary, HC.skin, HC.cover, HC.lines, HC.kick]},
		{"section": SECTION_PROGRESS, "title": "В чём смысл предметов из магазина?", "content": "Предметы не повышают сложность и не дают бонуса к очкам — это косметика и звук удара.\nЧто делает каждая категория:\n1. [color=#%s]Скины нот[/color]: меняют внешний вид нот на линиях.\n2. [color=#%s]Звуки кика[/color]: задают звук при успешном попадании по ноте.\n3. [color=#%s]Обложки[/color]: если у трека в метаданных нет своей картинки, показывается выбранный вами пак обложек из магазина.\n4. [color=#%s]Подсветка линий[/color]: меняет оформление подсветки дорожек." % [HC.skin, HC.kick, HC.cover, HC.lines]},
		{"section": SECTION_PROGRESS, "title": "Как получают предметы в магазине?", "content": "Один и тот же предмет может открываться по-разному — по условию получения:\n1. [color=#%s]За валюту[/color]: покупка за валюту, заработанную в игре.\n2. [color=#%s]За достижения[/color]: бесплатно при выполнении условия достижения.\n3. [color=#%s]За уровень[/color]: доступ при достижении нужного уровня профиля.\n4. [color=#%s]За ежедневные задания[/color]: выдаётся за накопленное число завершённых ежедневных квестов." % [HC.mint, HC.cat_ach, HC.cat_lvl, HC.cat_daily]},
		{"section": SECTION_PROGRESS, "title": "Как работают ежедневные задания?", "content": "Каждый день вам предлагается [color=#%s]3 случайных задания[/color] (например, набрать определенное комбо или сыграть несколько песен). За выполнение каждого задания вы мгновенно получаете [color=#%s]бонусную валюту[/color]. Прогресс заданий отображается в главном меню." % [HC.sky, HC.teal]},
		{"section": SECTION_PROGRESS, "title": "Как работают достижения?", "content": "В игре более 80 достижений: от [color=#%s]простых[/color] (сыграть первую песню) до [color=#%s]более сложных[/color] (пройти 10 уровней на 100% точности). Некоторые достижения также открывают эксклюзивные предметы в магазине, которые нельзя купить за валюту." % [HC.primary, HC.purple]},
	]


func _add_help_category(section_title: String) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_list.add_child(wrap)

	var header := Button.new()
	header.toggle_mode = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.custom_minimum_size.y = 72
	header.add_theme_font_size_override("font_size", 30)
	header.text = "> " + section_title

	var inner := VBoxContainer.new()
	inner.visible = false
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title_ref := section_title
	header.toggled.connect(func(pressed: bool):
		inner.visible = pressed
		header.text = ("v " if pressed else "> ") + title_ref
		if pressed:
			header.modulate = Color(0.42, 0.57, 0.82)
		else:
			header.modulate = Color.WHITE
	)

	wrap.add_child(header)
	wrap.add_child(inner)
	return inner


func _create_help_item_in(container: Node, title: String, content: String) -> void:
	var row: HelpCard = help_card_template.duplicate() as HelpCard
	row.visible = true
	container.add_child(row)
	row.setup(title, content)
