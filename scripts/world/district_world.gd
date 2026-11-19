extends Node2D

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
var construction_animation_time: float = 0.0
var pedestrian_time: float = 0.0
var resident_groups: Array = []

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
	construction_animation_time += delta
	pedestrian_time += delta
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
	_draw_residents()

func set_resident_groups(groups: Array) -> void:
	resident_groups = groups.duplicate(true)
	queue_redraw()

func _draw_residents() -> void:
	for group in resident_groups:
		if not group is Dictionary:
			continue
		var plot_id := int(group.get("plot_id", -1))
		if plot_id < 1 or plot_id >= PLOT_RECTS.size():
			continue
		var activity := str(group.get("activity", "at_home"))
		# Sleeping and work hours intentionally keep residents off the visible street.
		if activity == "sleeping" or activity == "at_work":
			continue
		var members := clampi(int(group.get("members_count", 0)), 0, 8)
		var home_x := PLOT_RECTS[plot_id].position.x + 108.0
		var home_y := PLOT_RECTS[plot_id].position.y + 106.0
		if activity == "at_home":
			for member_index in members:
				var home_position := Vector2(home_x + float(member_index - 1) * 12.0, home_y + 14.0)
				_draw_pedestrian(home_position, member_index)
			continue
		var sidewalk_y := 325.0 if plot_id < 4 else 430.0
		var route := PackedVector2Array([
			Vector2(home_x, home_y),
			Vector2(home_x, sidewalk_y),
			Vector2(565.0, sidewalk_y),
			Vector2(565.0, 520.0),
			Vector2(565.0, sidewalk_y),
			Vector2(home_x, sidewalk_y),
			Vector2(home_x, home_y)
		])
		var total_length := 0.0
		for i in range(route.size() - 1):
			total_length += route[i].distance_to(route[i + 1])
		for member_index in members:
			var distance := fposmod(pedestrian_time * 34.0 + float(member_index) * 31.0, maxf(1.0, total_length))
			var person_position := route[0]
			for i in range(route.size() - 1):
				var segment_length := route[i].distance_to(route[i + 1])
				if distance <= segment_length:
					person_position = route[i].lerp(route[i + 1], distance / maxf(1.0, segment_length))
					break
				distance -= segment_length
			_draw_pedestrian(person_position, member_index)

