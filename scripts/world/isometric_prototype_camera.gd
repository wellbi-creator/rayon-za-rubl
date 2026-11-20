extends Camera3D

## Standalone prototype camera: desktop drag / wheel and iOS-safe touch drag / pinch.
@export var pan_speed: float = 0.018
@export var min_zoom: float = 11.0
@export var max_zoom: float = 30.0

var _dragging := false
# Do not use InputEventScreenTouch.index here: iOS Web exports can provide
# a changing, invalid index. The event positions themselves remain correct.
var _touch_positions: Array[Vector2] = []
var _has_screen_touch := false

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 20.0
	look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_has_screen_touch = true
		_dragging = false
		if event.pressed:
			_touch_positions.append(event.position)
		else:
			_remove_nearest_touch(event.position)
	elif event is InputEventScreenDrag:
		_has_screen_touch = true
		_dragging = false
		_handle_touch_drag(event)
	elif event is InputEventMouseButton and not _has_screen_touch:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = maxf(min_zoom, size - 1.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size = minf(max_zoom, size + 1.0)
	elif event is InputEventMouseMotion and _dragging and not _has_screen_touch:
		_pan(event.relative)
	elif event is InputEventMagnifyGesture:
		# Keep native magnify support where the platform provides it.
		size = clampf(size / event.factor, min_zoom, max_zoom)

func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	# Match the moving finger to its previous position, never to event.index.
	var touch_index := _find_nearest_touch(event.position)
	if touch_index == -1:
		# Recover gracefully if a browser omitted the initial press event.
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
