extends Node2D

const DistrictWorldScript = preload("res://scripts/world/district_world.gd")
const EconomyServiceScript = preload("res://scripts/systems/economy_service.gd")
const SaveServiceScript = preload("res://scripts/systems/save_service.gd")
const ConstructionServiceScript = preload("res://scripts/systems/construction_service.gd")
const MoveInServiceScript = preload("res://scripts/systems/move_in_service.gd")
const ResidentServiceScript = preload("res://scripts/systems/resident_service.gd")
const GameTimeScript = preload("res://scripts/systems/game_time.gd")
const BUILD_COSTS := {"ordinary": 100000}
const BABA_REPAIR_COST := 120000
const BABA_QUEST_REWARD := 150000

var world: DistrictWorld
var selected_plot_id: int = -1
var construction_service: ConstructionService
var move_in_service: MoveInService
var resident_service: ResidentService
var game_time: GameTime
var game_time_label: Label
var resident_label: Label
var resident_button: Button
var household_actions_heading: Label
var household_actions_grid: GridContainer
var household_action_buttons: Dictionary = {}
var autonomy_toggle_button: Button
var readiness_selector: OptionButton
var readiness_button: Button
var readiness_label: Label
var readiness_heading: Label
var readiness_note: Label
var selected_house_type: String = "ordinary"
var house_type_selector: OptionButton
var last_construction_save_second: int = -1
var economy: EconomyService
var save_service: SaveService
var save_timer: Timer
var baba_notebook_opened: bool = false
var baba_wiring_repaired: bool = false

var balance_label: Label
var plot_title: Label
var plot_description: Label
var build_button: Button
var status_label: Label
var control_root: Control
var hint_label: Label

func _ready() -> void:
	economy = EconomyServiceScript.new()
	add_child(economy)
	economy.balance_changed.connect(_on_balance_changed)
	save_service = SaveServiceScript.new()
	add_child(save_service)
	game_time = GameTimeScript.new()
	add_child(game_time)
	game_time.time_changed.connect(_on_game_time_changed)
	resident_service = ResidentServiceScript.new()
	add_child(resident_service)
	resident_service.residents_changed.connect(_on_residents_changed)
	move_in_service = MoveInServiceScript.new()
	add_child(move_in_service)
	move_in_service.readiness_updated.connect(_on_readiness_updated)
	move_in_service.house_ready.connect(_on_house_ready)
	construction_service = ConstructionServiceScript.new()
	add_child(construction_service)
	construction_service.project_updated.connect(_on_construction_updated)
	construction_service.project_completed.connect(_on_construction_completed)
	world = DistrictWorldScript.new()
	add_child(world)
	world.plot_selected.connect(_on_plot_selected)
	_create_interface()
	_create_save_timer()
	_load_game()
	world.set_resident_groups(resident_service.get_resident_display_data())
	_update_balance()
	_on_game_time_changed(game_time.get_hour(), game_time.get_minute(), game_time.get_day())
	_show_empty_selection()

func _create_save_timer() -> void:
	save_timer = Timer.new()
	save_timer.wait_time = 5.0
	save_timer.timeout.connect(_save_game)
	add_child(save_timer)
	save_timer.start()

