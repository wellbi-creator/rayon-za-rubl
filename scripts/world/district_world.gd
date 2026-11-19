extends Node2D
class_name DistrictWorld

signal plot_selected(plot_id: int)

const PLOT_RECTS: Array[Rect2] = [
	Rect2(115, 145, 190, 150),
	Rect2(365, 145, 190, 150),
	Rect2(615, 145, 190, 150),
	Rect2(865, 145, 190, 150),
	Rect2(240, 405, 190, 150),
	Rect2(740, 405, 190, 150)
]
const PLOT_NAMES: Array[String] = [
	"Дом Бабы Зины", "Участок №2", "Участок №3",
	"Участок №4", "Участок №5", "Участок №6"
]

var plot_states: Array[Dictionary] = []
var selected_plot: int = -1
var camera: Camera2D
var dragging: bool = false
var touch_active: bool = false
var touch_start_position: Vector2 = Vector2.ZERO
var touch_moved: bool = false
var traffic_time: float = 0.0
var car_positions: Array[float] = [80.0, 880.0]
var baba_home_repaired: bool = false

func _ready() -> void:
	for i in PLOT_RECTS.size():
		plot_states.append({"kind": "home" if i == 0 else "empty", "progress": 0.0})
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	camera.zoom = Vector2.ONE
	add_child(camera)
	camera.make_current()
	queue_redraw()

func _process(delta: float) -> void:
	traffic_time += delta
	car_positions[0] = wrapf(car_positions[0] + delta * 72.0, -150.0, 1450.0)
	car_positions[1] = wrapf(car_positions[1] - delta * 54.0, -150.0, 1450.0)
	queue_redraw()

func _draw() -> void:
	# Grass base and subtle ground texture.
	draw_rect(Rect2(-500, -500, 2280, 1720), Color("#78966d"))
	for x in range(-400, 1800, 48):
		for y in range(-400, 1400, 48):
			draw_circle(Vector2(x + ((y / 48) % 2) * 18, y), 1.5, Color("#88a77b", 0.35))

	# Main asphalt road with sidewalks and lane markings.
	draw_rect(Rect2(-100, 330, 1480, 94), Color("#c4bda5"))
	draw_rect(Rect2(-100, 340, 1480, 74), Color("#515b5b"))
	for x in range(-60, 1400, 82):
		draw_rect(Rect2(x, 375, 42, 4), Color("#e7d9a8"))

	# Small connecting road.
	draw_rect(Rect2(570, -100, 78, 850), Color("#c4bda5"))
	draw_rect(Rect2(578, -100, 62, 850), Color("#596262"))
	for y in range(-60, 760, 82):
		draw_rect(Rect2(607, y, 4, 42), Color("#e7d9a8"))

	# Trees and garden details.
	_draw_tree(Vector2(55, 110))
	_draw_tree(Vector2(1080, 115))
	_draw_tree(Vector2(1100, 500))
	_draw_tree(Vector2(90, 520))
	_draw_tree(Vector2(485, 590))
	_draw_tree(Vector2(980, 620))

	for i in PLOT_RECTS.size():
		_draw_plot(i)

	# Decorative park patch.
	draw_rect(Rect2(475, 465, 180, 115), Color("#6e9565"), true)
	draw_circle(Vector2(565, 520), 27, Color("#d4c18b"))
	draw_circle(Vector2(565, 520), 19, Color("#83a76e"))
	draw_circle(Vector2(525, 490), 8, Color("#b5c98b"))
	draw_circle(Vector2(615, 550), 8, Color("#b5c98b"))

	_draw_neighborhood_details()
	_draw_car(Vector2(car_positions[0], 354), Color("#c96e4e"), false)
	_draw_car(Vector2(car_positions[1], 397), Color("#d7d6c9"), true)

