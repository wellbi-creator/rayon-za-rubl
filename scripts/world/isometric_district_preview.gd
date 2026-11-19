extends Node2D
class_name IsometricDistrictPreview

const Grid = preload("res://scripts/world/isometric_grid.gd")
const TILE := Vector2(128.0, 64.0)
const MAP_WIDTH := 9
const MAP_HEIGHT := 7

var camera: Camera2D
var selected_cell := Vector2i(-1, -1)
var drag_active := false
var drag_last := Vector2.ZERO
var time := 0.0

func _ready() -> void:
	camera = Camera2D.new()
	camera.position = Grid.grid_to_world(Vector2i(4, 3), TILE)
	camera.zoom = Vector2(0.82, 0.82)
	add_child(camera)
	camera.make_current()
	queue_redraw()

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	_draw_ground()
	_draw_roads()
	_draw_plots()
	_draw_trees()
	_draw_lamps()

func _draw_ground() -> void:
	for y in MAP_HEIGHT:
		for x in MAP_WIDTH:
			var cell := Vector2i(x, y)
			var center: Vector2 = Grid.grid_to_world(cell, TILE)
			var color := Color("#78966d") if (x + y) % 2 == 0 else Color("#819d72")
			_draw_diamond(center, TILE, color, Color("#9db58a", 0.55), 1.0)

func _draw_roads() -> void:
	# A broad diagonal avenue and a crossing street, aligned to the isometric grid.
	for x in MAP_WIDTH:
		var cell := Vector2i(x, 3)
		var center: Vector2 = Grid.grid_to_world(cell, TILE)
		_draw_diamond(center, TILE, Color("#626b68"), Color("#c5bda7"), 2.0)
		_draw_diamond(center, TILE * Vector2(0.72, 0.72), Color("#59615f"), Color("#747d77"), 1.0)
	for y in MAP_HEIGHT:
		var cell := Vector2i(4, y)
		var center: Vector2 = Grid.grid_to_world(cell, TILE)
		_draw_diamond(center, TILE, Color("#626b68"), Color("#c5bda7"), 2.0)
		_draw_diamond(center, TILE * Vector2(0.72, 0.72), Color("#59615f"), Color("#747d77"), 1.0)
	# Short dashed center markings on the avenue.
	for x in range(1, MAP_WIDTH - 1, 2):
		var center: Vector2 = Grid.grid_to_world(Vector2i(x, 3), TILE)
		draw_line(center + Vector2(-18, 0), center + Vector2(18, 0), Color("#eadcae"), 2.0)

func _draw_plots() -> void:
	var cells: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(2, 5), Vector2i(6, 1),
		Vector2i(7, 5), Vector2i(1, 5), Vector2i(7, 1)
	]
	for index in cells.size():
		var cell := cells[index]
		var center: Vector2 = Grid.grid_to_world(cell, TILE)
		var plot_color := Color("#a2b887") if index != 0 else Color("#b0bd8a")
		_draw_diamond(center, TILE * Vector2(0.88, 0.78), plot_color, Color("#e1d4b5"), 2.0)
		if index == 0:
			_draw_house(center + Vector2(0, -4), true)
		elif index == 1:
			_draw_house(center + Vector2(0, -4), false)
		else:
			_draw_garden(center)

func _draw_house(ground: Vector2, repaired: bool) -> void:
	# Ground shadow and two visible wall planes.
	draw_colored_polygon(PackedVector2Array([
		ground + Vector2(-36, -8), ground + Vector2(0, -25),
		ground + Vector2(38, -8), ground + Vector2(0, 10)
	]), Color("#52634d", 0.35))
	var wall_height := 44.0
	var left := PackedVector2Array([
		ground + Vector2(-31, -20), ground + Vector2(0, -4),
		ground + Vector2(0, -4 - wall_height), ground + Vector2(-31, -20 - wall_height)
	])
	var right := PackedVector2Array([
		ground + Vector2(0, -4), ground + Vector2(31, -20),
		ground + Vector2(31, -20 - wall_height), ground + Vector2(0, -4 - wall_height)
	])
	draw_colored_polygon(left, Color("#d9bd91"))
	draw_colored_polygon(right, Color("#b88e68"))
	# Roof planes rise above the walls.
	draw_colored_polygon(PackedVector2Array([
		ground + Vector2(-39, -23), ground + Vector2(0, -46),
		ground + Vector2(0, -64), ground + Vector2(-39, -41)
	]), Color("#96594a"))
	draw_colored_polygon(PackedVector2Array([
		ground + Vector2(0, -46), ground + Vector2(39, -23),
		ground + Vector2(39, -41), ground + Vector2(0, -64)
	]), Color("#75463e"))
	var window_color := Color("#f4d77f") if repaired else Color("#8fb8bc")
	draw_rect(Rect2(ground + Vector2(-23, -47), Vector2(10, 13)), window_color)
	draw_rect(Rect2(ground + Vector2(9, -36), Vector2(10, 13)), window_color)
	draw_rect(Rect2(ground + Vector2(-4, -29), Vector2(9, 25)), Color("#76513d"))

