extends Camera3D

## Standalone prototype camera with an on-screen input diagnostic.
@export var pan_speed: float = 0.018
@export var min_zoom: float = 11.0
@export var max_zoom: float = 30.0

var _dragging := false
var _touch_positions: Array[Vector2] = []
var _has_screen_touch := false

var _screen_touch_events := 0
var _screen_drag_events := 0
var _mouse_button_events := 0
var _mouse_motion_events := 0
var _magnify_events := 0
var _last_event := "Ожидание касания"
var _diagnostic_label: Label

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 20.0
	look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	_create_diagnostic_overlay()

func _process(_delta: float) -> void:
	if is_instance_valid(_diagnostic_label):
		_diagnostic_label.text = _diagnostic_text()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_screen_touch_events += 1
		_last_event = "SCREEN TOUCH: " + ("press" if event.pressed else "release") + " @ " + str(event.position)
		_has_screen_touch = true
		_dragging = false
		if event.pressed:
			_touch_positions.append(event.position)
		else:
			_remove_nearest_touch(event.position)
	elif event is InputEventScreenDrag:
		_screen_drag_events += 1
		_last_event = "SCREEN DRAG @ " + str(event.position) + " relative " + str(event.relative)
		_has_screen_touch = true
		_dragging = false
		_handle_touch_drag(event)
	elif event is InputEventMouseButton:
		_mouse_button_events += 1
		_last_event = "MOUSE BUTTON: " + str(event.button_index)
		if not _has_screen_touch:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_dragging = event.pressed
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
				size = maxf(min_zoom, size - 1.0)
			elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				size = minf(max_zoom, size + 1.0)
	elif event is InputEventMouseMotion:
		_mouse_motion_events += 1
		_last_event = "MOUSE MOTION relative " + str(event.relative)
		if _dragging and not _has_screen_touch:
			_pan(event.relative)
	elif event is InputEventMagnifyGesture:
		_magnify_events += 1
		_last_event = "MAGNIFY factor " + str(event.factor)
		size = clampf(size / event.factor, min_zoom, max_zoom)

func _create_diagnostic_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(12.0, 12.0)
	panel.custom_minimum_size = Vector2(340.0, 150.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)

	_diagnostic_label = Label.new()
	_diagnostic_label.add_theme_font_size_override("font_size", 15)
	_diagnostic_label.add_theme_color_override("font_color", Color.WHITE)
	_diagnostic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diagnostic_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_diagnostic_label)

func _diagnostic_text() -> String:
	return "INPUT DIAGNOSTICS\n" + \
		"ScreenTouch: " + str(_screen_touch_events) + " | ScreenDrag: " + str(_screen_drag_events) + "\n" + \
		"MouseButton: " + str(_mouse_button_events) + " | MouseMotion: " + str(_mouse_motion_events) + "\n" + \
		"Magnify: " + str(_magnify_events) + " | Active fingers: " + str(_touch_positions.size()) + "\n" + \
		"Camera size: " + str(snappedf(size, 0.1)) + "\n" + \
		"Last: " + _last_event

func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	var touch_index := _find_nearest_touch(event.position)
	if touch_index == -1:
		if _touch_positions.is_empty():
			_pan(event.relative)
			return
		touch_index = 0

	var previous_position: Vector2 = _touch_positions[touch_index]
	if _touch_positions.size() >= 2:
		var other_index := 1 - touch_index
		if other_index >= 0 and other_index < _touch_positions.size():
			var other_position: Vector2 = _touch_positions[other_index]
			var old_distance := previous_position.distance_to(other_position)
			var new_distance := event.position.distance_to(other_position)
			if old_distance > 0.0 and new_distance > 0.0:
				size = clampf(size * old_distance / new_distance, min_zoom, max_zoom)
		_touch_positions[touch_index] = event.position
		return

	_touch_positions[touch_index] = event.position
	_pan(event.relative)

func _find_nearest_touch(position: Vector2) -> int:
	var best_index := -1
	var best_distance := INF
	for i in range(_touch_positions.size()):
		var distance := _touch_positions[i].distance_squared_to(position)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index

func _remove_nearest_touch(position: Vector2) -> void:
	var touch_index := _find_nearest_touch(position)
	if touch_index != -1:
		_touch_positions.remove_at(touch_index)

func _pan(relative: Vector2) -> void:
	var scale := pan_speed * (size / 20.0)
	global_position -= global_basis.x * relative.x * scale
	global_position += global_basis.z * relative.y * scale
	global_position.x = clampf(global_position.x, -18.0, 18.0)
	global_position.z = clampf(global_position.z, -18.0, 18.0)
