extends Node2D
class_name DistrictWorld

signal plot_selected(plot_id: int)

const Grid = preload("res://scripts/world/isometric_grid.gd")
const TILE := Vector2(128.0, 64.0)
const MAP_WIDTH := 9
const MAP_HEIGHT := 7
const PLOT_CELLS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(2, 5), Vector2i(6, 1),
	Vector2i(7, 5), Vector2i(1, 5), Vector2i(7, 1)
]
const PLOT_NAMES: Array[String] = [
	"Дом Бабы Зины", "Участок №2", "Участок №3",
	"Участок №4", "Участок №5", "Участок №6"
]

var plot_states: Array[Dictionary] = []
var selected_plot: int = -1
var camera: Camera2D
var resident_groups: Array = []
var baba_home_repaired := false
var construction_animation_time := 0.0
var pedestrian_time := 0.0
var drag_active := false
var touch_active := false
var touch_moved := false
var touch_start := Vector2.ZERO
var camera_target_position := Vector2.ZERO
var camera_target_zoom := 0.82
var camera_smoothing := 10.0
var keyboard_pan_speed := 520.0
var camera_min_zoom := 0.55
var camera_max_zoom := 1.6

func _ready() -> void:
	for i in PLOT_CELLS.size():
		plot_states.append({"kind": "home" if i == 0 else "empty", "progress": 0.0})
	camera = Camera2D.new()
	camera.position = Grid.grid_to_world(Vector2i(4, 3), TILE)
	camera_target_position = camera.position
	camera.zoom = Vector2(camera_target_zoom, camera_target_zoom)
	add_child(camera)
	camera.make_current()
	queue_redraw()

func _process(delta: float) -> void:
	construction_animation_time += delta
	pedestrian_time += delta
	_update_keyboard_camera(delta)
	_clamp_camera_target()
	var weight := 1.0 - exp(-camera_smoothing * delta)
	camera.position = camera.position.lerp(camera_target_position, weight)
	var zoom_value := lerpf(camera.zoom.x, camera_target_zoom, weight)
	camera.zoom = Vector2(zoom_value, zoom_value)
	queue_redraw()

func _draw() -> void:
	_draw_ground()
	_draw_roads()
	_draw_environment()
	for plot_id in PLOT_CELLS.size():
		_draw_plot(plot_id)
	_draw_residents()

func _draw_ground() -> void:
	for y in MAP_HEIGHT:
		for x in MAP_WIDTH:
			var cell := Vector2i(x, y)
			var center: Vector2 = Grid.grid_to_world(cell, TILE)
			var fill := Color("#78966d") if (x + y) % 2 == 0 else Color("#819d72")
			_draw_diamond(center, TILE, fill, Color("#a4b78d", 0.48), 1.0)

func _draw_roads() -> void:
	# The two streets follow the same logical cells as the approved preview.
	for x in MAP_WIDTH:
		_draw_road_cell(Vector2i(x, 3))
	for y in MAP_HEIGHT:
		_draw_road_cell(Vector2i(4, y))
	# Small lane markers remain aligned with the road's isometric direction.
	for x in [1, 3, 5, 7]:
		var p: Vector2 = Grid.grid_to_world(Vector2i(x, 3), TILE)
		draw_line(p + Vector2(-15, 0), p + Vector2(15, 0), Color("#eadcae"), 2.0)
	for y in [1, 5]:
		var p: Vector2 = Grid.grid_to_world(Vector2i(4, y), TILE)
		draw_line(p + Vector2(0, -8), p + Vector2(0, 8), Color("#eadcae"), 2.0)

func _draw_road_cell(cell: Vector2i) -> void:
	var center: Vector2 = Grid.grid_to_world(cell, TILE)
	_draw_diamond(center, TILE, Color("#c5bda7"), Color("#ded4bd"), 1.0)
	_draw_diamond(center, TILE * Vector2(0.86, 0.82), Color("#59615f"), Color("#737c75"), 1.0)