func _draw_plot(plot_id: int) -> void:
	var rect := PLOT_RECTS[plot_id]
	var state: Dictionary = plot_states[plot_id]
	var is_selected := selected_plot == plot_id
	draw_rect(rect.grow(5), Color("#d8d0b5", 0.55), true)
	draw_rect(rect, Color("#9eb184"), true)
	draw_rect(rect, Color("#e4d8b7") if is_selected else Color("#c9c3a3"), false, 3.0)

	if state["kind"] == "home":
		_draw_house(rect.position + Vector2(27, 16), false, 0.0)
		if plot_id == 0 and baba_home_repaired:
			_draw_repaired_home_lights(rect.position + Vector2(27, 16))
	elif state["kind"] == "building":
		_draw_construction(rect, float(state["progress"]))
	elif state["kind"] == "built":
		_draw_house(rect.position + Vector2(27, 16), true, 0.0)
	else:
		draw_rect(Rect2(rect.position + Vector2(70, 58), Vector2(50, 34)), Color("#a9bf91", 0.7), true)
		draw_circle(rect.position + Vector2(95, 75), 3, Color("#e2d6a9"))

	if is_selected:
		draw_rect(rect.grow(7), Color("#f6d77a"), false, 4.0)

func _draw_house(pos: Vector2, finished: bool, progress: float) -> void:
	# Yard and small path.
	draw_rect(Rect2(pos + Vector2(8, 86), Vector2(145, 34)), Color("#83a36f"))
	draw_rect(Rect2(pos + Vector2(64, 82), Vector2(18, 42)), Color("#c7b99a"))
	# Warm walls and roof.
	draw_rect(Rect2(pos + Vector2(22, 35), Vector2(116, 70)), Color("#e7d3ad"))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(10, 42), pos + Vector2(80, 2), pos + Vector2(150, 42)
	]), Color("#854f43"))
	draw_rect(Rect2(pos + Vector2(36, 55), Vector2(24, 23)), Color("#8bb7bd"))
	draw_rect(Rect2(pos + Vector2(101, 55), Vector2(24, 23)), Color("#8bb7bd"))
	draw_rect(Rect2(pos + Vector2(73, 75), Vector2(18, 30)), Color("#78533e"))
	draw_circle(pos + Vector2(81, 90), 2, Color("#e8c66f"))
	# Window frames, chimney, flower boxes and garden shrubs.
	draw_rect(Rect2(pos + Vector2(33, 52), Vector2(30, 29)), Color("#f0e2c4"), false, 3.0)
	draw_rect(Rect2(pos + Vector2(98, 52), Vector2(30, 29)), Color("#f0e2c4"), false, 3.0)
	draw_line(pos + Vector2(48, 53), pos + Vector2(48, 80), Color("#f0e2c4"), 2.0)
	draw_line(pos + Vector2(113, 53), pos + Vector2(113, 80), Color("#f0e2c4"), 2.0)
	draw_rect(Rect2(pos + Vector2(112, 8), Vector2(12, 25)), Color("#a77a60"))
	draw_rect(Rect2(pos + Vector2(31, 108), Vector2(24, 8)), Color("#d58c75"))
	draw_rect(Rect2(pos + Vector2(112, 108), Vector2(24, 8)), Color("#d58c75"))
	_draw_bush(pos + Vector2(17, 111))
	_draw_bush(pos + Vector2(145, 111))
	if finished:
		draw_rect(Rect2(pos + Vector2(36, 55), Vector2(24, 23)), Color("#f4d77b"))
		draw_rect(Rect2(pos + Vector2(101, 55), Vector2(24, 23)), Color("#f4d77b"))

func _draw_construction(rect: Rect2, progress: float) -> void:
	var base := rect.position + Vector2(25, 25)
	draw_rect(Rect2(base, Vector2(140, 105)), Color("#b99a6d"))
	draw_rect(Rect2(base + Vector2(8, 8), Vector2(124, 89)), Color("#d0b184"))
	var wall_height := lerp(12.0, 64.0, clampf(progress, 0.0, 1.0))
	draw_rect(Rect2(base + Vector2(25, 72 - wall_height), Vector2(90, wall_height)), Color("#d9c39b"))
	draw_line(base + Vector2(12, 12), base + Vector2(130, 12), Color("#8d6246"), 5.0)
	draw_rect(Rect2(base + Vector2(10, 96), Vector2(120, 5)), Color("#8d6246"))

