extends Node2D

const DistrictWorldScript = preload("res://scripts/world/isometric_district_world.gd")
const EconomyServiceScript = preload("res://scripts/systems/economy_service.gd")
const SaveServiceScript = preload("res://scripts/systems/save_service.gd")
const ConstructionServiceScript = preload("res://scripts/systems/construction_service.gd")
const MoveInServiceScript = preload("res://scripts/systems/move_in_service.gd")
const ResidentServiceScript = preload("res://scripts/systems/resident_service.gd")
const GameTimeScript = preload("res://scripts/systems/game_time.gd")
const DistrictUpkeepServiceScript = preload("res://scripts/systems/district_upkeep_service.gd")
const MunicipalServicesServiceScript = preload("res://scripts/systems/municipal_services_service.gd")
const DistrictProgressionServiceScript = preload("res://scripts/systems/district_progression_service.gd")
const DistrictEventServiceScript = preload("res://scripts/systems/district_event_service.gd")
const WeatherServiceScript = preload("res://scripts/systems/weather_service.gd")
const BusinessServiceScript = preload("res://scripts/systems/business_service.gd")
const BUILD_COSTS := {"ordinary": 100000}
const BABA_REPAIR_COST := 120000
const EAST_QUARTER_REQUIRED_LEVEL := 3
const EAST_QUARTER_REQUIRED_REPUTATION := 20
const BABA_QUEST_REWARD := 150000
const ROAD_CELL_COST := 5000
const ROAD_REMOVAL_REFUND := 2500
const ROAD_ASPHALT_COST := 12000
const ROAD_LAMP_COST := 8000

var world: DistrictWorld
var selected_plot_id: int = -1
var construction_service: ConstructionService
var move_in_service: MoveInService
var resident_service: ResidentService
var game_time: GameTime
var upkeep_service: DistrictUpkeepService
var municipal_services: MunicipalServicesService
var progression_service: DistrictProgressionService
var district_event_service: DistrictEventService
var weather_service: WeatherService
var business_service: BusinessService
var game_time_label: Label
var resident_label: Label
var resident_button: Button
var business_button: Button
var business_upgrade_button: Button
var business_lease_button: Button
var business_type_selector: OptionButton
var business_schedule_selector: OptionButton
var business_status_label: Label
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
var is_loading_game: bool = false

var balance_label: Label
var plot_title: Label
var plot_description: Label
var build_button: Button
var status_label: Label
var control_root: Control
var hint_label: Label
var transaction_popup: PopupPanel
var business_portfolio_popup: PopupPanel
var business_portfolio_summary_label: Label
var finance_popup: PopupPanel
var finance_summary_label: Label
var business_portfolio_rows: VBoxContainer
var transaction_rows: VBoxContainer
var transaction_summary_label: Label
var municipal_popup: PopupPanel
var municipal_rows: VBoxContainer
var municipal_summary_label: Label
var municipal_status_label: Label
var progression_popup: PopupPanel
var progression_summary_label: Label
var progression_achievements_rows: VBoxContainer
var progression_events_label: Label
var district_event_popup: PopupPanel
var district_event_title_label: Label
var district_event_description_label: Label
var district_event_choices: VBoxContainer
var district_event_status_label: Label
var weather_label: Label
var road_tool_button: Button
var road_remove_button: Button
var road_asphalt_button: Button
var road_lamp_button: Button
var road_tool_status_label: Label

func _ready() -> void:
	economy = EconomyServiceScript.new()
	add_child(economy)
	upkeep_service = DistrictUpkeepServiceScript.new()
	municipal_services = MunicipalServicesServiceScript.new()
	progression_service = DistrictProgressionServiceScript.new()
	district_event_service = DistrictEventServiceScript.new()
	weather_service = WeatherServiceScript.new()
	business_service = BusinessServiceScript.new()
	economy.balance_changed.connect(_on_balance_changed)
	save_service = SaveServiceScript.new()
	add_child(save_service)
	game_time = GameTimeScript.new()
	add_child(game_time)
	weather_service.initialize_day(game_time.get_day())
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
	world.road_cell_requested.connect(_on_road_cell_requested)
	_create_interface()
	_create_save_timer()
	_load_game()
	municipal_services.set_available_plot_ids(world.get_owned_plot_ids())
	district_event_service.set_available_plot_ids(world.get_owned_plot_ids())
	world.set_resident_groups(resident_service.get_resident_display_data())
	world.set_business_plots(business_service.get_business_visual_data(), game_time.get_hour())
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
	_create_finance_popup()
	_create_business_portfolio_popup()
	_create_municipal_services_popup()
	_create_progression_popup()
	_create_district_event_popup()

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
	var weather_panel := PanelContainer.new()
	weather_panel.position = Vector2(18, 116)
	weather_panel.size = Vector2(220, 34)
	weather_panel.custom_minimum_size = Vector2(220, 34)
	weather_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weather_panel.add_theme_stylebox_override("panel", _panel_style(Color("#263c34"), 0.88))
	root.add_child(weather_panel)
	weather_label = Label.new()
	weather_label.add_theme_font_size_override("font_size", 12)
	weather_label.add_theme_color_override("font_color", Color("#d9e6c8"))
	weather_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weather_panel.add_child(weather_label)

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

	var management_buttons := HBoxContainer.new()
	management_buttons.add_theme_constant_override("separation", 8)
	content.add_child(management_buttons)
	var transaction_button := Button.new()
	transaction_button.text = "ЖУРНАЛ"
	transaction_button.custom_minimum_size = Vector2(0, 40)
	transaction_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transaction_button.add_theme_font_size_override("font_size", 11)
	transaction_button.add_theme_stylebox_override("normal", _button_style(Color("#d8c58e")))
	transaction_button.pressed.connect(_on_transaction_history_pressed)
	management_buttons.add_child(transaction_button)
	var municipal_button := Button.new()
	municipal_button.text = "СЛУЖБЫ"
	municipal_button.custom_minimum_size = Vector2(0, 40)
	municipal_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	municipal_button.add_theme_font_size_override("font_size", 11)
	municipal_button.add_theme_stylebox_override("normal", _button_style(Color("#b8cf9a")))
	municipal_button.pressed.connect(_on_municipal_services_pressed)
	management_buttons.add_child(municipal_button)
	var progression_button := Button.new()
	progression_button.text = "ПРОГРЕСС"
	progression_button.custom_minimum_size = Vector2(0, 40)
	progression_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progression_button.add_theme_font_size_override("font_size", 10)
	progression_button.add_theme_stylebox_override("normal", _button_style(Color("#d5c4a1")))
	progression_button.pressed.connect(_on_progression_pressed)
	management_buttons.add_child(progression_button)
	var business_portfolio_button := Button.new()
	business_portfolio_button.text = "БИЗНЕС"
	business_portfolio_button.custom_minimum_size = Vector2(0, 40)
	business_portfolio_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	business_portfolio_button.add_theme_font_size_override("font_size", 10)
	business_portfolio_button.add_theme_stylebox_override("normal", _button_style(Color("#d5b98f")))
	business_portfolio_button.pressed.connect(_on_business_portfolio_pressed)
	var finance_button := Button.new()
	finance_button.text = "ФИНАНСЫ РАЙОНА"
	finance_button.custom_minimum_size = Vector2(0, 36)
	finance_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	finance_button.add_theme_font_size_override("font_size", 11)
	finance_button.add_theme_stylebox_override("normal", _button_style(Color("#b8c7c0")))
	finance_button.pressed.connect(_on_finance_pressed)
	content.add_child(finance_button)
	management_buttons.add_child(business_portfolio_button)
	road_tool_button = Button.new()
	road_tool_button.text = "ДОРОГИ"
	road_tool_button.custom_minimum_size = Vector2(0, 40)
	road_tool_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	road_tool_button.add_theme_font_size_override("font_size", 10)
	road_tool_button.add_theme_stylebox_override("normal", _button_style(Color("#b8c7c0")))
	road_tool_button.pressed.connect(_on_road_tool_pressed)
	var road_buttons := HBoxContainer.new()
	road_buttons.add_theme_constant_override("separation", 8)
	content.add_child(road_buttons)
	road_buttons.add_child(road_tool_button)
	road_remove_button = Button.new()
	road_remove_button.text = "СНЕСТИ"
	road_remove_button.custom_minimum_size = Vector2(0, 40)
	road_remove_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	road_remove_button.add_theme_font_size_override("font_size", 10)
	road_remove_button.add_theme_stylebox_override("normal", _button_style(Color("#d6a17f")))
	road_remove_button.pressed.connect(_on_road_remove_pressed)
	road_buttons.add_child(road_remove_button)
	road_asphalt_button = Button.new()
	road_asphalt_button.text = "АСФАЛЬТ"
	road_asphalt_button.custom_minimum_size = Vector2(0, 40)
	road_asphalt_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	road_asphalt_button.add_theme_font_size_override("font_size", 10)
	road_asphalt_button.add_theme_stylebox_override("normal", _button_style(Color("#8eb8d6")))
	road_asphalt_button.pressed.connect(_on_road_asphalt_pressed)
	road_buttons.add_child(road_asphalt_button)
	road_lamp_button = Button.new()
	road_lamp_button.text = "ФОНАРИ"
	road_lamp_button.custom_minimum_size = Vector2(0, 40)
	road_lamp_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	road_lamp_button.add_theme_font_size_override("font_size", 10)
	road_lamp_button.add_theme_stylebox_override("normal", _button_style(Color("#e1c77f")))
	road_lamp_button.pressed.connect(_on_road_lamp_pressed)
	road_buttons.add_child(road_lamp_button)

	road_tool_status_label = Label.new()
	road_tool_status_label.text = "Дороги: 5 000 ₽ за клетку. Включи режим, чтобы строить."
	road_tool_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	road_tool_status_label.add_theme_font_size_override("font_size", 11)
	road_tool_status_label.add_theme_color_override("font_color", Color("#d9e6c8"))
	content.add_child(road_tool_status_label)

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

	business_status_label = Label.new()
	business_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	business_status_label.add_theme_font_size_override("font_size", 11)
	business_status_label.add_theme_color_override("font_color", Color("#e0e5d6"))
	business_status_label.visible = false
	content.add_child(business_status_label)

	business_type_selector = OptionButton.new()
	business_type_selector.add_theme_font_size_override("font_size", 11)
	business_type_selector.item_selected.connect(_on_business_type_selected)
	business_type_selector.visible = false
	for type_id in business_service.get_business_type_ids():
		business_type_selector.add_item("%s — ₽ %s" % [business_service.get_business_type_title(type_id), _format_money(business_service.get_opening_cost(type_id))])
		business_type_selector.set_item_metadata(business_type_selector.item_count - 1, type_id)
	content.add_child(business_type_selector)

	business_schedule_selector = OptionButton.new()
	business_schedule_selector.add_theme_font_size_override("font_size", 11)
	business_schedule_selector.item_selected.connect(_on_business_schedule_selected)
	business_schedule_selector.visible = false
	for schedule_id in business_service.get_business_schedule_ids():
		business_schedule_selector.add_item(business_service.get_business_schedule_title(schedule_id))
		business_schedule_selector.set_item_metadata(business_schedule_selector.item_count - 1, schedule_id)
	content.add_child(business_schedule_selector)

	business_button = Button.new()
	business_button.text = "Открыть магазин"
	business_button.custom_minimum_size = Vector2(0, 38)
	business_button.add_theme_font_size_override("font_size", 11)
	business_button.add_theme_stylebox_override("normal", _button_style(Color("#e6c77d")))
	business_button.pressed.connect(_on_business_action_pressed)
	business_button.visible = false
	content.add_child(business_button)

	business_upgrade_button = Button.new()
	business_upgrade_button.text = "Улучшить заведение"
	business_upgrade_button.custom_minimum_size = Vector2(0, 36)
	business_upgrade_button.add_theme_font_size_override("font_size", 11)
	business_upgrade_button.add_theme_stylebox_override("normal", _button_style(Color("#b8cfca")))
	business_upgrade_button.pressed.connect(_on_business_upgrade_pressed)
	business_upgrade_button.visible = false
	content.add_child(business_upgrade_button)

	business_lease_button = Button.new()
	business_lease_button.text = "Сдать помещение в аренду"
	business_lease_button.custom_minimum_size = Vector2(0, 36)
	business_lease_button.add_theme_font_size_override("font_size", 11)
	business_lease_button.add_theme_stylebox_override("normal", _button_style(Color("#d5bd91")))
	business_lease_button.pressed.connect(_on_business_lease_pressed)
	business_lease_button.visible = false
	content.add_child(business_lease_button)

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