func _draw_environment() -> void:
	for cell in [Vector2i(0, 0), Vector2i(8, 0), Vector2i(0, 6), Vector2i(8, 6), Vector2i(2, 2), Vector2i(6, 5)]:
		_draw_tree(Grid.grid_to_world(cell, TILE) + Vector2(0, -7))
	for cell in [Vector2i(2, 3), Vector2i(6, 3), Vector2i(4, 1), Vector2i(4, 5)]:
		_draw_lamp(Grid.grid_to_world(cell, TILE) + Vector2(0, -10))
	# Park greenery between the lower plots.
	var park: Vector2 = Grid.grid_to_world(Vector2i(5, 5), TILE)
	_draw_diamond(park, TILE * Vector2(0.72, 0.58), Color("#719565"), Color("#9ab27e"), 1.0)
	for offset in [Vector2(-18, -4), Vector2(13, 5), Vector2(0, 13)]:
		_draw_bush(park + offset)

func _draw_plot(plot_id: int) -> void:
	var cell := PLOT_CELLS[plot_id]
	var center: Vector2 = Grid.grid_to_world(cell, TILE)
	var state: Dictionary = plot_states[plot_id]
	var selected := selected_plot == plot_id
	var plot_color := Color("#b0bd8a") if plot_id == 0 else Color("#9eb582")
	_draw_diamond(center, TILE * Vector2(0.88, 0.76), plot_color, Color("#e5d9b9"), 2.0)
	if selected:
		_draw_diamond(center, TILE * Vector2(0.96, 0.84), Color("#f6d77a", 0.14), Color("#ffe49a"), 3.0)

	match str(state.get("kind", "empty")):
		"home":
			_draw_house(center, plot_id == 0 and baba_home_repaired)
		"building":
			_draw_construction(center, float(state.get("progress", 0.0)))
		"built":
			_draw_house(center, true)
		_:
			_draw_garden(center)

func _draw_house(ground: Vector2, repaired: bool) -> void:
	# Footprint shadow and two facade planes; the base point stays on the plot cell.
	draw_colored_polygon(PackedVector2Array([
		ground + Vector2(-39, -3), ground + Vector2(0, -21),
		ground + Vector2(39, -3), ground + Vector2(0, 18)
	]), Color("#405642", 0.34))
	var h := 43.0
	draw_colored_polygon(PackedVector2Array([
		ground + Vector2(-31, -18), ground + Vector2(0, -2),
		ground + Vector2(0, -2 - h), ground + Vector2(-31, -18 - h)
	]), Color("#dfc49a"))
	draw_colored_polygon(PackedVector2Array([
		ground + Vector2(0, -2), ground + Vector2(31, -18),
		ground + Vector2(31, -18 - h), ground + Vector2(0, -2 - h)
	]), Color("#b98f69"))
	# Two roof planes with a clear ridge.
	draw_colored_polygon(PackedVector2Array([
		ground + Vector2(-39, -21), ground + Vector2(0, -44),
		ground + Vector2(0, -62), ground + Vector2(-39, -39)
	]), Color("#96594a"))
	draw_colored_polygon(PackedVector2Array([
		ground + Vector2(0, -44), ground + Vector2(39, -21),
		ground + Vector2(39, -39), ground + Vector2(0, -62)
	]), Color("#75463e"))
	draw_line(ground + Vector2(0, -62), ground + Vector2(0, -44), Color("#c58c6c"), 2.0)
	var window_color := Color("#f4d77f") if repaired else Color("#8fb8bc")
	_draw_iso_window(ground + Vector2(-21, -37), window_color)
	_draw_iso_window(ground + Vector2(8, -25), window_color)
	# Door is drawn on the front-facing right wall.
	draw_colored_polygon(PackedVector2Array([
		ground + Vector2(4, -25), ground + Vector2(13, -20),
		ground + Vector2(13, 2), ground + Vector2(4, -3)
	]), Color("#76513d"))
	_draw_bush(ground + Vector2(-43, 12))
	_draw_bush(ground + Vector2(43, 12))
	if repaired:
		draw_circle(ground + Vector2(-16, -29), 13, Color("#f5d77c", 0.10))
		draw_circle(ground + Vector2(16, -17), 13, Color("#f5d77c", 0.10))

