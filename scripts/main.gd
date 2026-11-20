extends Node2D

const DistrictWorldScript = preload("res://scripts/world/isometric_district_world.gd")
const EconomyServiceScript = preload("res://scripts/systems/economy_service.gd")
const SaveServiceScript = preload("res://scripts/systems/save_service.gd")
const ConstructionServiceScript = preload("res://scripts/systems/construction_service.gd")
const MoveInServiceScript = preload("res://scripts/systems/move_in_service.gd")
const ResidentServiceScript = preload("res://scripts/systems/resident_service.gd")
const GameTimeScript = preload("res://scripts/systems/game_time.gd")
const DistrictUpkeepServiceScript = preload("res://scripts/systems/district_upkeep_service.gd")
const BUILD_COSTS := {"ordinary": 100000}
const BABA_REPAIR_COST := 120000
const BABA_QUEST_REWARD := 150000

var world: DistrictWorld
var selected_plot_id: int = -1
var construction_service: ConstructionService
var move_in_service: MoveInService
var resident_service: ResidentService
var game_time: GameTime
var upkeep_service: DistrictUpkeepService
var game_time_label: Label
var resident_label: Label
var resident_button: Button
var household_actions_heading: Label
var household_actions_grid: GridContainer
var household_action_buttons: Dictionary = {}
var member_autonomy_container: VBoxContainer
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
var transaction_popup: PopupPanel
var transaction_rows: VBoxContainer
var transaction_summary_label: Label

func _ready() -> void:
	economy = EconomyServiceScript.new()
	add_child(economy)
	upkeep_service = DistrictUpkeepServiceScript.new()
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
	_create_transaction_history_popup()

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

	var transaction_button := Button.new()
	transaction_button.text = "₽  ЖУРНАЛ ОПЕРАЦИЙ"
	transaction_button.custom_minimum_size = Vector2(0, 40)
	transaction_button.add_theme_stylebox_override("normal", _button_style(Color("#d8c58e")))
	transaction_button.add_theme_stylebox_override("hover", _button_style(Color("#ead7a5")))
	transaction_button.pressed.connect(_on_transaction_history_pressed)
	content.add_child(transaction_button)

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
		readiness_selector.add_item("%s — ₽ %s" % [
			str(requirement["label"]),
			_format_money(int(requirement.get("cost", 0)))
		])
	readiness_selector.visible = false
	readiness_selector.item_selected.connect(_on_readiness_option_selected)
	content.add_child(readiness_selector)

	readiness_note = Label.new()
	readiness_note.text = "Каждый этап оплачивается отдельно. Общая стоимость полной подготовки: 150 000 ₽."
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

	member_autonomy_container = VBoxContainer.new()
	member_autonomy_container.add_theme_constant_override("separation", 4)
	member_autonomy_container.visible = false
	content.add_child(member_autonomy_container)

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