func _create_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	control_root = root
	root.resized.connect(_on_interface_resized)

	var top_panel := PanelContainer.new()
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	top_panel.position = Vector2(18, 16)
	top_panel.custom_minimum_size = Vector2(370, 66)
	top_panel.add_theme_stylebox_override("panel", _panel_style(Color("#263c34"), 0.92))
	root.add_child(top_panel)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 18)
	top_panel.add_child(top_row)
	var game_title := Label.new()
	game_title.text = "РАЙОН ЗА РУБЛЬ"
	game_title.add_theme_font_size_override("font_size", 20)
	game_title.add_theme_color_override("font_color", Color("#f4e8c8"))
	top_row.add_child(game_title)
	game_time_label = Label.new()
	game_time_label.add_theme_font_size_override("font_size", 16)
	game_time_label.add_theme_color_override("font_color", Color("#d9e6c8"))
	top_row.add_child(game_time_label)
	balance_label = Label.new()
	balance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance_label.add_theme_font_size_override("font_size", 18)
	balance_label.add_theme_color_override("font_color", Color("#f4d98d"))
	top_row.add_child(balance_label)

	hint_label = Label.new()
	hint_label.text = "ПК: правая кнопка — перемещение, колесо — масштаб  •  Телефон: перетаскивание и касание"
	hint_label.position = Vector2(22, 92)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color("#f6f0d9"))
	root.add_child(hint_label)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -342
	panel.offset_top = 104
	panel.offset_right = -18
	panel.offset_bottom = 680
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#263c34"), 0.96))
	root.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var heading := Label.new()
	heading.text = "УПРАВЛЕНИЕ РАЙОНОМ"
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", Color("#f4e8c8"))
	content.add_child(heading)

	plot_title = Label.new()
	plot_title.text = "Выбери участок"
	plot_title.add_theme_font_size_override("font_size", 21)
	plot_title.add_theme_color_override("font_color", Color("#f4d98d"))
	content.add_child(plot_title)

	plot_description = Label.new()
	plot_description.text = "Нажми на участок на карте, чтобы посмотреть доступные действия."
	plot_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plot_description.custom_minimum_size = Vector2(270, 86)
	plot_description.add_theme_color_override("font_color", Color("#e0e5d6"))
	content.add_child(plot_description)

	status_label = Label.new()
	status_label.text = "Район ждёт своего восстановления."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#b9c9ae"))
	content.add_child(status_label)

	house_type_selector = OptionButton.new()
	house_type_selector.add_item("Обычный дом — 10 минут")
	house_type_selector.add_item("Продвинутый дом — 30 минут")
	house_type_selector.add_item("Премиум-дом — 60 минут")
	house_type_selector.set_item_disabled(1, true)
	house_type_selector.set_item_disabled(2, true)
	house_type_selector.item_selected.connect(_on_house_type_selected)
	content.add_child(house_type_selector)

	build_button = Button.new()
	build_button.text = "Построить обычный дом"
	build_button.custom_minimum_size = Vector2(0, 46)
	build_button.disabled = true
	build_button.pressed.connect(_on_context_action_pressed)
	build_button.add_theme_color_override("font_color", Color("#26372d"))
	build_button.add_theme_stylebox_override("normal", _button_style(Color("#e6c77d")))
	build_button.add_theme_stylebox_override("hover", _button_style(Color("#f0d99d")))
	build_button.add_theme_stylebox_override("disabled", _button_style(Color("#777e70")))
	content.add_child(build_button)

	readiness_heading = Label.new()
	readiness_heading.text = "ПОДГОТОВКА К ЗАСЕЛЕНИЮ"
	readiness_heading.add_theme_font_size_override("font_size", 14)
	readiness_heading.add_theme_color_override("font_color", Color("#f4e8c8"))
	readiness_heading.visible = false
	content.add_child(readiness_heading)

	readiness_label = Label.new()
	readiness_label.text = "Готовность дома: 0/8"
	readiness_label.add_theme_color_override("font_color", Color("#e0e5d6"))
	readiness_label.visible = false
	content.add_child(readiness_label)

	readiness_selector = OptionButton.new()
	for requirement in move_in_service.get_requirements():
		readiness_selector.add_item(str(requirement["label"]))
	readiness_selector.visible = false
	readiness_selector.item_selected.connect(_on_readiness_option_selected)
	content.add_child(readiness_selector)

	readiness_note = Label.new()
	readiness_note.text = "Прототип: отметки без списания денег. Стоимость работ будет сбалансирована отдельно."
	readiness_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readiness_note.add_theme_font_size_override("font_size", 11)
	readiness_note.add_theme_color_override("font_color", Color("#c9d0b9"))
	readiness_note.visible = false
	content.add_child(readiness_note)

	readiness_button = Button.new()
	readiness_button.text = "Отметить этап выполненным"
	readiness_button.custom_minimum_size = Vector2(0, 40)
	readiness_button.visible = false
	readiness_button.pressed.connect(_on_readiness_button_pressed)
	readiness_button.add_theme_stylebox_override("normal", _button_style(Color("#b8cf9a")))
	content.add_child(readiness_button)

	resident_label = Label.new()
	resident_label.text = "Жители появятся после подготовки дома."
	resident_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resident_label.add_theme_color_override("font_color", Color("#e0e5d6"))
	resident_label.visible = false
	content.add_child(resident_label)

	resident_button = Button.new()
	resident_button.text = "Заселить семью"
	resident_button.custom_minimum_size = Vector2(0, 40)
	resident_button.visible = false
	resident_button.pressed.connect(_on_resident_button_pressed)
	resident_button.add_theme_stylebox_override("normal", _button_style(Color("#b8cf9a")))
	content.add_child(resident_button)

	household_actions_heading = Label.new()
	household_actions_heading.text = "ДЕЙСТВИЯ ДЛЯ СЕМЬИ"
	household_actions_heading.add_theme_font_size_override("font_size", 13)
	household_actions_heading.add_theme_color_override("font_color", Color("#f4e8c8"))
	household_actions_heading.visible = false
	content.add_child(household_actions_heading)

	household_actions_grid = GridContainer.new()
	household_actions_grid.columns = 2
	household_actions_grid.add_theme_constant_override("h_separation", 8)
	household_actions_grid.add_theme_constant_override("v_separation", 6)
	household_actions_grid.visible = false
	content.add_child(household_actions_grid)
	for action_id in ["meal", "shower", "rest", "leisure"]:
		var action_button := Button.new()
		action_button.text = resident_service.get_household_action_label(action_id)
		action_button.custom_minimum_size = Vector2(0, 38)
		action_button.add_theme_font_size_override("font_size", 12)
		action_button.add_theme_stylebox_override("normal", _button_style(Color("#b8cf9a")))
		action_button.pressed.connect(_on_household_action_pressed.bind(action_id))
		household_actions_grid.add_child(action_button)
		household_action_buttons[action_id] = action_button

	autonomy_toggle_button = Button.new()
	autonomy_toggle_button.custom_minimum_size = Vector2(0, 38)
	autonomy_toggle_button.add_theme_font_size_override("font_size", 12)
	autonomy_toggle_button.add_theme_stylebox_override("normal", _button_style(Color("#b8cf9a")))
	autonomy_toggle_button.pressed.connect(_on_autonomy_toggle_pressed)
	autonomy_toggle_button.visible = false
	content.add_child(autonomy_toggle_button)

	var footer := Label.new()
	footer.text = "Глава 1  •  Возвращение жизни"
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color("#a9b8a3"))
	content.add_child(footer)