func _draw_tree(pos: Vector2) -> void:
	draw_ellipse(pos + Vector2(3, 17), Vector2(22, 8), Color("#526d4e", 0.45))
	draw_rect(Rect2(pos + Vector2(-3, 0), Vector2(6, 25)), Color("#76553c"))
	draw_circle(pos, 18, Color("#4e7951"))
	draw_circle(pos + Vector2(-9, -5), 11, Color("#638e5c"))
	draw_circle(pos + Vector2(9, -7), 10, Color("#78a36a"))

func _draw_neighborhood_details() -> void:
	# Sidewalk joints, pedestrian crossing and small street furniture.
	for x in range(-60, 1400, 38):
		draw_line(Vector2(x, 333), Vector2(x + 18, 333), Color("#e5ddc9", 0.55), 2.0)
		draw_line(Vector2(x, 421), Vector2(x + 18, 421), Color("#e5ddc9", 0.55), 2.0)
	for i in 5:
		draw_rect(Rect2(550 + i * 15, 343, 8, 22), Color("#eee7d5", 0.9))
		draw_rect(Rect2(550 + i * 15, 389, 8, 22), Color("#eee7d5", 0.9))
	# Warm wooden benches in the park.
	draw_rect(Rect2(510, 535, 34, 5), Color("#8a5e40"))
	draw_rect(Rect2(510, 542, 34, 3), Color("#604936"))
	draw_rect(Rect2(590, 485, 34, 5), Color("#8a5e40"))
	draw_rect(Rect2(590, 492, 34, 3), Color("#604936"))
	# Flower beds and shrubs make empty plots feel maintained.
	for p in [Vector2(330, 185), Vector2(825, 185), Vector2(825, 475), Vector2(180, 575)]:
		_draw_flower_bed(p)
	# Street lamps along both sides of the main road.
	for x in [160.0, 455.0, 780.0, 1040.0, 1260.0]:
		_draw_lamp(Vector2(x, 322))
		_draw_lamp(Vector2(x + 105.0, 432))

func _draw_lamp(pos: Vector2) -> void:
	draw_circle(pos + Vector2(0, 3), 9, Color("#52634c", 0.25))
	draw_rect(Rect2(pos + Vector2(-2, -25), Vector2(4, 27)), Color("#454e49"))
	draw_line(pos + Vector2(0, -24), pos + Vector2(10, -31), Color("#454e49"), 3.0)
	draw_circle(pos + Vector2(11, -31), 5, Color("#f3d98e"))
	draw_circle(pos + Vector2(11, -31), 9, Color("#f3d98e", 0.13))

func _draw_flower_bed(pos: Vector2) -> void:
	draw_rect(Rect2(pos, Vector2(34, 15)), Color("#6e8d59"))
	for i in 5:
		var flower_pos := pos + Vector2(5 + i * 6, 7)
		draw_circle(flower_pos, 2.5, Color("#e7c6a0") if i % 2 == 0 else Color("#e8d98f"))
		draw_circle(flower_pos + Vector2(0, 3), 2, Color("#527a4b"))

func _draw_bush(pos: Vector2) -> void:
	draw_circle(pos, 8, Color("#4e784e"))
	draw_circle(pos + Vector2(-4, -2), 5, Color("#6f985e"))
	draw_circle(pos + Vector2(4, -3), 5, Color("#82a96a"))

func _draw_car(pos: Vector2, body_color: Color, facing_left: bool) -> void:
	# Compact top-down car with shadow, roof glass and visible wheels.
	var direction := -1.0 if facing_left else 1.0
	draw_rect(Rect2(pos + Vector2(-18, -7), Vector2(42, 20)), Color("#33413d", 0.35))
	draw_rect(Rect2(pos + Vector2(-21, -9), Vector2(42, 18)), body_color)
	draw_rect(Rect2(pos + Vector2(-10, -7), Vector2(20, 14)), Color("#a9c5c5"))
	draw_rect(Rect2(pos + Vector2(-7, -6), Vector2(14, 12)), Color("#d2e0d9"))
	draw_rect(Rect2(pos + Vector2(-18, -11), Vector2(7, 4)), Color("#303a38"))
	draw_rect(Rect2(pos + Vector2(12, -11), Vector2(7, 4)), Color("#303a38"))
	draw_rect(Rect2(pos + Vector2(-18, 7), Vector2(7, 4)), Color("#303a38"))
	draw_rect(Rect2(pos + Vector2(12, 7), Vector2(7, 4)), Color("#303a38"))
	var front_x := 19.0 * direction
	draw_rect(Rect2(pos + Vector2(front_x - 2.0, -6), Vector2(3, 4)), Color("#f6e5a7"))
	draw_rect(Rect2(pos + Vector2(front_x - 2.0, 3), Vector2(3, 4)), Color("#f6e5a7"))