func _draw_iso_window(origin: Vector2, tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		origin, origin + Vector2(10, 5), origin + Vector2(10, 18),
		origin + Vector2(0, 13)
	]), tint)
	draw_line(origin + Vector2(5, 2), origin + Vector2(5, 15), Color("#eee0c3"), 1.5)

func _draw_construction(ground: Vector2, progress: float) -> void:
	var p := clampf(progress, 0.0, 1.0)
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
	_draw_diamond(ground, TILE * Vector2(0.76, 0.62), Color("#b99b70"), Color("#8d7558"), 1.5)
	# Material stacks and survey stakes.
	_draw_diamond(ground + Vector2(34, 8), Vector2(25, 13), Color("#9b7956"), Color("#d0b18a"), 1.0)
	for offset in [Vector2(-30, -5), Vector2(30, -5), Vector2(-30, 5), Vector2(30, 5)]:
		draw_line(ground + offset, ground + offset + Vector2(0, -16), Color("#79543a"), 2.0)
		draw_circle(ground + offset + Vector2(0, -16), 2.5, Color("#f0d27e"))
	if phase >= 1:
		_draw_diamond(ground + Vector2(0, -3), TILE * Vector2(0.56, 0.42), Color("#92988d"), Color("#d1cbbb"), 1.0)
	if phase >= 2:
		var wall_h := lerpf(8.0, 34.0, clampf((p - 0.28) / 0.27, 0.0, 1.0))
		draw_colored_polygon(PackedVector2Array([
			ground + Vector2(-25, -12), ground + Vector2(0, 1),
			ground + Vector2(0, 1 - wall_h), ground + Vector2(-25, -12 - wall_h)
		]), Color("#c99a70"))
		draw_colored_polygon(PackedVector2Array([
			ground + Vector2(0, 1), ground + Vector2(25, -12),
			ground + Vector2(25, -12 - wall_h), ground + Vector2(0, 1 - wall_h)
		]), Color("#ad805f"))
		for row in range(1, int(wall_h / 8.0) + 1):
			var y := 1.0 - float(row) * 8.0
			draw_line(ground + Vector2(-24, y - 12), ground + Vector2(24, y - 12), Color("#a9785b"), 1.0)
	if phase >= 3:
		var roof_h := 42.0
		var roof_progress := clampf((p - 0.55) / 0.17, 0.0, 1.0)
		var roof_color := Color("#875647").lerp(Color("#70443b"), roof_progress)
		draw_colored_polygon(PackedVector2Array([
			ground + Vector2(-34, -20), ground + Vector2(0, -40),
			ground + Vector2(0, -40 - roof_h * 0.35), ground + Vector2(-34, -20 - roof_h * 0.35)
		]), roof_color)
		draw_colored_polygon(PackedVector2Array([
			ground + Vector2(0, -40), ground + Vector2(34, -20),
			ground + Vector2(34, -20 - roof_h * 0.35), ground + Vector2(0, -40 - roof_h * 0.35)
		]), Color("#70443b"))
	if phase >= 4:
		_draw_iso_window(ground + Vector2(-20, -32), Color("#91b8bd"))
		_draw_iso_window(ground + Vector2(8, -20), Color("#91b8bd"))
	if phase >= 5:
		draw_line(ground + Vector2(-39, 19), ground + Vector2(39, -19), Color("#477b9a"), 3.0)
		draw_line(ground + Vector2(-34, 24), ground + Vector2(34, -14), Color("#c5a34f"), 2.0)
	if phase >= 6:
		_draw_bush(ground + Vector2(-43, 12))
		_draw_bush(ground + Vector2(43, 12))
	# Construction beacon gives active projects a subtle animated marker.
	var pulse := 0.5 + 0.5 * sin(construction_animation_time * 3.0)
	draw_circle(ground + Vector2(42, -58), 4.0 + pulse * 2.0, Color("#f4d47a", 0.18 + pulse * 0.16))
	draw_circle(ground + Vector2(42, -58), 2.5, Color("#f4d47a"))

func _draw_garden(center: Vector2) -> void:
	_draw_diamond(center + Vector2(0, -1), TILE * Vector2(0.48, 0.34), Color("#86a36e"), Color("#a9bc8b"), 1.0)
	for offset in [Vector2(-13, -5), Vector2(10, -3), Vector2(1, 8)]:
		_draw_bush(center + offset)