func _on_interface_resized() -> void:
	if control_root == null or hint_label == null:
		return
	# Hide the long desktop hint on narrow landscape screens.
	hint_label.visible = control_root.size.x >= 900.0

func _panel_style(color: Color, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, alpha)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.border_color = Color("#d6c18b", 0.35)
	style.set_border_width_all(1)
	return style

func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style

func _update_balance() -> void:
	balance_label.text = "₽ %s" % _format_money(economy.balance)

func _on_game_time_changed(hour: int, minute: int, day: int) -> void:
	if game_time_label != null:
		game_time_label.text = "День %d  •  %02d:%02d" % [day, hour, minute]
	if resident_service != null:
		resident_service.update_time(hour, minute, day)

func _on_balance_changed(_new_balance: int) -> void:
	_update_balance()
	_save_game()

func _format_money(value: int) -> String:
	var raw := str(value)
	var result := ""
	for i in raw.length():
		result += raw[i]
		if (raw.length() - i - 1) % 3 == 0 and i < raw.length() - 1:
			result += " "
	return result

func _show_empty_selection() -> void:
	readiness_heading.visible = false
	readiness_label.visible = false
	readiness_selector.visible = false
	readiness_note.visible = false
	readiness_button.visible = false
	resident_label.visible = false
	resident_button.visible = false
	household_actions_grid.visible = false
	household_actions_heading.visible = false
	autonomy_toggle_button.visible = false
	plot_title.text = "Выбери участок"
	plot_description.text = "Нажми на участок на карте, чтобы посмотреть доступные действия."
	status_label.text = "Район ждёт своего восстановления."
	build_button.disabled = true