func _create_business_portfolio_popup() -> void:
	business_portfolio_popup = PopupPanel.new()
	business_portfolio_popup.title = "Коммерческие заведения района"
	business_portfolio_popup.size = Vector2i(600, 500)
	business_portfolio_popup.transient = true
	business_portfolio_popup.exclusive = true
	add_child(business_portfolio_popup)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#263c34"), 0.98))
	business_portfolio_popup.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "КОММЕРЧЕСКИЙ ПОРТФЕЛЬ РАЙОНА"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#f4e8c8"))
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(42, 34)
	close_button.pressed.connect(business_portfolio_popup.hide)
	header.add_child(close_button)

	business_portfolio_summary_label = Label.new()
	business_portfolio_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	business_portfolio_summary_label.add_theme_color_override("font_color", Color("#f4d98d"))
	content.add_child(business_portfolio_summary_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(540, 340)
	content.add_child(scroll)
	business_portfolio_rows = VBoxContainer.new()
	business_portfolio_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	business_portfolio_rows.add_theme_constant_override("separation", 7)
	scroll.add_child(business_portfolio_rows)


func _on_business_portfolio_pressed() -> void:
	_refresh_business_portfolio()
	business_portfolio_popup.popup_centered(Vector2i(600, 500))


func _refresh_business_portfolio() -> void:
	if business_portfolio_rows == null or business_service == null:
		return
	var summary := business_service.get_portfolio_summary()
	var operating_result := int(summary.get("operating_result", 0))
	business_portfolio_summary_label.text = "Заведений: %d • работают: %d • сданы в аренду: %d\nПокупатели: %s • выручка: ₽ %s\nНачислено расходов: ₽ %s • оплачено: ₽ %s • долг: ₽ %s\nОперационный результат собственных заведений: %s ₽\nПолучено аренды: ₽ %s" % [
		int(summary.get("business_count", 0)),
		int(summary.get("active_count", 0)),
		int(summary.get("leased_count", 0)),
		_format_money(int(summary.get("total_customers", 0))),
		_format_money(int(summary.get("total_revenue", 0))),
		_format_money(int(summary.get("total_operating_costs", 0))),
		_format_money(int(summary.get("total_operating_costs_paid", 0))),
		_format_money(int(summary.get("unpaid_operating_costs", 0))),
		("+" if operating_result >= 0 else "−") + _format_money(absi(operating_result)),
		_format_money(int(summary.get("total_rent_received", 0)))
	]
	for child in business_portfolio_rows.get_children():
		business_portfolio_rows.remove_child(child)
		child.queue_free()
	var plot_ids: Array[int] = []
	for key in business_service.businesses.keys():
		plot_ids.append(int(key))
	plot_ids.sort()
	if plot_ids.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Коммерческих заведений пока нет. Открой магазин на готовом свободном участке."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color("#e0e5d6"))
		business_portfolio_rows.add_child(empty_label)
		return
	for plot_id in plot_ids:
		var business: Dictionary = business_service.get_business(plot_id)
		var leased := bool(business.get("leased", false))
		var active := bool(business.get("active", false))
		var business_type := str(business.get("type", "corner_shop"))
		var status := "АРЕНДА" if leased else ("РАБОТАЕТ" if active else "ПРИОСТАНОВЛЕНО")
		var details := "Покупатели: %s • выручка: ₽ %s\nРасходы: ₽ %s • оплачено: ₽ %s • долг: ₽ %s" % [
			_format_money(int(business.get("total_customers", 0))),
			_format_money(int(business.get("total_revenue", 0))),
			_format_money(int(business.get("total_operating_costs", 0))),
			_format_money(int(business.get("total_operating_costs_paid", 0))),
			_format_money(int(business.get("unpaid_operating_costs", 0)))
		]
		if leased:
			details = "Арендная ставка: ₽ %s/сутки • получено: ₽ %s" % [
				_format_money(business_service.get_daily_rent(plot_id)),
				_format_money(int(business.get("total_rent_received", 0)))
			]
		var row_panel := PanelContainer.new()
		row_panel.add_theme_stylebox_override("panel", _panel_style(Color("#354b40"), 0.9))
		business_portfolio_rows.add_child(row_panel)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		row_panel.add_child(row)
		var heading := Label.new()
		heading.text = "Участок %d • %s • %s • репутация %d/100" % [
			plot_id,
			business_service.get_business_type_title(business_type),
			status,
			business_service.get_business_reputation(plot_id)
		]
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.add_theme_color_override("font_color", Color("#f4e8c8"))
		row.add_child(heading)
		var details_label := Label.new()
		details_label.text = details
		details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details_label.add_theme_font_size_override("font_size", 12)
		details_label.add_theme_color_override("font_color", Color("#c9d0b9"))
		row.add_child(details_label)


func _create_finance_popup() -> void:
	finance_popup = PopupPanel.new()
	finance_popup.title = "Финансы района"
	finance_popup.size = Vector2i(560, 390)
	finance_popup.transient = true
	finance_popup.exclusive = true
	add_child(finance_popup)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#263c34"), 0.98))
	finance_popup.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "ФИНАНСОВАЯ СВОДКА РАЙОНА"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#f4e8c8"))
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(42, 34)
	close_button.pressed.connect(finance_popup.hide)
	header.add_child(close_button)
	finance_summary_label = Label.new()
	finance_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	finance_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	finance_summary_label.add_theme_color_override("font_color", Color("#e0e5d6"))
	content.add_child(finance_summary_label)

func _on_finance_pressed() -> void:
	_refresh_finance_summary()
	finance_popup.popup_centered(Vector2i(560, 390))

func _refresh_finance_summary() -> void:
	if finance_summary_label == null or economy == null:
		return
	var resident_count := resident_service.get_total_resident_count()
	var business_projection := business_service.get_daily_financial_projection(resident_count, _get_average_resident_satisfaction(), progression_service.reputation, weather_service.weather_id)
	var business_revenue := int(business_projection.get("daily_revenue", 0))
	var rent_income := int(business_projection.get("daily_rent", 0))
	var business_costs := int(business_projection.get("daily_expenses", 0))
	var household_costs := upkeep_service.get_daily_cost(resident_count)
	var payroll := municipal_services.get_total_daily_payroll()
	var maintenance := 0
	for definition in municipal_services.get_service_definitions():
		var service_id := str(definition.get("id", ""))
		if municipal_services.is_automatic_maintenance_enabled(service_id):
			maintenance += municipal_services.get_maintenance_cost(service_id)
	var daily_income := business_revenue + rent_income
	var daily_costs := business_costs + household_costs + payroll + maintenance
	var daily_result := daily_income - daily_costs
	var result_sign := "+" if daily_result >= 0 else "−"
	var total_debt := business_service.unpaid_operating_costs + municipal_services.get_unpaid_wages() + upkeep_service.unpaid_balance
	finance_summary_label.text = "ТЕКУЩИЙ БАЛАНС\n₽ %s\n\nПРОГНОЗ НА ИГРОВЫЕ СУТКИ\nВыручка бизнеса: + ₽ %s\nАренда: + ₽ %s\nРасходы бизнеса: − ₽ %s\nКоммунальные расходы жителей: − ₽ %s\nЗарплаты служб: − ₽ %s\nПлановое обслуживание: до ₽ %s\n\nОжидаемый операционный результат: %s ₽ %s\n\nТЕКУЩИЕ ДОЛГИ\nБизнес: ₽ %s\nЗарплаты служб: ₽ %s\nКоммунальные расходы жителей: ₽ %s\nВсего задолженность: ₽ %s\n\nПрогноз ориентировочный. Спрос зависит от населения, удовлетворённости, репутации и погоды. Обслуживание показано как верхняя оценка." % [
		_format_money(economy.balance),
		_format_money(business_revenue),
		_format_money(rent_income),
		_format_money(business_costs),
		_format_money(household_costs),
		_format_money(payroll),
		_format_money(maintenance),
		result_sign, _format_money(absi(daily_result)),
		_format_money(business_service.unpaid_operating_costs),
		_format_money(municipal_services.get_unpaid_wages()),
		_format_money(upkeep_service.unpaid_balance),
		_format_money(total_debt)
	]

func _create_municipal_services_popup() -> void:
	municipal_popup = PopupPanel.new()
	municipal_popup.title = "Коммунальные службы района"
	municipal_popup.size = Vector2i(560, 470)
	municipal_popup.transient = true
	municipal_popup.exclusive = true
	add_child(municipal_popup)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#263c34"), 0.98))
	municipal_popup.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "ШТАТ КОММУНАЛЬНЫХ СЛУЖБ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("#f4e8c8"))
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(42, 34)
	close_button.pressed.connect(municipal_popup.hide)
	header.add_child(close_button)

	municipal_summary_label = Label.new()
	municipal_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	municipal_summary_label.add_theme_color_override("font_color", Color("#f4d98d"))
	content.add_child(municipal_summary_label)

	municipal_status_label = Label.new()
	municipal_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	municipal_status_label.add_theme_color_override("font_color", Color("#c9d0b9"))
	content.add_child(municipal_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(500, 340)
	content.add_child(scroll)
	municipal_rows = VBoxContainer.new()
	municipal_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	municipal_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(municipal_rows)


func _create_progression_popup() -> void:
	progression_popup = PopupPanel.new()
	progression_popup.title = "Развитие района"
	progression_popup.size = Vector2i(560, 470)
	progression_popup.transient = true
	progression_popup.exclusive = true
	add_child(progression_popup)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#263c34"), 0.98))
	progression_popup.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "РАЗВИТИЕ И ДОСТИЖЕНИЯ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("#f4e8c8"))
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(42, 34)
	close_button.pressed.connect(progression_popup.hide)
	header.add_child(close_button)

	progression_summary_label = Label.new()
	progression_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progression_summary_label.add_theme_color_override("font_color", Color("#f4d98d"))
	content.add_child(progression_summary_label)

	var achievements_heading := Label.new()
	achievements_heading.text = "ДОСТИЖЕНИЯ"
	achievements_heading.add_theme_font_size_override("font_size", 13)
	achievements_heading.add_theme_color_override("font_color", Color("#f4e8c8"))
	content.add_child(achievements_heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(500, 250)
	content.add_child(scroll)
	progression_achievements_rows = VBoxContainer.new()
	progression_achievements_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progression_achievements_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(progression_achievements_rows)

	progression_events_label = Label.new()
	progression_events_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progression_events_label.add_theme_font_size_override("font_size", 11)
	progression_events_label.add_theme_color_override("font_color", Color("#c9d0b9"))
	content.add_child(progression_events_label)


func _create_district_event_popup() -> void:
	district_event_popup = PopupPanel.new()
	district_event_popup.title = "Событие района"
	district_event_popup.size = Vector2i(560, 360)
	district_event_popup.transient = true
	district_event_popup.exclusive = true
	add_child(district_event_popup)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#263c34"), 0.98))
	district_event_popup.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	district_event_title_label = Label.new()
	district_event_title_label.add_theme_font_size_override("font_size", 19)
	district_event_title_label.add_theme_color_override("font_color", Color("#f4d98d"))
	district_event_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(district_event_title_label)

	district_event_description_label = Label.new()
	district_event_description_label.add_theme_color_override("font_color", Color("#e0e5d6"))
	district_event_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	district_event_description_label.custom_minimum_size = Vector2(500, 72)
	content.add_child(district_event_description_label)

	var choices_heading := Label.new()
	choices_heading.text = "КАК ПОСТУПИМ?"
	choices_heading.add_theme_font_size_override("font_size", 13)
	choices_heading.add_theme_color_override("font_color", Color("#f4e8c8"))
	content.add_child(choices_heading)

	district_event_choices = VBoxContainer.new()
	district_event_choices.add_theme_constant_override("separation", 6)
	content.add_child(district_event_choices)

	district_event_status_label = Label.new()
	district_event_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	district_event_status_label.add_theme_color_override("font_color", Color("#c9d0b9"))
	content.add_child(district_event_status_label)


func _show_district_event() -> void:
	if district_event_service == null or district_event_popup == null:
		return
	var event := district_event_service.get_active_event()
	if event.is_empty():
		return
	district_event_title_label.text = str(event.get("title", "Событие района"))
	district_event_description_label.text = str(event.get("description", "Району требуется внимание."))
	var target_plot_id := clampi(int(event.get("target_plot_id", 0)), 0, world.plot_states.size() - 1)
	var target_plot_name := world.get_plot_name(target_plot_id) if world != null else "Участок района"
	district_event_description_label.text += "\n\nЗона происшествия: %s" % target_plot_name
	var event_service_id := str(event.get("service_id", ""))
	var can_dispatch_staff := municipal_services != null and municipal_services.is_plot_assigned_to_service(event_service_id, target_plot_id)
	district_event_status_label.text = "День %d" % int(event.get("created_day", game_time.get_day()))
	for child in district_event_choices.get_children():
		district_event_choices.remove_child(child)
		child.queue_free()
	for choice in event.get("choices", []):
		if not choice is Dictionary:
			continue
		var choice_id := str(choice.get("id", ""))
		var cost := district_event_service.get_choice_cost(choice_id, municipal_services)
		var button := Button.new()
		var service_action := int(choice.get("cost", 0)) > 0
		var action_label := str(choice.get("label", "Выбрать"))
		if service_action:
			action_label = ("👷 Направить свою службу: " if can_dispatch_staff else "Вызвать подрядчика: ") + action_label
		button.text = "%s%s" % [
			action_label,
			"  •  ₽ %s" % _format_money(cost) if cost > 0 else "  •  бесплатно"
		]
		button.custom_minimum_size = Vector2(0, 42)
		button.add_theme_font_size_override("font_size", 12)
		button.disabled = cost < 0 or cost > economy.balance
		button.add_theme_stylebox_override("normal", _button_style(Color("#b8cf9a")))
		button.pressed.connect(_on_district_event_choice_pressed.bind(choice_id, service_action and can_dispatch_staff))
		district_event_choices.add_child(button)
	district_event_popup.popup_centered(Vector2i(560, 360))


func _on_district_event_choice_pressed(choice_id: String, dispatched_by_staff: bool = false) -> void:
	var active_event := district_event_service.get_active_event()
	var service_id := str(active_event.get("service_id", ""))
	var result := district_event_service.resolve_choice(choice_id, game_time.get_day(), economy, municipal_services)
	if not bool(result.get("success", false)):
		var failure_message := str(result.get("message", "Не удалось применить решение."))
		_show_district_event()
		district_event_status_label.text = failure_message
		return
	if dispatched_by_staff and municipal_services.record_work_order(service_id, game_time.get_day(), int(result.get("cost", 0))):
		result["message"] = "Штатная служба выполнила работу. " + str(result.get("message", ""))
	progression_service.add_progress(int(result.get("experience", 0)), int(result.get("reputation", 0)), str(result.get("reason", "Решение события района")))
	if progression_service.unlock_achievement("first_district_event"):
		progression_service.add_progress(15, 1, "Решено первое событие района")
	if progression_achievements_rows != null:
		_refresh_progression_popup()
	district_event_popup.hide()
	status_label.text = str(result.get("message", "Событие района завершено."))
	_save_game()


func _on_progression_pressed() -> void:
	_refresh_progression_popup()
	progression_popup.popup_centered(Vector2i(560, 470))


func _refresh_progression_popup() -> void:
	if progression_achievements_rows == null or progression_service == null:
		return
	var level := progression_service.get_level()
	var next_level_xp := progression_service.get_experience_needed()
	var progress_xp := progression_service.get_experience_progress()
	var xp_text := "максимальный уровень" if next_level_xp <= 0 else "%d / %d XP до следующего уровня" % [progress_xp, next_level_xp]
	progression_summary_label.text = "Уровень района: %d\nОпыт: %d XP  •  %s\nРепутация: %d / 100" % [
		level,
		progression_service.experience,
		xp_text,
		progression_service.reputation
	]
	for child in progression_achievements_rows.get_children():
		progression_achievements_rows.remove_child(child)
		child.queue_free()
	var unlocked_count := 0
	for achievement in progression_service.get_achievements():
		var unlocked := bool(achievement.get("unlocked", false))
		if unlocked:
			unlocked_count += 1
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _panel_style(Color("#354b40"), 0.9))
		progression_achievements_rows.add_child(row)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		row.add_child(info)
		var achievement_title := Label.new()
		achievement_title.text = "%s  %s" % ["✓" if unlocked else "○", str(achievement.get("title", "Достижение"))]
		achievement_title.add_theme_color_override("font_color", Color("#f4d98d") if unlocked else Color("#e0e5d6"))
		info.add_child(achievement_title)
		var description := Label.new()
		description.text = str(achievement.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 11)
		description.add_theme_color_override("font_color", Color("#c9d0b9"))
		info.add_child(description)
	progression_events_label.text = "Открыто достижений: %d / %d" % [unlocked_count, progression_service.get_achievements().size()]
	var events := progression_service.get_recent_events()
	if not events.is_empty():
		var last_event: Dictionary = events[events.size() - 1]
		progression_events_label.text += "\nПоследний вклад: %s  •  +%d XP  •  репутация %d" % [
			str(last_event.get("reason", "Развитие района")),
			int(last_event.get("experience", 0)),
			int(last_event.get("reputation", 0))
		]


func _award_district_progress(experience_gain: int, reputation_gain: int, reason: String) -> void:
	progression_service.add_progress(experience_gain, reputation_gain, reason)
	if selected_plot_id >= 0 and world != null and not world.is_plot_unlocked(selected_plot_id):
		_on_plot_selected(selected_plot_id)
	if progression_achievements_rows != null:
		_refresh_progression_popup()
	_save_game()


func _on_municipal_services_pressed() -> void:
	_refresh_municipal_services()
	municipal_popup.popup_centered(Vector2i(560, 470))


func _refresh_municipal_services() -> void:
	if municipal_rows == null or municipal_services == null:
		return
	municipal_summary_label.text = "Работников: %d  •  зарплата/сутки: ₽ %s  •  долг: ₽ %s  •  работ: %d  •  качество: %d%%  •  инфраструктура: %d%%  •  автослужб: %d" % [
		municipal_services.get_total_employee_count(),
		_format_money(municipal_services.get_total_daily_payroll()),
		_format_money(municipal_services.get_unpaid_wages()),
		municipal_services.get_total_work_orders_completed(),
		municipal_services.get_average_service_quality(),
		municipal_services.get_average_infrastructure_condition(),
		municipal_services.get_automatic_maintenance_count()
	]
	for child in municipal_rows.get_children():
		municipal_rows.remove_child(child)
		child.queue_free()
	for definition in municipal_services.get_service_definitions():
		var service_id := str(definition["id"])
		var label := str(definition["label"])
		var count := municipal_services.get_employee_count(service_id)
		var daily_salary := municipal_services.get_daily_salary(service_id)
		var hire_cost := municipal_services.get_hire_cost(service_id)
		var row_panel := PanelContainer.new()
		row_panel.add_theme_stylebox_override("panel", _panel_style(Color("#354b40"), 0.9))
		municipal_rows.add_child(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row_panel.add_child(row)
		var info := Label.new()
		var efficiency := municipal_services.get_service_efficiency_percent(service_id)
		var work_count := municipal_services.get_work_orders_completed(service_id)
		var last_work := municipal_services.get_last_work_day(service_id)
		var work_status := "Последняя работа: день %d" % last_work if last_work > 0 else "Работ пока не было"
		var work_spent := municipal_services.get_total_work_spent(service_id)
		var quality := municipal_services.get_service_quality_percent(service_id)
		var maintenance_cost := municipal_services.get_maintenance_cost(service_id)
		var maintenance_status := "ВКЛ • ₽ %s/работу" % _format_money(maintenance_cost) if municipal_services.is_automatic_maintenance_enabled(service_id) else "ВЫКЛ"
		var assigned_zones := municipal_services.get_service_zone_plot_ids(service_id)
		var equipment_level := municipal_services.get_equipment_level(service_id)
		var wages_accrued := municipal_services.get_total_wages_accrued(service_id)
		var wages_paid := municipal_services.get_total_wages_paid(service_id)
		var wages_unpaid := municipal_services.get_unpaid_wages_for_service(service_id)
		var equipment_spent := municipal_services.get_total_equipment_spent(service_id)
		var maintenance_spent := municipal_services.get_total_maintenance_spent(service_id)
		info.text = "%s\nШтат: %d  •  Эффективность: %d%%  •  Качество: %d%%\nТехника: уровень %d (+%d%%)  •  Зоны: %d/%d\nЗарплата: ₽ %s/день\nЗарплата всего: начислено ₽ %s  •  выплачено ₽ %s  •  долг ₽ %s\nОборудование: ₽ %s  •  обслуживание: ₽ %s\nАвтообслуживание: %s\nВыполнено работ: %d  •  %s\nЗатраты на работы: ₽ %s" % [label, count, efficiency, quality, equipment_level, equipment_level * MunicipalServicesService.EQUIPMENT_EFFICIENCY_PER_LEVEL, assigned_zones.size(), count, _format_money(daily_salary), _format_money(wages_accrued), _format_money(wages_paid), _format_money(wages_unpaid), _format_money(equipment_spent), _format_money(maintenance_spent), maintenance_status, work_count, work_status, _format_money(work_spent)]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_color_override("font_color", Color("#e0e5d6"))
		row.add_child(info)
		var maintenance_button := Button.new()
		maintenance_button.text = "Авто ВКЛ" if municipal_services.is_automatic_maintenance_enabled(service_id) else "Авто ВЫКЛ"
		maintenance_button.custom_minimum_size = Vector2(82, 42)
		maintenance_button.add_theme_font_size_override("font_size", 10)
		maintenance_button.disabled = count <= 0
		maintenance_button.pressed.connect(_on_municipal_maintenance_toggled.bind(service_id))
		row.add_child(maintenance_button)
		var zones_button := Button.new()
		zones_button.text = "Зоны"
		zones_button.custom_minimum_size = Vector2(64, 42)
		zones_button.add_theme_font_size_override("font_size", 10)
		zones_button.disabled = count <= 0
		zones_button.pressed.connect(_on_municipal_zones_pressed.bind(service_id))
		row.add_child(zones_button)
		var equipment_button := Button.new()
		equipment_button.text = "Техника"
		equipment_button.custom_minimum_size = Vector2(72, 42)
		equipment_button.add_theme_font_size_override("font_size", 10)
		equipment_button.pressed.connect(_on_municipal_equipment_pressed.bind(service_id))
		row.add_child(equipment_button)
		var fire_button := Button.new()
		fire_button.text = "−"
		fire_button.custom_minimum_size = Vector2(42, 42)
		fire_button.disabled = count <= 0
		fire_button.pressed.connect(_on_municipal_fire_pressed.bind(service_id))
		row.add_child(fire_button)
		var hire_button := Button.new()
		hire_button.text = "+ ₽ %s" % _format_money(hire_cost)
		hire_button.custom_minimum_size = Vector2(112, 42)
		hire_button.disabled = count >= MunicipalServicesService.MAX_EMPLOYEES_PER_SERVICE or economy.balance < hire_cost
		hire_button.add_theme_font_size_override("font_size", 11)
		hire_button.pressed.connect(_on_municipal_hire_pressed.bind(service_id))
		row.add_child(hire_button)


func _on_municipal_maintenance_toggled(service_id: String) -> void:
	var enabled := not municipal_services.is_automatic_maintenance_enabled(service_id)
	if municipal_services.set_automatic_maintenance_enabled(service_id, enabled):
		municipal_status_label.text = "Автоматическое обслуживание %s." % ("включено" if enabled else "отключено")
		_save_game()
	else:
		municipal_status_label.text = "Для автообслуживания сначала найми хотя бы одного работника."
	_refresh_municipal_services()


func _on_municipal_zones_pressed(service_id: String) -> void:
	var popup := PopupPanel.new()
	popup.name = "MunicipalZonesPopup"
	var layout := VBoxContainer.new()
	layout.custom_minimum_size = Vector2(320, 0)
	layout.add_theme_constant_override("separation", 8)
	popup.add_child(layout)
	var heading := Label.new()
	heading.text = "Зоны: %s" % service_id
	heading.add_theme_color_override("font_color", Color("#f4d98d"))
	layout.add_child(heading)
	var hint := Label.new()
	hint.text = "Один сотрудник обслуживает один участок. Можно выбрать не больше числа работников."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(hint)
	var zone_checkboxes: Array[CheckBox] = []
	var zone_plot_ids: Array[int] = []
	var assigned := municipal_services.get_service_zone_plot_ids(service_id)
	var zone_scroll := ScrollContainer.new()
	zone_scroll.custom_minimum_size = Vector2(320, 300)
	var zone_list := VBoxContainer.new()
	zone_scroll.add_child(zone_list)
	for plot_id in world.get_owned_plot_ids():
		var checkbox := CheckBox.new()
		checkbox.text = "%s • инфраструктура %d%%" % [world.get_plot_name(plot_id), municipal_services.get_plot_infrastructure_condition(plot_id)]
		checkbox.button_pressed = assigned.has(plot_id)
		zone_list.add_child(checkbox)
		zone_checkboxes.append(checkbox)
		zone_plot_ids.append(plot_id)
	layout.add_child(zone_scroll)
	var save_button := Button.new()
	save_button.text = "Сохранить зоны"
	save_button.pressed.connect(_save_municipal_service_zones.bind(service_id, zone_checkboxes, zone_plot_ids, popup))
	layout.add_child(save_button)
	popup.popup_hide.connect(popup.queue_free)
	add_child(popup)
	popup.popup_centered(Vector2i(380, 500))


func _save_municipal_service_zones(service_id: String, checkboxes: Array[CheckBox], plot_ids: Array[int], popup: PopupPanel) -> void:
	var selected_plots: Array[int] = []
	for index in range(checkboxes.size()):
		if checkboxes[index].button_pressed:
			selected_plots.append(plot_ids[index])
	if not municipal_services.set_service_zone_plot_ids(service_id, selected_plots):
		municipal_status_label.text = "Нельзя назначить больше участков, чем есть работников в этой службе."
		return
	municipal_status_label.text = "Зоны службы обновлены: %d участков." % selected_plots.size()
	popup.hide()
	_save_game()
	_refresh_municipal_services()


func _on_municipal_equipment_pressed(service_id: String) -> void:
	var popup := PopupPanel.new()
	popup.name = "MunicipalEquipmentPopup"
	var layout := VBoxContainer.new()
	layout.custom_minimum_size = Vector2(300, 0)
	layout.add_theme_constant_override("separation", 10)
	popup.add_child(layout)
	var level := municipal_services.get_equipment_level(service_id)
	var bonus := level * MunicipalServicesService.EQUIPMENT_EFFICIENCY_PER_LEVEL
	var heading := Label.new()
	var service_label := service_id
	for definition in municipal_services.get_service_definitions():
		if str(definition["id"]) == service_id:
			service_label = str(definition["label"])
			break
	heading.text = "Оборудование: %s" % service_label
	heading.add_theme_color_override("font_color", Color("#f4d98d"))
	layout.add_child(heading)
	var details := Label.new()
	details.text = "Уровень: %d/3\nБонус к эффективности: +%d%%\nДоплата к плановому обслуживанию: ₽ %d за сутки" % [level, bonus, level * MunicipalServicesService.EQUIPMENT_MAINTENANCE_PER_LEVEL]
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(details)
	var cost := municipal_services.get_equipment_upgrade_cost(service_id)
	var upgrade_button := Button.new()
	upgrade_button.text = "Улучшить • ₽ %s" % _format_money(cost) if cost >= 0 else "Максимальный уровень"
	upgrade_button.disabled = cost < 0 or economy.balance < cost or municipal_services.get_employee_count(service_id) <= 0
	if cost >= 0:
		upgrade_button.pressed.connect(_on_municipal_equipment_upgrade_pressed.bind(service_id, popup))
	layout.add_child(upgrade_button)
	popup.popup_hide.connect(popup.queue_free)
	add_child(popup)
	popup.popup_centered(Vector2i(360, 220))


func _on_municipal_equipment_upgrade_pressed(service_id: String, popup: PopupPanel) -> void:
	if municipal_services.upgrade_equipment(service_id, economy):
		municipal_status_label.text = "Оборудование улучшено. Эффективность службы повышена."
		popup.hide()
		_save_game()
	else:
		municipal_status_label.text = "Не удалось улучшить оборудование: проверь баланс и уровень."
	_refresh_municipal_services()


func _on_municipal_hire_pressed(service_id: String) -> void:
	var hire_cost := municipal_services.get_hire_cost(service_id)
	if municipal_services.hire_employee(service_id, economy):
		if municipal_services.get_total_employee_count() == 1 and progression_service.unlock_achievement("first_worker"):
			_award_district_progress(25, 2, "Нанят первый работник коммунальной службы")
		municipal_status_label.text = "Сотрудник принят. Найм оплачен: ₽ %s." % _format_money(hire_cost)
		_save_game()
	else:
		municipal_status_label.text = "Найм невозможен: проверь баланс или лимит штата."
	_refresh_municipal_services()


func _on_municipal_fire_pressed(service_id: String) -> void:
	if municipal_services.fire_employee(service_id):
		municipal_status_label.text = "Сотрудник уволен. Возврат средств за найм не предусмотрен."
		_save_game()
	_refresh_municipal_services()


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

func _get_average_resident_satisfaction() -> float:
	if resident_service == null:
		return 75.0
	var total := 0.0
	var count := 0
	for family_value in resident_service.get_resident_display_data():
		if not family_value is Dictionary:
			continue
		var family: Dictionary = family_value
		for member_value in family.get("members", []):
			if not member_value is Dictionary:
				continue
			var member: Dictionary = member_value
			total += float(member.get("satisfaction", 75))
			count += 1
	return total / float(count) if count > 0 else 75.0

func _on_game_time_changed(hour: int, minute: int, day: int) -> void:
	if game_time_label != null:
		game_time_label.text = "День %d  •  %02d:%02d" % [day, hour, minute]
	if world != null:
		world.set_time_of_day(hour, minute)
		if business_service != null:
			world.set_business_plots(business_service.get_business_visual_data(), hour)
	var weather_processed := false
	if not is_loading_game and weather_service != null:
		weather_processed = weather_service.process_day(day)
	var business_processed := false
	if not is_loading_game and business_service != null and economy != null:
		business_processed = business_service.process_day(day, economy, resident_service.get_total_resident_count(), _get_average_resident_satisfaction(), progression_service.reputation, weather_service.weather_id)
	_apply_weather_state()
	if not is_loading_game and resident_service != null:
		resident_service.update_time(hour, minute, day)
	if not is_loading_game and upkeep_service != null and economy != null and resident_service != null:
		if world != null:
			municipal_services.set_available_plot_ids(world.get_owned_plot_ids())
			district_event_service.set_available_plot_ids(world.get_owned_plot_ids())
		var upkeep_processed := upkeep_service.process_day(day, resident_service.get_total_resident_count(), economy)
		var payroll_processed := municipal_services.process_day(day, economy) if municipal_services != null else false
		var maintenance_processed := municipal_services.process_daily_maintenance(day, economy) if municipal_services != null else false
		var infrastructure_processed := municipal_services.process_daily_infrastructure(day) if municipal_services != null else false
		var resident_impact_processed := resident_service.apply_municipal_service_impact(municipal_services.get_plot_service_quality_by_plot(), municipal_services.get_plot_infrastructure_condition_data(), day) if municipal_services != null else false
		var event_spawned := district_event_service.process_day(day) if district_event_service != null else false
		if event_spawned:
			_show_district_event()
		if upkeep_processed or payroll_processed or maintenance_processed or infrastructure_processed or resident_impact_processed or event_spawned or weather_processed or business_processed:
			_save_game()
		if district_event_service != null and district_event_service.has_active_event() and district_event_popup != null and not district_event_popup.visible:
			_show_district_event()

func _apply_weather_state() -> void:
	if weather_service == null:
		return
	if weather_label != null:
		weather_label.text = "%s  •  %s" % [weather_service.get_season_label(), weather_service.get_weather_label()]
	if world != null:
		world.set_season(weather_service.season_id)
		world.set_weather(weather_service.weather_id)
	if resident_service != null:
		resident_service.set_environment(weather_service.season_id, weather_service.weather_id)
	if construction_service != null:
		var speed_multiplier := 1.0
		match weather_service.weather_id:
			"rain":
				speed_multiplier = 0.9
			"storm":
				speed_multiplier = 0.75
			"snow":
				speed_multiplier = 0.9
			"heatwave":
				speed_multiplier = 0.95
		construction_service.set_weather_speed_multiplier(speed_multiplier)


func _on_balance_changed(_new_balance: int) -> void:
	_update_balance()
	if municipal_rows != null:
		_refresh_municipal_services()
	if not is_loading_game:
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

func _on_road_tool_pressed() -> void:
	var enabled := not world.road_build_mode or world.road_edit_action != "build"
	world.set_road_build_mode(enabled, "build")
	road_tool_button.text = "ЗАКРЫТЬ" if enabled else "ДОРОГИ"
	road_remove_button.text = "СНЕСТИ"
	road_asphalt_button.text = "АСФАЛЬТ"
	road_lamp_button.text = "ФОНАРИ"
	road_tool_status_label.text = "Строительство: зелёная клетка — можно проложить дорогу. Цена — 5 000 ₽." if enabled else "Режим работы с дорогами выключен."

func _on_road_remove_pressed() -> void:
	var enabled := not world.road_build_mode or world.road_edit_action != "remove"
	world.set_road_build_mode(enabled, "remove")
	road_remove_button.text = "ЗАКРЫТЬ" if enabled else "СНЕСТИ"
	road_tool_button.text = "ДОРОГИ"
	road_asphalt_button.text = "АСФАЛЬТ"
	road_lamp_button.text = "ФОНАРИ"
	road_tool_status_label.text = "Демонтаж: оранжевая клетка — можно снять сегмент. Возврат за построенную дорогу — 2 500 ₽." if enabled else "Режим работы с дорогами выключен."

func _on_road_asphalt_pressed() -> void:
	var enabled := not world.road_build_mode or world.road_edit_action != "upgrade"
	world.set_road_build_mode(enabled, "upgrade")
	road_asphalt_button.text = "ЗАКРЫТЬ" if enabled else "АСФАЛЬТ"
	road_tool_button.text = "ДОРОГИ"
	road_remove_button.text = "СНЕСТИ"
	road_lamp_button.text = "ФОНАРИ"
	road_tool_status_label.text = "Асфальтирование: голубая клетка — можно улучшить покрытие. Цена — 12 000 ₽." if enabled else "Режим работы с дорогами выключен."

func _on_road_lamp_pressed() -> void:
	var enabled := not world.road_build_mode or world.road_edit_action != "lamp"
	world.set_road_build_mode(enabled, "lamp")
	road_lamp_button.text = "ЗАКРЫТЬ" if enabled else "ФОНАРИ"
	road_tool_button.text = "ДОРОГИ"
	road_remove_button.text = "СНЕСТИ"
	road_asphalt_button.text = "АСФАЛЬТ"
	road_tool_status_label.text = "Установка фонарей: жёлтая клетка — можно поставить фонарь. Цена — 8 000 ₽." if enabled else "Режим работы с дорогами выключен."

func _on_road_cell_requested(cell: Vector2i) -> void:
	if not world.road_build_mode:
		return
	if world.road_edit_action == "lamp":
		if not world.can_add_road_lamp(cell):
			road_tool_status_label.text = "Фонарь можно установить только на свободную клетку дороги."
			return
		if not economy.try_spend(ROAD_LAMP_COST, "Установка уличного фонаря"):
			road_tool_status_label.text = "Недостаточно средств. Нужно %s ₽." % _format_money(ROAD_LAMP_COST)
			return
		if not world.add_road_lamp(cell):
			economy.add_money(ROAD_LAMP_COST, "Возврат за отменённую установку фонаря")
			road_tool_status_label.text = "Не удалось установить фонарь. Деньги возвращены."
			return
		progression_service.add_progress(3, 0, "Установлен уличный фонарь")
		road_tool_status_label.text = "Фонарь установлен! −%s ₽." % _format_money(ROAD_LAMP_COST)
		_save_game()
		return
	if world.road_edit_action == "upgrade":
		if not world.can_upgrade_road_surface(cell):
			road_tool_status_label.text = "Здесь нет стандартной дороги для асфальтирования."
			return
		if not economy.try_spend(ROAD_ASPHALT_COST, "Асфальтирование дороги"):
			road_tool_status_label.text = "Недостаточно средств. Нужно %s ₽." % _format_money(ROAD_ASPHALT_COST)
			return
		if not world.upgrade_road_surface(cell):
			economy.add_money(ROAD_ASPHALT_COST, "Возврат за отменённое асфальтирование")
			road_tool_status_label.text = "Не удалось обновить покрытие. Деньги возвращены."
			return
		progression_service.add_progress(5, 0, "Улучшено дорожное покрытие")
		road_tool_status_label.text = "Асфальт уложен! −%s ₽." % _format_money(ROAD_ASPHALT_COST)
		_save_game()
		return
	if world.road_edit_action == "remove":
		if not world.can_remove_road_cell(cell):
			road_tool_status_label.text = "Нельзя снять этот сегмент: он отсутствует или его удаление разорвёт дорожную сеть."
			return
		var refund_allowed := world.is_player_built_road_cell(cell)
		if not world.remove_road_cell(cell):
			road_tool_status_label.text = "Не удалось демонтировать дорогу. Изменений нет."
			return
		if refund_allowed:
			economy.add_money(ROAD_REMOVAL_REFUND, "Возврат за демонтаж дороги")
			road_tool_status_label.text = "Сегмент снят. Возвращено %s ₽." % _format_money(ROAD_REMOVAL_REFUND)
		else:
			road_tool_status_label.text = "Стартовая дорога демонтирована. Возврат за неё не предусмотрен."
		_save_game()
		return
	if not world.can_build_road_cell(cell):
		road_tool_status_label.text = "Здесь нельзя построить дорогу: выбери свободную клетку рядом с существующей сетью."
		return
	if not economy.try_spend(ROAD_CELL_COST, "Прокладка дороги"):
		road_tool_status_label.text = "Недостаточно средств. Нужно %s ₽." % _format_money(ROAD_CELL_COST)
		return
	if not world.add_road_cell(cell):
		economy.add_money(ROAD_CELL_COST, "Возврат за отменённую прокладку дороги")
		road_tool_status_label.text = "Не удалось добавить дорогу. Деньги возвращены."
		return
	progression_service.add_progress(5, 0, "Построен участок дорожной сети")
	road_tool_status_label.text = "Дорога построена! −%s ₽. Можно продолжать." % _format_money(ROAD_CELL_COST)
	_save_game()

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
	business_status_label.visible = false
	business_button.visible = false
	business_upgrade_button.visible = false
	business_lease_button.visible = false
	business_type_selector.visible = false
	business_schedule_selector.visible = false
	household_actions_grid.visible = false
	household_actions_heading.visible = false
	member_autonomy_container.visible = false
	autonomy_toggle_button.visible = false
	plot_title.text = plot_name
	if kind == "locked":
		var level_ready := progression_service.get_level() >= EAST_QUARTER_REQUIRED_LEVEL
		var reputation_ready := progression_service.reputation >= EAST_QUARTER_REQUIRED_REPUTATION
		plot_description.text = "Восточный квартал откроется, когда район достигнет 3-го уровня и репутации 20. После выполнения условий потребуется оплатить покупку территории."
		status_label.text = "Требования: уровень %d/%d • репутация %d/%d\nСтоимость: ₽ %s" % [progression_service.get_level(), EAST_QUARTER_REQUIRED_LEVEL, progression_service.reputation, EAST_QUARTER_REQUIRED_REPUTATION, _format_money(world.get_quarter_purchase_cost())]
		build_button.text = "Открыть восточный квартал"
		build_button.disabled = not level_ready or not reputation_ready or economy.balance < world.get_quarter_purchase_cost()
	elif kind == "unowned":
		var land_cost := world.get_plot_purchase_cost(plot_id)
		plot_description.text = "Участок доступен для покупки. После приобретения здесь можно будет построить дом и заселить семью либо подготовить площадку под магазин."
		status_label.text = "Покупка земли: ₽ %s" % _format_money(land_cost)
		build_button.text = "Купить участок"
		build_button.disabled = land_cost < 0 or economy.balance < land_cost
	elif kind == "home" and plot_id == 0:
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
			if current_family.is_empty():
				var business := business_service.get_business(plot_id)
				business_status_label.visible = true
				business_button.visible = true
				if business.is_empty():
					business_schedule_selector.visible = false
					business_status_label.text = "Выбери специализацию помещения. У каждого заведения своя стоимость открытия, средний чек и ежедневные расходы."
					business_type_selector.visible = true
					var selected_type := str(business_type_selector.get_item_metadata(business_type_selector.selected))
					var opening_cost := business_service.get_opening_cost(selected_type)
					business_button.text = "Открыть: %s — ₽ %s" % [business_service.get_business_type_title(selected_type), _format_money(opening_cost)]
					business_button.disabled = economy.balance < opening_cost
				else:
					resident_button.visible = false
					resident_label.visible = false
					business_type_selector.visible = false
					var active := bool(business.get("active", false))
					var leased := business_service.is_business_leased(plot_id)
					var daily_rent := business_service.get_daily_rent(plot_id)
					var business_type := str(business.get("type", "corner_shop"))
					var business_title := business_service.get_business_type_title(business_type)
					var daily_customers := int(business.get("last_daily_customers", 80))
					var daily_revenue := int(business.get("last_daily_revenue", business_service.get_daily_revenue()))
					var upgrade_level := business_service.get_business_upgrade_level(plot_id)
					var business_reputation := business_service.get_business_reputation(plot_id)
					var reputation_change := business_service.get_business_reputation_change(plot_id)
					var reputation_trend := "+1 за сутки" if reputation_change > 0 else ("−1 за сутки" if reputation_change < 0 else "без изменений")
					var daily_expenses := business_service.get_business_daily_expenses(plot_id)
					var daily_profit := daily_revenue - daily_expenses
					var lifetime_customers := int(business.get("total_customers", 0))
					var lifetime_revenue := int(business.get("total_revenue", 0))
					var lifetime_expenses := int(business.get("total_operating_costs", 0))
					var lifetime_paid_expenses := int(business.get("total_operating_costs_paid", 0))
					var business_unpaid_expenses := int(business.get("unpaid_operating_costs", 0))
					var lifetime_result := lifetime_revenue - lifetime_expenses
					var lifetime_rent := int(business.get("total_rent_received", 0))
					var schedule_id := business_service.get_business_schedule(plot_id)
					var schedule_title := business_service.get_business_schedule_title(schedule_id)
					business_schedule_selector.visible = not leased
					for schedule_index in business_schedule_selector.item_count:
						if str(business_schedule_selector.get_item_metadata(schedule_index)) == schedule_id:
							business_schedule_selector.select(schedule_index)
							break
					if leased:
						business_status_label.text = "%s • СДАНО В АРЕНДУ\nАрендатор платит: ₽ %s за игровые сутки\nПолучено от этого помещения: ₽ %s\nОбщая аренда района: ₽ %s\nРепутация: %d/100 (%s)\nГрафик арендатора: %s\nСодержание и операционные расходы оплачивает арендатор.\nПривлекательность: уровень %d/2" % [
							business_title.to_upper(),
							_format_money(daily_rent),
							_format_money(lifetime_rent),
							_format_money(business_service.total_rent_received),
							business_reputation,
							reputation_trend,
							schedule_title,
							upgrade_level
						]
					else:
						business_status_label.text = "%s • %s\nРепутация: %d/100 (%s)\nПривлекательность: уровень %d/2\nГрафик: %s\nПосетители: %d/день • всего: %s\nВыручка: ₽ %s/день • расходы: ₽ %s/день • результат: %s ₽/день\nЗа всё время: выручка ₽ %s • начислено ₽ %s • оплачено ₽ %s • итог %s ₽\nДолг заведения: ₽ %s" % [
							business_title.to_upper(),
							"РАБОТАЕТ" if active else "ПРИОСТАНОВЛЕН",
							business_reputation,
							reputation_trend,
							upgrade_level,
							schedule_title,
							daily_customers,
							_format_money(lifetime_customers),
							_format_money(daily_revenue),
							_format_money(daily_expenses),
							"%s%s" % ["+" if daily_profit >= 0 else "−", _format_money(absi(daily_profit))],
							_format_money(lifetime_revenue),
							_format_money(lifetime_expenses),
							_format_money(lifetime_paid_expenses),
							"%s%s" % ["+" if lifetime_result >= 0 else "−", _format_money(absi(lifetime_result))],
							_format_money(business_unpaid_expenses)
						]
					business_button.visible = not leased
					business_button.text = "Приостановить заведение" if active else "Возобновить заведение"
					business_button.disabled = false
					business_lease_button.visible = true
					business_lease_button.text = "Расторгнуть договор аренды" if leased else "Сдать в аренду — ₽ %s/сутки" % _format_money(daily_rent)
					business_upgrade_button.visible = not leased
					var next_upgrade_cost := business_service.get_business_upgrade_cost(plot_id)
					if leased:
						business_upgrade_button.visible = false
					elif next_upgrade_cost > 0:
						business_upgrade_button.text = "Улучшить привлекательность — ₽ %s" % _format_money(next_upgrade_cost)
						business_upgrade_button.disabled = economy.balance < next_upgrade_cost
					else:
						business_upgrade_button.text = "Максимальная привлекательность"
						business_upgrade_button.disabled = true

func _on_business_schedule_selected(index: int) -> void:
	if selected_plot_id < 1 or index < 0 or index >= business_schedule_selector.item_count:
		return
	var schedule_id := str(business_schedule_selector.get_item_metadata(index))
	if not business_service.set_business_schedule(selected_plot_id, schedule_id):
		status_label.text = "Не удалось изменить график работы."
		return
	world.set_business_plots(business_service.get_business_visual_data(), game_time.get_hour())
	status_label.text = "График заведения изменён: %s. Новые расходы и доля спроса применятся со следующих игровых суток." % business_service.get_business_schedule_title(schedule_id)
	_save_game()
	_on_plot_selected(selected_plot_id)


func _on_business_lease_pressed() -> void:
	if selected_plot_id < 1:
		return
	var leased := business_service.is_business_leased(selected_plot_id)
	var changed := business_service.terminate_business_lease(selected_plot_id) if leased else business_service.lease_business(selected_plot_id)
	if not changed:
		status_label.text = "Не удалось изменить договор аренды."
		return
	status_label.text = "Договор аренды расторгнут. Заведение остановлено." if leased else "Помещение сдано в аренду. Арендная плата будет поступать за каждые прошедшие игровые сутки."
	world.set_business_plots(business_service.get_business_visual_data(), game_time.get_hour())
	_save_game()
	_on_plot_selected(selected_plot_id)


func _on_business_upgrade_pressed() -> void:
	if selected_plot_id < 1:
		return
	if not business_service.purchase_business_upgrade(selected_plot_id, economy):
		status_label.text = "Не удалось улучшить заведение. Проверь баланс и уровень улучшения."
		return
	status_label.text = "Заведение улучшено! Его привлекательность выросла, а ежедневные расходы увеличились на 500 ₽."
	_save_game()
	_on_plot_selected(selected_plot_id)


func _on_business_type_selected(index: int) -> void:
	if index < 0 or index >= business_type_selector.item_count:
		return
	var selected_type := str(business_type_selector.get_item_metadata(index))
	var opening_cost := business_service.get_opening_cost(selected_type)
	business_button.text = "Открыть: %s — ₽ %s" % [business_service.get_business_type_title(selected_type), _format_money(opening_cost)]
	business_button.disabled = economy.balance < opening_cost


func _on_business_action_pressed() -> void:
	if selected_plot_id < 1 or world.get_plot_kind(selected_plot_id) != "built":
		return
	if not move_in_service.is_ready(selected_plot_id) or resident_service.is_plot_occupied(selected_plot_id):
		return
	var business := business_service.get_business(selected_plot_id)
	if business.is_empty():
		var selected_type := str(business_type_selector.get_item_metadata(business_type_selector.selected))
		if not business_service.open_business(selected_plot_id, economy, selected_type):
			status_label.text = "Не удалось открыть магазин. Проверь готовность помещения и баланс района."
			return
		progression_service.add_progress(60, 4, "Открыт первый магазин у дома")
		status_label.text = "Магазин открыт! Со следующих игровых суток начнут начисляться выручка и операционные расходы."
	else:
		var next_active := not bool(business.get("active", false))
		if not business_service.set_business_active(selected_plot_id, next_active):
			return
		status_label.text = "Магазин %s." % ("возобновил работу" if next_active else "приостановлен")
	world.set_business_plots(business_service.get_business_visual_data(), game_time.get_hour())
	_save_game()
	_on_plot_selected(selected_plot_id)


func _on_resident_button_pressed() -> void:
	if selected_plot_id < 1 or world.get_plot_kind(selected_plot_id) != "built" or not business_service.get_business(selected_plot_id).is_empty():
		return
	if not move_in_service.is_ready(selected_plot_id) or resident_service.is_plot_occupied(selected_plot_id):
		return
	var available_families := resident_service.get_available_families()
	if available_families.is_empty():
		return
	var family_id := str(available_families[0]["id"])
	if resident_service.move_family_in(family_id, selected_plot_id, move_in_service.is_ready(selected_plot_id)):
		_award_district_progress(80, 10, "Заселение новой семьи")
		progression_service.unlock_achievement("first_family")
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
	_award_district_progress(50, 5, "Дом полностью подготовлен к заселению")
	progression_service.unlock_achievement("first_ready_home")
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
			_award_district_progress(100, 10, "Помощь Бабе Зине")
			progression_service.unlock_achievement("baba_helper")
			world.set_baba_home_repaired(true)
			economy.add_money(BABA_QUEST_REWARD, "Награда за помощь Бабе Зине")
			_on_plot_selected(0)
			status_label.text = "Проводка восстановлена! Баба Зина вручает награду: 150 000 ₽."
			_save_game()
			return
		return
	_on_build_pressed()

func _on_build_pressed() -> void:
	if selected_plot_id >= 0 and world.is_plot_unlocked(selected_plot_id) and not world.is_plot_owned(selected_plot_id):
		var land_cost := world.get_plot_purchase_cost(selected_plot_id)
		if land_cost < 0 or not economy.try_spend(land_cost, "Покупка земли: %s" % world.get_plot_name(selected_plot_id)):
			status_label.text = "Недостаточно средств для покупки участка."
			return
		if not world.purchase_plot(selected_plot_id):
			economy.add_money(land_cost, "Возврат: участок уже приобретён")
			status_label.text = "Не удалось оформить покупку участка."
			return
		municipal_services.set_available_plot_ids(world.get_owned_plot_ids())
		district_event_service.set_available_plot_ids(world.get_owned_plot_ids())
		status_label.text = "Участок приобретён! Теперь здесь можно строить."
		_on_plot_selected(selected_plot_id)
		_save_game()
		return
	if selected_plot_id >= 0 and not world.is_plot_unlocked(selected_plot_id):
		if progression_service.get_level() < EAST_QUARTER_REQUIRED_LEVEL or progression_service.reputation < EAST_QUARTER_REQUIRED_REPUTATION:
			status_label.text = "Сначала развей район до 3-го уровня и подними репутацию до 20."
			return
		var quarter_cost := world.get_quarter_purchase_cost()
		if not economy.try_spend(quarter_cost, "Покупка восточного квартала"):
			status_label.text = "Недостаточно средств для покупки квартала."
			return
		if not world.unlock_east_quarter():
			economy.add_money(quarter_cost, "Возврат: квартал уже открыт")
			status_label.text = "Квартал уже открыт."
			return
		municipal_services.set_available_plot_ids(world.get_owned_plot_ids())
		district_event_service.set_available_plot_ids(world.get_owned_plot_ids())
		status_label.text = "Восточный квартал открыт! Четыре участка теперь можно покупать по отдельности."
		_on_plot_selected(selected_plot_id)
		_save_game()
		return
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
		var remaining_work := maxf(0.0, float(project.get("duration", 0.0)) - float(project.get("elapsed", 0.0)))
		var remaining := maxi(0, int(ceil(remaining_work / maxf(construction_service.weather_speed_multiplier, 0.01))))
		status_label.text = "%s • %d%% • осталось %d сек." % [stage, int(progress * 100.0), remaining]
	var current_second := int(Time.get_ticks_msec() / 1000)
	if current_second % 5 == 0 and current_second != last_construction_save_second:
		last_construction_save_second = current_second
		_save_game()

func _on_construction_completed(plot_id: int) -> void:
	world.finish_plot(plot_id)
	_award_district_progress(120, 5, "Завершено строительство дома")
	progression_service.unlock_achievement("first_house")
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
		"municipal_services": municipal_services.get_save_data(),
		"district_progression": progression_service.get_save_data(),
		"district_events": district_event_service.get_save_data(),
		"weather": weather_service.get_save_data(),
		"businesses": business_service.get_save_data(),
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
	is_loading_game = true
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
	var municipal_data: Variant = data.get("municipal_services", {})
	if municipal_data is Dictionary and not municipal_data.is_empty():
		municipal_services.load_save_data(municipal_data)
	else:
		municipal_services.initialize_day(game_time.get_day())
	var progression_data: Variant = data.get("district_progression", {})
	if progression_data is Dictionary:
		progression_service.load_save_data(progression_data)
	var event_data: Variant = data.get("district_events", {})
	if event_data is Dictionary and not event_data.is_empty():
		district_event_service.load_save_data(event_data)
	else:
		district_event_service.initialize_day(game_time.get_day())
	var weather_data: Variant = data.get("weather", {})
	if weather_data is Dictionary and not weather_data.is_empty():
		weather_service.load_save_data(weather_data)
	else:
		weather_service.initialize_day(game_time.get_day())
	var businesses_data: Variant = data.get("businesses", {})
	if businesses_data is Dictionary and not businesses_data.is_empty():
		business_service.load_save_data(businesses_data)
	else:
		# Older saves start the business calendar on the current day without back-charging.
		business_service.initialize_day(game_time.get_day())
	# Backfill one-time achievements for milestones completed in older saves.
	if baba_wiring_repaired:
		progression_service.unlock_achievement("baba_helper")
	for plot_id in range(1, world.plot_states.size()):
		if world.get_plot_kind(plot_id) == "built":
			progression_service.unlock_achievement("first_house")
		if move_in_service.is_ready(plot_id):
			progression_service.unlock_achievement("first_ready_home")
	if resident_service.get_total_resident_count() > 0:
		progression_service.unlock_achievement("first_family")
	if municipal_services.get_total_employee_count() > 0:
		progression_service.unlock_achievement("first_worker")
	is_loading_game = false
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