func _draw_tree(pos: Vector2) -> void:
	draw_ellipse(pos + Vector2(3, 13), Vector2(18, 7), Color("#435d43", 0.35))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-3, 0), pos + Vector2(3, 0),
		pos + Vector2(3, 20), pos + Vector2(-3, 20)
	]), Color("#76543a"))
	draw_circle(pos + Vector2(0, -13), 17, Color("#4c7950"))
	draw_circle(pos + Vector2(-9, -17), 10, Color("#638f5b"))
	draw_circle(pos + Vector2(8, -20), 10, Color("#79a66a"))
	draw_circle(pos + Vector2(-3, -25), 7, Color("#8bb477"))

func _draw_bush(pos: Vector2) -> void:
	draw_circle(pos, 7, Color("#4d784d"))
	draw_circle(pos + Vector2(-4, -3), 5, Color("#719a5d"))
	draw_circle(pos + Vector2(4, -4), 5, Color("#82a86b"))

func _draw_lamp(pos: Vector2) -> void:
	draw_ellipse(pos + Vector2(0, 4), Vector2(7, 3), Color("#435443", 0.3))
	draw_line(pos, pos + Vector2(0, -24), Color("#3d4944"), 3.0)
	draw_line(pos + Vector2(0, -23), pos + Vector2(8, -28), Color("#3d4944"), 2.0)
	draw_circle(pos + Vector2(9, -29), 4.0, Color("#f3d98e"))
	draw_circle(pos + Vector2(9, -29), 9.0 + sin(construction_animation_time * 2.0) * 1.0, Color("#f3d98e", 0.12))

func _draw_residents() -> void:
	for group in resident_groups:
		if not group is Dictionary:
			continue
		var plot_id := int(group.get("plot_id", -1))
		if plot_id < 1 or plot_id >= PLOT_CELLS.size():
			continue
		var activity := str(group.get("activity", "at_home"))
		if activity == "sleeping" or activity == "at_work":
			continue
		var home: Vector2 = Grid.grid_to_world(PLOT_CELLS[plot_id], TILE)
		var count := clampi(int(group.get("members_count", 0)), 0, 8)
		for member_index in count:
			var phase := pedestrian_time * 1.4 + float(member_index) * 1.8
			var pos := home + Vector2(sin(phase) * 13.0, 15.0 + cos(phase * 0.7) * 3.0)
			_draw_person(pos, member_index)

func _draw_person(pos: Vector2, variant: int) -> void:
	var shirts := [Color("#d58c68"), Color("#6e91a3"), Color("#d5bd78")]
	var shirt: Color = shirts[variant % shirts.size()]
	draw_ellipse(pos + Vector2(1, 5), Vector2(4, 2), Color("#34443a", 0.28))
	draw_circle(pos + Vector2(0, -5), 3.0, Color("#e7c6a3"))
	draw_rect(Rect2(pos + Vector2(-2.5, -2), Vector2(5, 7)), shirt, true)
	draw_line(pos + Vector2(-1, 5), pos + Vector2(-2, 8), Color("#39433f"), 1.5)
	draw_line(pos + Vector2(1, 5), pos + Vector2(2, 8), Color("#39433f"), 1.5)

func _draw_diamond(center: Vector2, size: Vector2, fill: Color, outline: Color, width: float) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -size.y * 0.5),
		center + Vector2(size.x * 0.5, 0),
		center + Vector2(0, size.y * 0.5),
		center + Vector2(-size.x * 0.5, 0)
	])
	draw_colored_polygon(points, fill)
	for i in points.size():
		draw_line(points[i], points[(i + 1) % points.size()], outline, width)