func _on_plot_selected(plot_id: int) -> void:
	selected_plot_id = plot_id
	var plot_name := world.get_plot_name(plot_id)
	var kind := world.get_plot_kind(plot_id)
	readiness_heading.visible = false
	readiness_label.visible = false
	readiness_selector.visible = false
	readiness_note.visible = false
	readiness_button.visible = false
	resident_label.visible = false
	resident_button.visible = false
	household_actions_grid.visible = false
	household_actions_heading.visible = false
	autonomy_toggle_button.visible = false
	plot_title.text = plot_name
	if kind == "home" and plot_id == 0:
		if baba_wiring_repaired:
			plot_description.text = "Баба Зина благодарит тебя: в доме снова работает электричество. В её блокноте появятся новые просьбы."
			status_label.text = "Задание выполнено • Проводка восстановлена"
			build_button.text = "Задание выполнено"
			build_button.disabled = true
		elif baba_notebook_opened:
			plot_description.text = "Блокнот Бабы Зины: «В доме совсем старая проводка. Свет мигает, а вечером страшно включать чайник. Помоги заменить проводку»."
			status_label.text = "Первое поручение • Замена электропроводки"
			build_button.text = "Починить проводку — 120 000 ₽"
			build_button.disabled = economy.balance < BABA_REPAIR_COST
		else:
			plot_description.text = "Здесь живёт Баба Зина. Её дому нужна забота. Поговори с ней и загляни в её старый блокнот."
			status_label.text = "Сюжетный дом • Первый житель района"
			build_button.text = "Открыть блокнот Бабы Зины"
			build_button.disabled = false
	elif kind == "empty":
		plot_description.text = "Свободный участок. Здесь можно начать строительство нового обычного дома."
		status_label.text = "Стоимость строительства: будет уточнена в балансе M1."
		build_button.text = "Построить обычный дом — 100 000 ₽"
		build_button.disabled = economy.balance < 100000
	elif kind == "building":
		var project := construction_service.get_project(plot_id)
		var progress := float(project.get("elapsed", 0.0)) / maxf(1.0, float(project.get("duration", 1.0)))
		plot_description.text = "На участке работает бригада. Стадия: %s." % construction_service.get_stage(progress)
		status_label.text = "Строительство: %d%%" % int(progress * 100.0)
		build_button.text = "Строительство уже идёт"
		build_button.disabled = true
	else:
		var ready_count := move_in_service.get_completed_count(plot_id)
		var ready := move_in_service.is_ready(plot_id)
		var current_family := resident_service.get_family_at_plot(plot_id)
		if not current_family.is_empty():
			household_actions_grid.visible = true
			household_actions_heading.visible = true
			autonomy_toggle_button.visible = true
			autonomy_toggle_button.text = "Автономия: ВКЛ" if bool(current_family.get("autonomy_enabled", true)) else "Автономия: ВЫКЛ"
			plot_description.text = "Дом заселён: здесь живёт %s. Выбери, чем помочь семье." % str(current_family["title"])
			var needs: Dictionary = current_family.get("needs", {})
			var last_action := str(current_family.get("last_action_label", "Пока действий не было"))
			var action_source := str(current_family.get("last_action_source", ""))
			var action_source_label := "Автономия" if action_source == "autonomous" else ("Игрок" if action_source == "player" else "История")
			status_label.text = "Жителей: %d • %s\nЭнергия %d%%  Еда %d%%  Гигиена %d%%\nДосуг %d%%  Комфорт дома %d%%\nНастроение %d%%  Довольство %d%%\nПоследнее действие (%s): %s" % [
				int(current_family["members_count"]),
				str(current_family.get("activity_label", "Дома")),
				int(needs.get("energy", 75.0)),
				int(needs.get("hunger", 80.0)),
				int(needs.get("hygiene", 80.0)),
				int(needs.get("leisure", 75.0)),
				int(needs.get("home_comfort", 75.0)),
				int(current_family.get("mood", 75)),
				int(current_family.get("satisfaction", 75)),
				action_source_label,
				last_action
			]
			build_button.text = "Дом заселён"
		else:
			plot_description.text = "Коробка дома построена. Проверь инженерные системы, отделку и обустройство, прежде чем заселять семью."
			status_label.text = "Дом готов к заселению!" if ready else "Подготовка дома: %d из 8 этапов" % ready_count
			build_button.text = "Дом готов к заселению" if ready else "Строительство завершено"
		build_button.disabled = true
		readiness_heading.visible = current_family.is_empty()
		readiness_label.visible = current_family.is_empty()
		readiness_selector.visible = current_family.is_empty()
		readiness_note.visible = current_family.is_empty()
		readiness_button.visible = not ready and current_family.is_empty()
		readiness_label.text = "Готовность дома: %d/8" % ready_count
		if ready:
			readiness_button.text = "Все проверки пройдены"
			readiness_button.disabled = true
		else:
			readiness_button.text = "Отметить этап выполненным"
			readiness_button.disabled = false
			var checklist := move_in_service.get_checklist(plot_id)
			var selected_index := clampi(readiness_selector.selected, 0, move_in_service.get_requirements().size() - 1)
			var selected_req := str(move_in_service.get_requirements()[selected_index]["id"])
			if bool(checklist.get(selected_req, false)):
				readiness_button.text = "Этап уже выполнен"
				readiness_button.disabled = true

		if ready:
			var resident_family := current_family
			if not resident_family.is_empty():
				resident_label.text = "%s уже живёт здесь. Жителей: %d. Сейчас: %s. Настроение: %d%% • Удовлетворённость: %d%%" % [resident_family["title"], int(resident_family["members_count"]), str(resident_family.get("activity_label", "Дома")), int(resident_family["mood"]), int(resident_family["satisfaction"])]
				resident_button.visible = false
			else:
				var available_families := resident_service.get_available_families()
				if not available_families.is_empty():
					var next_family: Dictionary = available_families[0]
					resident_label.text = "%s ищут новый дом. Состав семьи: %d человека." % [next_family["title"], int(next_family["members_count"])]
					resident_button.text = "Заселить: %s" % str(next_family["title"])
					resident_button.visible = true
					resident_button.disabled = false
				else:
					resident_label.text = "Все доступные семьи уже получили жильё."
					resident_button.visible = false
			resident_label.visible = current_family.is_empty()

