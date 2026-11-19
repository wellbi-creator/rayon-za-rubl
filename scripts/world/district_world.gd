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

func _ready() -> void:
	for i in PLOT_RECTS.size():
		plot_states.append({"kind": "home" if i == 0 else "empty", "progress": 0.0})
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	camera.zoom = Vector2.ONE
	add_child(camera)
	camera.make_current()
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

func _draw_plot(plot_id: int) -> void:
	var rect := PLOT_RECTS[plot_id]
	var state: Dictionary = plot_states[plot_id]
	var is_selected := selected_plot == plot_id
	draw_rect(rect.grow(5), Color("#d8d0b5", 0.55), true)
	draw_rect(rect, Color("#9eb184"), true)
	draw_rect(rect, Color("#e4d8b7") if is_selected else Color("#c9c3a3"), false, 3.0)

	if state["kind"] == "home":
		_draw_house(rect.position + Vector2(27, 16), false, 0.0)
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
			_select_at(get_global_transform_with_canvas().affine_inverse() * event.position)
	elif event is InputEventScreenDrag:
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