func _create_transaction_history_popup() -> void:
	transaction_popup = PopupPanel.new()
	transaction_popup.title = "Журнал денежных операций"
	transaction_popup.size = Vector2i(560, 380)
	transaction_popup.transient = true
	transaction_popup.exclusive = true
	add_child(transaction_popup)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#263c34"), 0.98))
	transaction_popup.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)

	var title := Label.new()
	title.text = "ДЕНЬГИ РАЙОНА"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#f4e8c8"))
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(42, 34)
	close_button.pressed.connect(transaction_popup.hide)
	header.add_child(close_button)

	transaction_summary_label = Label.new()
	transaction_summary_label.add_theme_color_override("font_color", Color("#f4d98d"))
	content.add_child(transaction_summary_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(500, 250)
	content.add_child(scroll)

	transaction_rows = VBoxContainer.new()
	transaction_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transaction_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(transaction_rows)


func _on_transaction_history_pressed() -> void:
	_refresh_transaction_history()
	transaction_popup.popup_centered(Vector2i(560, 380))


func _refresh_transaction_history() -> void:
	if transaction_rows == null or economy == null:
		return
	var entries := economy.get_transaction_history()
	transaction_summary_label.text = "Баланс района: ₽ %s  •  операций: %d" % [
		_format_money(economy.balance),
		entries.size()
	]
	for child in transaction_rows.get_children():
		transaction_rows.remove_child(child)
		child.queue_free()

	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Пока операций нет. Доходы и расходы появятся здесь."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color("#e0e5d6"))
		transaction_rows.add_child(empty_label)
		return

	for index in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[index]
		var amount := int(entry.get("amount", 0))
		var reason := str(entry.get("reason", "Операция"))
		var stamp := int(entry.get("timestamp", 0))
		var date_data := Time.get_datetime_dict_from_unix_time(stamp)
		var date_text := "%02d.%02d.%04d  •  %02d:%02d" % [
			int(date_data.get("day", 1)),
			int(date_data.get("month", 1)),
			int(date_data.get("year", 1970)),
			int(date_data.get("hour", 0)),
			int(date_data.get("minute", 0))
		]

		var row_panel := PanelContainer.new()
		row_panel.add_theme_stylebox_override("panel", _panel_style(Color("#354b40"), 0.9))
		transaction_rows.add_child(row_panel)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row_panel.add_child(row)

		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_theme_constant_override("separation", 2)
		row.add_child(details)

		var reason_label := Label.new()
		reason_label.text = reason
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason_label.add_theme_color_override("font_color", Color("#f4e8c8"))
		details.add_child(reason_label)

		var date_label := Label.new()
		date_label.text = date_text
		date_label.add_theme_font_size_override("font_size", 11)
		date_label.add_theme_color_override("font_color", Color("#b9c9ae"))
		details.add_child(date_label)

		var amount_label := Label.new()
		var sign := "+" if amount > 0 else "−"
		amount_label.text = "%s ₽%s" % [sign, _format_money(absi(amount))]
		amount_label.add_theme_font_size_override("font_size", 15)
		amount_label.add_theme_color_override("font_color", Color("#a9d58d") if amount > 0 else Color("#f0a18d"))
		amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(amount_label)


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
	if world != null:
		world.set_time_of_day(hour, minute)
	if resident_service != null:
		resident_service.update_time(hour, minute, day)
	if upkeep_service != null and economy != null and resident_service != null:
		if upkeep_service.process_day(day, resident_service.get_total_resident_count(), economy):
			_save_game()

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
	member_autonomy_container.visible = false
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
	member_autonomy_container.visible = false
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
			autonomy_toggle_button.text = "Общая автономия семьи: ВКЛ" if bool(current_family.get("autonomy_enabled", true)) else "Общая автономия семьи: ВЫКЛ"
			member_autonomy_container.visible = true
			for old_control in member_autonomy_container.get_children():
				old_control.queue_free()
			plot_description.text = "Дом заселён: здесь живёт %s. Каждый житель самостоятельно заботится о своих потребностях." % str(current_family["title"])
			var needs: Dictionary = current_family.get("needs", {})
			var last_action := str(current_family.get("last_action_label", "Пока действий не было"))
			var action_source := str(current_family.get("last_action_source", ""))
			var action_source_label := "Автономия" if action_source == "autonomous" else ("Игрок" if action_source == "player" else "История")
			var member_lines := PackedStringArray()
			for member_value in current_family.get("members", []):
				if not member_value is Dictionary:
					continue
				var member: Dictionary = member_value
				var member_needs: Dictionary = member.get("needs", {})
				var member_autonomy := bool(member.get("autonomy_enabled", true))
				var member_last_action := str(member.get("last_action_label", "Пока действий не было"))
				var personal_goal: Dictionary = member.get("personal_goal", {})
				var goal_progress := int(personal_goal.get("progress", 0))
				var goal_target := maxi(1, int(personal_goal.get("target", 3)))
				var goal_status := "выполнена" if bool(personal_goal.get("completed", false)) else "%d/%d" % [goal_progress, goal_target]
				member_lines.append("%s — %s\nПредпочтения: %s\nЛичная цель: %s (%s)\nОтношения в семье: %s (%d%%)\nЭнергия %d%% • Еда %d%% • Гигиена %d%% • Досуг %d%% • Настроение %d%%\nАвтономия: %s • Последнее действие: %s" % [
					str(member.get("name", "Житель")),
					str(member.get("activity_label", "Дома")),
					str(member.get("preferences_label", "Предпочтения не заданы")),
					str(personal_goal.get("title", "Личная цель не задана")),
					goal_status,
					str(member.get("relationship_label", "Нейтральные")),
					int(member.get("relationship_average", 60.0)),
					int(member_needs.get("energy", 75.0)),
					int(member_needs.get("hunger", 80.0)),
					int(member_needs.get("hygiene", 80.0)),
					int(member_needs.get("leisure", 75.0)),
					int(member.get("mood", 75)),
					"включена" if member_autonomy else "выключена",
					member_last_action
				])
				var member_toggle := Button.new()
				member_toggle.text = "%s — автономия %s" % [str(member.get("name", "Житель")), "ВКЛ" if member_autonomy else "ВЫКЛ"]
				member_toggle.custom_minimum_size = Vector2(0, 34)
				member_toggle.add_theme_font_size_override("font_size", 11)
				member_toggle.add_theme_stylebox_override("normal", _button_style(Color("#b8cf9a")))
				member_toggle.pressed.connect(_on_member_autonomy_toggle_pressed.bind(str(member.get("id", ""))))
				member_autonomy_container.add_child(member_toggle)
				for target_value in current_family.get("members", []):
					if not target_value is Dictionary:
						continue
					var target_member: Dictionary = target_value
					var target_id := str(target_member.get("id", ""))
					if target_id == str(member.get("id", "")):
						continue
					var pair_data := resident_service.get_targeted_relationship_data(selected_plot_id, str(member.get("id", "")), target_id)
					if pair_data.is_empty():
						continue
					var pair_score := int(pair_data.get("score", 60))
					var pair_status := str(pair_data.get("label", "Нейтральные"))
					var pair_remaining := int(pair_data.get("cooldown_remaining", 0))
					var pair_available := bool(pair_data.get("participants_available", false))
					var pair_label := Label.new()
					if pair_remaining > 0:
						pair_label.text = "Связь: %s • %d/100 • разговор через %d игровых мин." % [pair_status, pair_score, pair_remaining]
					elif not pair_available:
						pair_label.text = "Связь: %s • %d/100 • оба должны быть дома или на прогулке" % [pair_status, pair_score]
					else:
						pair_label.text = "Связь: %s • %d/100 • разговор доступен" % [pair_status, pair_score]
					pair_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					pair_label.add_theme_font_size_override("font_size", 10)
					pair_label.add_theme_color_override("font_color", Color("#e0e5d6"))
					member_autonomy_container.add_child(pair_label)
					var talk_button := Button.new()
					talk_button.text = "%s → поговорить с %s" % [str(member.get("name", "Житель")), str(target_member.get("name", "родственником"))]
					talk_button.custom_minimum_size = Vector2(0, 34)
					talk_button.disabled = not bool(pair_data.get("available", false))
					talk_button.add_theme_font_size_override("font_size", 11)
					talk_button.add_theme_stylebox_override("normal", _button_style(Color("#d5c4a1")))
					talk_button.pressed.connect(_on_resident_talk_to_member_pressed.bind(str(member.get("id", "")), target_id))
					member_autonomy_container.add_child(talk_button)
					var shared_remaining := resident_service.get_shared_time_cooldown_remaining(selected_plot_id, str(member.get("id", "")), target_id)
					var shared_button := Button.new()
					shared_button.text = "%s → провести время с %s" % [str(member.get("name", "Житель")), str(target_member.get("name", "родственником"))]
					if shared_remaining > 0:
						shared_button.text += " • через %d мин." % shared_remaining
					shared_button.custom_minimum_size = Vector2(0, 34)
					shared_button.disabled = not pair_available or shared_remaining > 0
					shared_button.add_theme_font_size_override("font_size", 11)
					shared_button.add_theme_stylebox_override("normal", _button_style(Color("#b8cfca")))
					shared_button.pressed.connect(_on_resident_shared_time_pressed.bind(str(member.get("id", "")), target_id))
					member_autonomy_container.add_child(shared_button)
			var family_event: Dictionary = current_family.get("active_event", {})
			if not family_event.is_empty():
				var event_heading := Label.new()
				event_heading.text = str(family_event.get("title", "Семейное событие"))
				event_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				event_heading.add_theme_font_size_override("font_size", 13)
				event_heading.add_theme_color_override("font_color", Color("#f4d98d"))
				member_autonomy_container.add_child(event_heading)
				var event_description := Label.new()
				event_description.text = str(family_event.get("description", "Семье нужна поддержка."))
				event_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				event_description.add_theme_font_size_override("font_size", 11)
				event_description.add_theme_color_override("font_color", Color("#e0e5d6"))
				member_autonomy_container.add_child(event_description)
				for choice_value in family_event.get("choices", []):
					if not choice_value is Dictionary:
						continue
					var choice: Dictionary = choice_value
					var choice_button := Button.new()
					choice_button.text = str(choice.get("label", "Выбрать"))
					choice_button.custom_minimum_size = Vector2(0, 36)
					choice_button.add_theme_font_size_override("font_size", 11)
					choice_button.add_theme_stylebox_override("normal", _button_style(Color("#e6c77d")))
					choice_button.pressed.connect(_on_family_event_choice_pressed.bind(str(family_event.get("id", "")), str(choice.get("id", ""))))
					member_autonomy_container.add_child(choice_button)
			var member_summary := "\n".join(member_lines)
			var history_lines := PackedStringArray()
			var activity_history: Array = current_family.get("activity_history", [])
			for event_value in activity_history:
				if not event_value is Dictionary:
					continue
				var event: Dictionary = event_value
				var source_label := "Автономия" if str(event.get("source", "")) == "autonomous" else "Игрок"
				history_lines.append("День %d, %02d:%02d — %s (%s)" % [int(event.get("day", 1)), int(event.get("hour", 0)), int(event.get("minute", 0)), str(event.get("description", "Событие")), source_label])
			var history_summary := "\n".join(history_lines) if not history_lines.is_empty() else "Пока событий не было."
			status_label.text = "Жителей: %d • %s\nСреднее по семье — Энергия %d%%  Еда %d%%  Гигиена %d%%\nДосуг %d%%  Комфорт дома %d%%\nНастроение %d%%  Довольство %d%%\nПоследнее действие (%s): %s\n\nЖурнал семьи (последние события):\n%s\n\nПо каждому жителю:\n%s" % [
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
				last_action,
				history_summary,
				member_summary
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
			var checklist := move_in_service.get_checklist(plot_id)
			var requirements := move_in_service.get_requirements()
			var selected_index := clampi(readiness_selector.selected, 0, requirements.size() - 1)
			var selected_requirement: Dictionary = requirements[selected_index]
			var selected_req := str(selected_requirement["id"])
			var selected_cost := int(selected_requirement.get("cost", 0))
			readiness_button.text = "Оплатить этап — ₽ %s" % _format_money(selected_cost)
			readiness_button.disabled = economy.balance < selected_cost
			if bool(checklist.get(selected_req, false)):
				readiness_button.text = "Этап уже выполнен"
				readiness_button.disabled = true
			elif economy.balance < selected_cost:
				readiness_button.text = "Не хватает ₽ %s" % _format_money(selected_cost - economy.balance)

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


func _on_member_autonomy_toggle_pressed(member_id: String) -> void:
	if selected_plot_id < 1 or member_id.is_empty():
		return
	var family := resident_service.get_family_at_plot(selected_plot_id)
	for member_value in family.get("members", []):
		if not member_value is Dictionary:
			continue
		var member: Dictionary = member_value
		if str(member.get("id", "")) == member_id:
			var next_enabled := not bool(member.get("autonomy_enabled", true))
			if resident_service.set_member_autonomy_enabled(selected_plot_id, member_id, next_enabled):
				_save_game()
				_on_plot_selected(selected_plot_id)
			return

func _on_resident_talk_to_member_pressed(speaker_id: String, target_id: String) -> void:
	if selected_plot_id < 1 or speaker_id.is_empty() or target_id.is_empty():
		return
	if resident_service.talk_to_member(selected_plot_id, speaker_id, target_id):
		_save_game()
		var family := resident_service.get_family_at_plot(selected_plot_id)
		var speaker_name := speaker_id
		var target_name := target_id
		for member_value in family.get("members", []):
			if not member_value is Dictionary:
				continue
			var member: Dictionary = member_value
			if str(member.get("id", "")) == speaker_id:
				speaker_name = str(member.get("name", speaker_id))
			elif str(member.get("id", "")) == target_id:
				target_name = str(member.get("name", target_id))
		status_label.text = "%s поговорил(а) с %s. Их отношения улучшились!" % [speaker_name, target_name]
	else:
		var remaining := resident_service.get_targeted_social_cooldown_remaining(selected_plot_id, speaker_id, target_id)
		if remaining > 0:
			status_label.text = "Следующий разговор между этими жителями будет доступен через %d игровых минут." % remaining
		else:
			status_label.text = "Для разговора оба жителя должны быть дома или на прогулке."


func _on_resident_shared_time_pressed(speaker_id: String, target_id: String) -> void:
	if selected_plot_id < 1 or speaker_id.is_empty() or target_id.is_empty():
		return
	if resident_service.spend_time_with_member(selected_plot_id, speaker_id, target_id):
		_save_game()
		var family := resident_service.get_family_at_plot(selected_plot_id)
		var speaker_name := speaker_id
		var target_name := target_id
		for member_value in family.get("members", []):
			if not member_value is Dictionary:
				continue
			var member: Dictionary = member_value
			if str(member.get("id", "")) == speaker_id:
				speaker_name = str(member.get("name", speaker_id))
			elif str(member.get("id", "")) == target_id:
				target_name = str(member.get("name", target_id))
		status_label.text = "%s провёл(а) время с %s. Их отношения и настроение улучшились!" % [speaker_name, target_name]
	else:
		var remaining := resident_service.get_shared_time_cooldown_remaining(selected_plot_id, speaker_id, target_id)
		if remaining > 0:
			status_label.text = "Совместное время для этой пары будет доступно через %d игровых минут." % remaining
		else:
			status_label.text = "Оба жителя должны быть дома или на прогулке."


func _on_family_event_choice_pressed(event_id: String, choice_id: String) -> void:
	if selected_plot_id < 1 or event_id.is_empty() or choice_id.is_empty():
		return
	if resident_service.resolve_family_event(selected_plot_id, event_id, choice_id):
		_save_game()
		_on_plot_selected(selected_plot_id)
		status_label.text = "Семейное событие завершено. Отношения, настроение и журнал обновлены."
	else:
		status_label.text = "Это семейное событие уже завершилось или выбор недоступен."


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
	if requirements.is_empty():
		return
	var index := clampi(readiness_selector.selected, 0, requirements.size() - 1)
	var requirement: Dictionary = requirements[index]
	var requirement_id := str(requirement["id"])
	var checklist := move_in_service.get_checklist(selected_plot_id)
	if bool(checklist.get(requirement_id, false)):
		status_label.text = "Этот этап уже выполнен."
		return
	var cost := int(requirement.get("cost", 0))
	if not economy.try_spend(cost, "Подготовка дома: %s" % str(requirement["label"])):
		status_label.text = "Не хватает средств. Нужно ещё ₽ %s." % _format_money(maxi(0, cost - economy.balance))
		return
	if move_in_service.complete_requirement(selected_plot_id, requirement_id):
		_on_plot_selected(selected_plot_id)
		status_label.text = "%s выполнено. Списано ₽ %s." % [
			str(requirement["label"]),
			_format_money(cost)
		]
		_save_game()
	else:
		economy.add_money(cost, "Возврат: этап подготовки не завершён")

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
		"economy_transactions": economy.get_transaction_history(),
		"district_upkeep": upkeep_service.get_save_data(),
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
	var transactions_data: Variant = data.get("economy_transactions", [])
	if transactions_data is Array:
		economy.load_transaction_history(transactions_data)
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
	var upkeep_data: Variant = data.get("district_upkeep", {})
	if upkeep_data is Dictionary and not upkeep_data.is_empty():
		upkeep_service.load_save_data(upkeep_data)
	else:
		# Legacy saves start tracking from their current day; no retroactive charges.
		upkeep_service.initialize_day(game_time.get_day())
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