func _on_resident_button_pressed() -> void:
	if selected_plot_id < 1 or world.get_plot_kind(selected_plot_id) != "built":
		return
	if not move_in_service.is_ready(selected_plot_id) or resident_service.is_plot_occupied(selected_plot_id):
		return
	var available_families := resident_service.get_available_families()
	if available_families.is_empty():
		return
	var family_id := str(available_families[0]["id"])
	if resident_service.move_family_in(family_id, selected_plot_id, move_in_service.is_ready(selected_plot_id)):
		_on_plot_selected(selected_plot_id)
		status_label.text = "Семья заселилась! В районе появились первые соседи."
		_save_game()


func _on_autonomy_toggle_pressed() -> void:
	if selected_plot_id < 1:
		return
	var enabled := not resident_service.is_autonomy_enabled(selected_plot_id)
	if resident_service.set_autonomy_enabled(selected_plot_id, enabled):
		_save_game()
		status_label.text = "Автономное поведение семьи %s." % ("включено" if enabled else "выключено")

func _on_household_action_pressed(action_id: String) -> void:
	if selected_plot_id < 1:
		return
	if resident_service.apply_household_action(selected_plot_id, action_id):
		_save_game()
		var action_label := resident_service.get_household_action_label(action_id)
		status_label.text = "%s: потребность семьи восстановлена." % action_label
	else:
		var remaining := resident_service.get_household_action_cooldown(selected_plot_id, action_id)
		if remaining > 0:
			status_label.text = "Это действие будет доступно через %d игровых минут." % remaining
		else:
			status_label.text = "Сейчас это действие недоступно по распорядку семьи."