func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * float(i) / 16.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_at(get_global_mouse_position())
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.12)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(0.89)
	elif event is InputEventMouseMotion and dragging:
		camera.position -= event.relative / camera.zoom.x
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_active = true
			touch_start_position = event.position
			touch_moved = false
		else:
			if touch_active and not touch_moved:
				var world_position := get_viewport().get_canvas_transform().affine_inverse() * event.position
				_select_at(world_position)
			touch_active = false
	elif event is InputEventScreenDrag:
		if touch_active:
			if event.position.distance_to(touch_start_position) > 12.0:
				touch_moved = true
			if touch_moved:
				camera.position -= event.relative / camera.zoom.x

func _zoom(factor: float) -> void:
	var next_zoom := clampf(camera.zoom.x * factor, 0.65, 1.8)
	camera.zoom = Vector2(next_zoom, next_zoom)

func _select_at(world_position: Vector2) -> void:
	for i in PLOT_RECTS.size():
		if PLOT_RECTS[i].has_point(world_position):
			selected_plot = i
			plot_selected.emit(i)
			queue_redraw()
			return

func get_save_data() -> Dictionary:
	return {
		"plot_states": plot_states.duplicate(true),
		"baba_home_repaired": baba_home_repaired
	}

func load_save_data(data: Dictionary) -> void:
	var saved_plots: Variant = data.get("plot_states", [])
	if saved_plots is Array and saved_plots.size() == PLOT_RECTS.size():
		plot_states.clear()
		for entry in saved_plots:
			if entry is Dictionary:
				var kind := str(entry.get("kind", "empty"))
				if kind not in ["home", "empty", "building", "built"]:
					kind = "empty"
				plot_states.append({
					"kind": kind,
					"progress": clampf(float(entry.get("progress", 0.0)), 0.0, 1.0)
				})
			else:
				plot_states.append({"kind": "empty", "progress": 0.0})
	baba_home_repaired = bool(data.get("baba_home_repaired", false))
	queue_redraw()

func set_baba_home_repaired(repaired: bool) -> void:
	baba_home_repaired = repaired
	queue_redraw()

func _draw_repaired_home_lights(pos: Vector2) -> void:
	# A small visual reward: the repaired home now glows warmly from within.
	draw_circle(pos + Vector2(48, 66), 17, Color("#f5d77c", 0.12))
	draw_circle(pos + Vector2(113, 66), 17, Color("#f5d77c", 0.12))
	draw_rect(Rect2(pos + Vector2(36, 55), Vector2(24, 23)), Color("#f6d77e"))
	draw_rect(Rect2(pos + Vector2(101, 55), Vector2(24, 23)), Color("#f6d77e"))
	draw_line(pos + Vector2(48, 55), pos + Vector2(48, 78), Color("#8d7650"), 2.0)
	draw_line(pos + Vector2(113, 55), pos + Vector2(113, 78), Color("#8d7650"), 2.0)

func set_plot_building(plot_id: int, progress: float) -> void:
	if plot_id < 0 or plot_id >= plot_states.size():
		return
	plot_states[plot_id] = {"kind": "building", "progress": clampf(progress, 0.0, 1.0)}
	queue_redraw()

func finish_plot(plot_id: int) -> void:
	if plot_id < 0 or plot_id >= plot_states.size():
		return
	plot_states[plot_id] = {"kind": "built", "progress": 1.0}
	queue_redraw()

func get_plot_kind(plot_id: int) -> String:
	if plot_id < 0 or plot_id >= plot_states.size():
		return ""
	return str(plot_states[plot_id]["kind"])

func get_plot_name(plot_id: int) -> String:
	if plot_id < 0 or plot_id >= PLOT_NAMES.size():
		return "Участок"
	return PLOT_NAMES[plot_id]