func _draw_garden(center: Vector2) -> void:
	_draw_diamond(center + Vector2(0, -2), TILE * Vector2(0.48, 0.36), Color("#86a36e"), Color("#a9bc8b"), 1.0)
	for offset in [Vector2(-13, -7), Vector2(10, -4), Vector2(1, 8)]:
		_draw_bush(center + offset)

func _draw_trees() -> void:
	for cell in [Vector2i(0, 0), Vector2i(8, 0), Vector2i(0, 6), Vector2i(8, 6), Vector2i(2, 2), Vector2i(6, 5)]:
		var pos: Vector2 = Grid.grid_to_world(cell, TILE) + Vector2(0, -5)
		_draw_tree(pos)

func _draw_tree(pos: Vector2) -> void:
	draw_ellipse(pos + Vector2(3, 12), Vector2(18, 7), Color("#435d43", 0.35))
	draw_rect(Rect2(pos + Vector2(-3, -3), Vector2(6, 21)), Color("#76543a"))
	draw_circle(pos + Vector2(0, -13), 17, Color("#4c7950"))
	draw_circle(pos + Vector2(-9, -17), 10, Color("#638f5b"))
	draw_circle(pos + Vector2(8, -20), 10, Color("#79a66a"))
	draw_circle(pos + Vector2(-3, -25), 7, Color("#8bb477"))

func _draw_bush(pos: Vector2) -> void:
	draw_circle(pos, 7, Color("#4d784d"))
	draw_circle(pos + Vector2(-4, -3), 5, Color("#719a5d"))
	draw_circle(pos + Vector2(4, -4), 5, Color("#82a86b"))

func _draw_lamps() -> void:
	for cell in [Vector2i(2, 3), Vector2i(6, 3), Vector2i(4, 1), Vector2i(4, 5)]:
		var pos: Vector2 = Grid.grid_to_world(cell, TILE) + Vector2(0, -13)
		draw_line(pos, pos + Vector2(0, -25), Color("#3d4944"), 3.0)
		draw_circle(pos + Vector2(0, -27), 4.0, Color("#f3d98e"))
		draw_circle(pos + Vector2(0, -27), 9.0 + sin(time * 2.0) * 1.2, Color("#f3d98e", 0.12))

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
		if event.button_index == MOUSE_BUTTON_RIGHT:
			drag_active = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(0.9)
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_screen_position(get_global_mouse_position())
	elif event is InputEventMouseMotion and drag_active:
		camera.position -= event.relative / camera.zoom.x
	elif event is InputEventScreenTouch:
		if event.pressed:
			drag_active = true
			drag_last = event.position
		else:
			drag_active = false
			_select_screen_position(get_viewport().get_canvas_transform().affine_inverse() * event.position)
	elif event is InputEventScreenDrag and drag_active:
		camera.position -= event.relative / camera.zoom.x
		drag_last = event.position

func _select_screen_position(world_position: Vector2) -> void:
	var cell: Vector2i = Grid.world_to_grid(world_position, TILE)
	var center: Vector2 = Grid.grid_to_world(cell, TILE)
	if cell.x >= 0 and cell.x < MAP_WIDTH and cell.y >= 0 and cell.y < MAP_HEIGHT and Grid.is_inside_cell(world_position - center, TILE):
		selected_cell = cell
		queue_redraw()

func _zoom(factor: float) -> void:
	var next_zoom := clampf(camera.zoom.x * factor, 0.55, 1.5)
	camera.zoom = Vector2(next_zoom, next_zoom)