func _on_residents_changed(plot_id: int) -> void:
	world.set_resident_groups(resident_service.get_resident_display_data())
	if selected_plot_id == plot_id:
		_on_plot_selected(plot_id)

func _on_readiness_option_selected(_index: int) -> void:
	if selected_plot_id >= 1 and world.get_plot_kind(selected_plot_id) == "built":
		_on_plot_selected(selected_plot_id)

func _on_readiness_button_pressed() -> void:
	if selected_plot_id < 1 or world.get_plot_kind(selected_plot_id) != "built":
		return
	var requirements := move_in_service.get_requirements()
	var index := clampi(readiness_selector.selected, 0, requirements.size() - 1)
	var requirement_id := str(requirements[index]["id"])
	if move_in_service.complete_requirement(selected_plot_id, requirement_id):
		_on_plot_selected(selected_plot_id)
		_save_game()

func _on_readiness_updated(plot_id: int, _completed_count: int, _total_count: int) -> void:
	if selected_plot_id == plot_id:
		_on_plot_selected(plot_id)

func _on_house_ready(plot_id: int) -> void:
	if selected_plot_id == plot_id:
		_on_plot_selected(plot_id)
		status_label.text = "Все проверки пройдены! Дом готов принять семью."
	_save_game()

func _on_house_type_selected(index: int) -> void:
	selected_house_type = ["ordinary", "advanced", "premium"][clampi(index, 0, 2)]
	if selected_plot_id >= 0:
		_on_plot_selected(selected_plot_id)

func _on_context_action_pressed() -> void:
	if selected_plot_id == 0:
		if not baba_notebook_opened:
			baba_notebook_opened = true
			_save_game()
			_on_plot_selected(0)
			status_label.text = "Баба Зина доверила тебе своё первое поручение."
			return
		if not baba_wiring_repaired:
			if not economy.try_spend(BABA_REPAIR_COST, "Ремонт электропроводки дома Бабы Зины"):
				status_label.text = "Не хватает денег на материалы и работу электрика."
				return
			baba_wiring_repaired = true
			world.set_baba_home_repaired(true)
			economy.add_money(BABA_QUEST_REWARD, "Награда за помощь Бабе Зине")
			_on_plot_selected(0)
			status_label.text = "Проводка восстановлена! Баба Зина вручает награду: 150 000 ₽."
			_save_game()
			return
		return
	_on_build_pressed()

func _on_build_pressed() -> void:
	if selected_plot_id < 1 or world.get_plot_kind(selected_plot_id) != "empty":
		return
	if not BUILD_COSTS.has(selected_house_type):
		status_label.text = "Стоимость этого типа дома будет добавлена после балансировки экономики."
		return
	if construction_service.projects.size() >= construction_service.crew_count:
		status_label.text = "Все строительные бригады заняты. Для параллельной стройки понадобится ещё бригада."
		return
	var build_cost := int(BUILD_COSTS[selected_house_type])
	if not economy.try_spend(build_cost, "Строительство обычного дома"):
		status_label.text = "Недостаточно средств."
		return
	if not construction_service.start_project(selected_plot_id, selected_house_type):
		economy.add_money(build_cost, "Возврат: стройка не запущена")
		status_label.text = "Не удалось назначить строительную бригаду."
		return
	world.set_plot_building(selected_plot_id, 0.0)
	status_label.text = "Бригада приступила к работе. Подготовка участка."
	_on_plot_selected(selected_plot_id)
	_save_game()