func _draw_pedestrian(pos: Vector2, variant: int) -> void:
	var shirt_colors := [Color("#d58c68"), Color("#6e91a3"), Color("#d5bd78")]
	var shirt: Color = shirt_colors[variant % shirt_colors.size()]
	draw_ellipse(pos + Vector2(1, 7), Vector2(5, 2.5), Color("#34443a", 0.28))
	draw_circle(pos + Vector2(0, -5), 3.2, Color("#e7c6a3"))
	draw_rect(Rect2(pos + Vector2(-2.8, -2), Vector2(5.6, 8)), shirt, true)
	draw_line(pos + Vector2(-1.5, 5), pos + Vector2(-2.5, 9), Color("#39433f"), 1.8)
	draw_line(pos + Vector2(1.5, 5), pos + Vector2(2.5, 9), Color("#39433f"), 1.8)

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
	var p := clampf(progress, 0.0, 1.0)
	var base := rect.position + Vector2(25, 24)
	var phase := 0
	if p >= 0.96:
		phase = 6
	elif p >= 0.86:
		phase = 5
	elif p >= 0.72:
		phase = 4
	elif p >= 0.55:
		phase = 3
	elif p >= 0.28:
		phase = 2
	elif p >= 0.12:
		phase = 1

	# Site boundary, soil and a compact materials staging area.
	draw_rect(Rect2(base - Vector2(8, 5), Vector2(156, 116)), Color("#9a805e"))
	draw_rect(Rect2(base - Vector2(3, 1), Vector2(146, 108)), Color("#c7ad7e"))
	draw_rect(Rect2(base + Vector2(112, 76), Vector2(28, 22)), Color("#8b6849"))
	for i in 4:
		draw_line(base + Vector2(114, 80 + i * 5), base + Vector2(137, 80 + i * 5), Color("#e2c18a"), 2.0)

	# Survey stakes and safety tape remain visible during the early phases.
	if phase <= 1:
		for point in [Vector2(8, 8), Vector2(132, 8), Vector2(8, 92), Vector2(132, 92)]:
			draw_line(base + point, base + point + Vector2(0, -15), Color("#79543a"), 3.0)
			draw_circle(base + point + Vector2(0, -15), 3, Color("#f0d27e"))
		draw_line(base + Vector2(8, 15), base + Vector2(132, 15), Color("#e4c66f"), 2.0)
		draw_line(base + Vector2(8, 86), base + Vector2(132, 86), Color("#e4c66f"), 2.0)

	# Foundation slab and footing trenches.
	if phase >= 1:
		draw_rect(Rect2(base + Vector2(17, 25), Vector2(108, 68)), Color("#777d75"))
		draw_rect(Rect2(base + Vector2(22, 30), Vector2(98, 58)), Color("#b8b7a7"))
		for x in range(25, 120, 18):
			draw_line(base + Vector2(x, 31), base + Vector2(x, 87), Color("#92988d"), 1.0)

	# Brick walls rise in sections; scaffolding is added as the shell grows.
	if phase >= 2:
		var wall_progress := clampf((p - 0.28) / 0.27, 0.0, 1.0)
		var wall_height := lerpf(8.0, 55.0, wall_progress)
		draw_rect(Rect2(base + Vector2(28, 82 - wall_height), Vector2(86, wall_height)), Color("#c99a70"))
		for y in range(0, int(wall_height), 9):
			draw_line(base + Vector2(28, 82 - float(y)), base + Vector2(114, 82 - float(y)), Color("#a9785b"), 1.0)
		for x in [28.0, 114.0]:
			draw_line(base + Vector2(x, 23), base + Vector2(x, 87), Color("#8b6748"), 3.0)
			draw_line(base + Vector2(x - 7, 38), base + Vector2(x + 7, 38), Color("#8b6748"), 2.0)
			draw_line(base + Vector2(x - 7, 62), base + Vector2(x + 7, 62), Color("#8b6748"), 2.0)

	# Roof frame, then finished roof planes.
	if phase >= 3:
		var roof_progress := clampf((p - 0.55) / 0.17, 0.0, 1.0)
		var roof_color := Color("#875647").lerp(Color("#70443b"), roof_progress)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(18, 32), base + Vector2(71, 4), base + Vector2(124, 32)
		]), roof_color)
		draw_line(base + Vector2(71, 5), base + Vector2(71, 31), Color("#d0a17b"), 3.0)
		for x in [43.0, 58.0, 84.0, 99.0]:
			draw_line(base + Vector2(x, 22), base + Vector2(x, 34), Color("#c08a68"), 2.0)

	# Windows and door appear after the roof is in place.
	if phase >= 4:
		draw_rect(Rect2(base + Vector2(39, 49), Vector2(19, 18)), Color("#e9d7b7"))
		draw_rect(Rect2(base + Vector2(91, 49), Vector2(19, 18)), Color("#e9d7b7"))
		draw_rect(Rect2(base + Vector2(41, 51), Vector2(15, 14)), Color("#91b8bd"))
		draw_rect(Rect2(base + Vector2(93, 51), Vector2(15, 14)), Color("#91b8bd"))
		draw_rect(Rect2(base + Vector2(66, 62), Vector2(13, 27)), Color("#76513d"))
		draw_rect(Rect2(base + Vector2(66, 62), Vector2(13, 27)), Color("#76513d"), false, 2.0)

	# Utility work: cable, water pipe and a small service trench.
	if phase >= 5:
		draw_line(base + Vector2(12, 99), base + Vector2(139, 99), Color("#477b9a"), 4.0)
		draw_line(base + Vector2(12, 104), base + Vector2(139, 104), Color("#c5a34f"), 3.0)
		draw_circle(base + Vector2(20, 99), 4, Color("#d5e1d9"))
		draw_circle(base + Vector2(130, 104), 4, Color("#e6d39a"))

	# Final facade, yard path and warm illuminated windows.
	if phase >= 6:
		draw_rect(Rect2(base + Vector2(39, 49), Vector2(19, 18)), Color("#f3d47b"))
		draw_rect(Rect2(base + Vector2(91, 49), Vector2(19, 18)), Color("#f3d47b"))
		draw_rect(Rect2(base + Vector2(8, 91), Vector2(128, 13)), Color("#83a16e"))
		draw_rect(Rect2(base + Vector2(69, 89), Vector2(9, 15)), Color("#d4c09b"))
		_draw_bush(base + Vector2(20, 93))
		_draw_bush(base + Vector2(125, 93))

	# A gently pulsing site beacon makes active construction feel alive.
	var pulse := 0.5 + 0.5 * sin(construction_animation_time * 3.2)
	draw_circle(base + Vector2(143, 4), 5.0 + pulse * 2.0, Color("#f4d47a", 0.18 + pulse * 0.18))
	draw_circle(base + Vector2(143, 4), 3.0, Color("#f4d47a"))

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