func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * float(i) / 16.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			drag_active = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_screen_position(1.12, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_screen_position(1.0 / 1.12, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_world_position(get_global_mouse_position())
	elif event is InputEventMouseMotion and drag_active:
		camera_target_position -= event.relative / camera.zoom.x
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_active = true
			touch_moved = false
			touch_start = event.position
		else:
			if touch_active and not touch_moved:
				_select_world_position(get_viewport().get_canvas_transform().affine_inverse() * event.position)
			touch_active = false
	elif event is InputEventScreenDrag and touch_active:
		if event.position.distance_to(touch_start) > 12.0:
			touch_moved = true
		if touch_moved:
			camera_target_position -= event.relative / camera.zoom.x
	elif event is InputEventMagnifyGesture:
		_zoom_at_screen_position(event.factor, get_viewport_rect().size * 0.5)
	elif event is InputEventPanGesture:
		camera_target_position -= event.delta / camera.zoom.x

func _zoom_at_screen_position(factor: float, screen_position: Vector2) -> void:
	var before := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	camera_target_zoom = clampf(camera_target_zoom * factor, camera_min_zoom, camera_max_zoom)
	var after := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	camera_target_position += before - after
	_clamp_camera_target()

func _update_keyboard_camera(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if direction.length_squared() > 0.0:
		camera_target_position += direction.normalized() * keyboard_pan_speed * delta / maxf(camera.zoom.x, 0.1)

func _clamp_camera_target() -> void:
	var first: Vector2 = Grid.grid_to_world(Vector2i(0, 0), TILE)
	var last: Vector2 = Grid.grid_to_world(Vector2i(MAP_WIDTH - 1, MAP_HEIGHT - 1), TILE)
	var left_top: Vector2 = Grid.grid_to_world(Vector2i(0, MAP_HEIGHT - 1), TILE)
	var right_bottom: Vector2 = Grid.grid_to_world(Vector2i(MAP_WIDTH - 1, 0), TILE)
	var min_x := minf(minf(first.x, last.x), minf(left_top.x, right_bottom.x)) - TILE.x * 0.9
	var max_x := maxf(maxf(first.x, last.x), maxf(left_top.x, right_bottom.x)) + TILE.x * 0.9
	var min_y := minf(minf(first.y, last.y), minf(left_top.y, right_bottom.y)) - 150.0
	var max_y := maxf(maxf(first.y, last.y), maxf(left_top.y, right_bottom.y)) + 90.0
	var visible_half := get_viewport_rect().size * 0.5 / maxf(camera_target_zoom, 0.1)
	var low_x := min_x + visible_half.x
	var high_x := max_x - visible_half.x
	var low_y := min_y + visible_half.y
	var high_y := max_y - visible_half.y
	if low_x > high_x:
		camera_target_position.x = (min_x + max_x) * 0.5
	else:
		camera_target_position.x = clampf(camera_target_position.x, low_x, high_x)
	if low_y > high_y:
		camera_target_position.y = (min_y + max_y) * 0.5
	else:
		camera_target_position.y = clampf(camera_target_position.y, low_y, high_y)

func _select_world_position(world_position: Vector2) -> void:
	var cell: Vector2i = Grid.world_to_grid(world_position, TILE)
	var center: Vector2 = Grid.grid_to_world(cell, TILE)
	if cell.x < 0 or cell.x >= MAP_WIDTH or cell.y < 0 or cell.y >= MAP_HEIGHT:
		return
	if not Grid.is_inside_cell(world_position - center, TILE):
		return
	for plot_id in PLOT_CELLS.size():
		if PLOT_CELLS[plot_id] == cell:
			selected_plot = plot_id
			plot_selected.emit(plot_id)
			queue_redraw()
			return

func _zoom(factor: float) -> void:
	camera_target_zoom = clampf(camera_target_zoom * factor, camera_min_zoom, camera_max_zoom)
	_clamp_camera_target()

func set_resident_groups(groups: Array) -> void:
	resident_groups = groups.duplicate(true)
	queue_redraw()

func get_save_data() -> Dictionary:
	return {"plot_states": plot_states.duplicate(true), "baba_home_repaired": baba_home_repaired}

func load_save_data(data: Dictionary) -> void:
	var saved_plots: Variant = data.get("plot_states", [])
	if saved_plots is Array and saved_plots.size() == PLOT_CELLS.size():
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
	return str(plot_states[plot_id].get("kind", ""))

func get_plot_name(plot_id: int) -> String:
	if plot_id < 0 or plot_id >= PLOT_NAMES.size():
		return "Участок"
	return PLOT_NAMES[plot_id]