func _on_construction_updated(plot_id: int, progress: float, stage: String) -> void:
	world.set_plot_building(plot_id, progress)
	if selected_plot_id == plot_id:
		var project := construction_service.get_project(plot_id)
		var remaining := maxi(0, int(ceil(float(project.get("duration", 0.0)) - float(project.get("elapsed", 0.0)))))
		status_label.text = "%s • %d%% • осталось %d сек." % [stage, int(progress * 100.0), remaining]
	var current_second := int(Time.get_ticks_msec() / 1000)
	if current_second % 5 == 0 and current_second != last_construction_save_second:
		last_construction_save_second = current_second
		_save_game()

func _on_construction_completed(plot_id: int) -> void:
	world.finish_plot(plot_id)
	if selected_plot_id == plot_id:
		_on_plot_selected(plot_id)
		status_label.text = "Дом готов! Следующий этап — подготовка к заселению."
	_save_game()

func _save_game() -> void:
	if save_service == null or economy == null or world == null:
		return
	var data := {
		"balance": economy.balance,
		"baba_notebook_opened": baba_notebook_opened,
		"baba_wiring_repaired": baba_wiring_repaired,
		"world": world.get_save_data(),
		"construction": construction_service.get_save_data(),
		"move_in": move_in_service.get_save_data(),
		"residents": resident_service.get_save_data(),
		"game_time": game_time.get_save_data()
	}
	save_service.save_game(data)

func _load_game() -> void:
	var data := save_service.load_game()
	if data.is_empty():
		return
	economy.set_balance(int(data.get("balance", 1000000)))
	baba_notebook_opened = bool(data.get("baba_notebook_opened", false))
	baba_wiring_repaired = bool(data.get("baba_wiring_repaired", false))
	var world_data: Variant = data.get("world", {})
	if world_data is Dictionary:
		world.load_save_data(world_data)
	var move_in_data: Variant = data.get("move_in", {})
	if move_in_data is Dictionary:
		move_in_service.load_save_data(move_in_data)
	var residents_data: Variant = data.get("residents", {})
	if residents_data is Dictionary:
		resident_service.load_save_data(residents_data)
	var saved_at := int(data.get("saved_at", 0))
	var offline_seconds := maxi(0, int(Time.get_unix_time_from_system()) - saved_at)
	var game_time_data: Variant = data.get("game_time", {})
	if game_time_data is Dictionary:
		game_time.load_save_data(game_time_data, offline_seconds)
	_on_game_time_changed(game_time.get_hour(), game_time.get_minute(), game_time.get_day())
	var construction_data: Variant = data.get("construction", {})
	if construction_data is Dictionary and not construction_data.is_empty():
		construction_service.load_save_data(construction_data, offline_seconds)
	else:
		var legacy_plot := int(data.get("construction_plot_id", -1))
		if legacy_plot >= 1 and legacy_plot < world.plot_states.size() and world.get_plot_kind(legacy_plot) == "building":
			if construction_service.start_project(legacy_plot, "ordinary"):
				var project: Dictionary = construction_service.projects[legacy_plot]
				project["elapsed"] = minf(600.0, float(data.get("construction_elapsed", 0.0)) + float(offline_seconds))
				if float(project["elapsed"]) >= 600.0:
					construction_service.projects.erase(legacy_plot)
					world.finish_plot(legacy_plot)
	for key in construction_service.projects.keys():
		var plot_id := int(key)
		var project: Dictionary = construction_service.get_project(plot_id)
		var progress := float(project.get("elapsed", 0.0)) / maxf(1.0, float(project.get("duration", 1.0)))
		world.set_plot_building(plot_id, progress)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_save_game()

