extends Node2D

const DistrictWorldScript = preload("res://scripts/world/district_world.gd")
const BUILD_SECONDS := 600.0

var world: DistrictWorld
var selected_plot_id: int = -1
var construction_plot_id: int = -1
var construction_elapsed: float = 0.0
var balance: int = 1000000

var balance_label: Label
var plot_title: Label
var plot_description: Label
var build_button: Button
var status_label: Label
var build_timer: Timer

func _ready() -> void:
	world = DistrictWorldScript.new()
	add_child(world)
	world.plot_selected.connect(_on_plot_selected)
	_create_interface()
	_create_timer()
	_update_balance()
	_show_empty_selection()

func _create_timer() -> void:
	build_timer = Timer.new()
	build_timer.wait_time = 1.0
	build_timer.timeout.connect(_on_build_tick)
	add_child(build_timer)

func _create_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(22, 18)
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
	balance_label = Label.new()
	balance_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance_label.add_theme_font_size_override("font_size", 18)
	balance_label.add_theme_color_override("font_color", Color("#f4d98d"))
	top_row.add_child(balance_label)

	var hint := Label.new()
	hint.text = "Перемещение: правая кнопка мыши / касание двумя пальцами   •   Колесо: масштаб"
	hint.position = Vector2(24, 94)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("#f6f0d9"))
	root.add_child(hint)

	var panel := PanelContainer.new()
	panel.position = Vector2(930, 112)
	panel.custom_minimum_size = Vector2(320, 310)
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

	build_button = Button.new()
	build_button.text = "Построить обычный дом"
	build_button.custom_minimum_size = Vector2(0, 46)
	build_button.disabled = true
	build_button.pressed.connect(_on_build_pressed)
	build_button.add_theme_color_override("font_color", Color("#26372d"))
	build_button.add_theme_stylebox_override("normal", _button_style(Color("#e6c77d")))
	build_button.add_theme_stylebox_override("hover", _button_style(Color("#f0d99d")))
	build_button.add_theme_stylebox_override("disabled", _button_style(Color("#777e70")))
	content.add_child(build_button)

	var footer := Label.new()
	footer.text = "Глава 1  •  Возвращение жизни"
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color("#a9b8a3"))
	content.add_child(footer)

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
	balance_label.text = "₽ %s" % _format_money(balance)

func _format_money(value: int) -> String:
	var raw := str(value)
	var result := ""
	for i in raw.length():
		result += raw[i]
		if (raw.length() - i - 1) % 3 == 0 and i < raw.length() - 1:
			result += " "
	return result

func _show_empty_selection() -> void:
	plot_title.text = "Выбери участок"
	plot_description.text = "Нажми на участок на карте, чтобы посмотреть доступные действия."
	status_label.text = "Район ждёт своего восстановления."
	build_button.disabled = true

func _on_plot_selected(plot_id: int) -> void:
	selected_plot_id = plot_id
	var plot_name := world.get_plot_name(plot_id)
	var kind := world.get_plot_kind(plot_id)
	plot_title.text = plot_name
	if kind == "home" and plot_id == 0:
		plot_description.text = "Здесь живёт Баба Зина. Её дому нужна забота — загляни к ней и узнай, с чего начать."
		status_label.text = "Сюжетный дом • Первый житель района"
		build_button.disabled = true
	elif kind == "empty":
		plot_description.text = "Свободный участок. Здесь можно начать строительство нового обычного дома."
		status_label.text = "Стоимость строительства: будет уточнена в балансе M1."
		build_button.disabled = balance < 100000
	elif kind == "building":
		plot_description.text = "На участке уже работает строительная бригада."
		status_label.text = "Строительство: %d%%" % int(float(world.plot_states[plot_id]["progress"]) * 100.0)
		build_button.disabled = true
	else:
		plot_description.text = "Дом построен. Подготовка к заселению появится в следующем этапе."
		status_label.text = "Строительство завершено."
		build_button.disabled = true

func _on_build_pressed() -> void:
	if selected_plot_id < 1 or world.get_plot_kind(selected_plot_id) != "empty":
		return
	const BUILD_COST := 100000
	if balance < BUILD_COST:
		status_label.text = "Недостаточно средств."
		return
	balance -= BUILD_COST
	_update_balance()
	construction_plot_id = selected_plot_id
	construction_elapsed = 0.0
	world.set_plot_building(construction_plot_id, 0.0)
	status_label.text = "Бригада приступила к работе. Осталось 10 минут."
	build_button.disabled = true
	build_timer.start()
	_on_plot_selected(selected_plot_id)

func _on_build_tick() -> void:
	construction_elapsed += 1.0
	var progress := construction_elapsed / BUILD_SECONDS
	world.set_plot_building(construction_plot_id, progress)
	if selected_plot_id == construction_plot_id:
		status_label.text = "Строительство: %d%%  •  Осталось %d сек." % [
			int(progress * 100.0), int(BUILD_SECONDS - construction_elapsed)
		]
	if construction_elapsed >= BUILD_SECONDS:
		build_timer.stop()
		world.finish_plot(construction_plot_id)
		if selected_plot_id == construction_plot_id:
			status_label.text = "Дом готов! Следующий этап — подготовка к заселению."
		construction_plot_id = -1
