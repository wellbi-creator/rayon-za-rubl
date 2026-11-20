extends Camera3D

## Standalone prototype camera: mouse drag / wheel, one-finger pan, two-finger pinch.
@export var pan_speed: float = 0.018
@export var min_zoom: float = 11.0
@export var max_zoom: float = 30.0

var _mouse_dragging := false
var _touch_points: Array[Vector2] = []

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 20.0
	look_at(Vector3.ZERO, Vector3.UP)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMagnifyGesture:
		if event.factor > 0.0:
			size = clampf(size / event.factor, min_zoom, max_zoom)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _mouse_dragging:
		_pan(event.relative)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_points.append(event.position)
	else:
		_remove_touch_near(event.position)

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if _touch_points.is_empty():
		# Recover if the browser starts delivering drag without a press event.
		_touch_points.append(event.position)
		return

	# Match by the finger's previous screen position, not event.index.
	# This avoids depending on unstable touch IDs in some iOS Web exports.
	var previous_position := event.position - event.relative
	var moving_index := _nearest_touch_index(previous_position)
	if moving_index < 0:
		return

	if _touch_points.size() == 1:
		_touch_points[0] = event.position
		_pan(event.relative)
		return

	# Two active fingers: update only the moving finger and derive zoom
	# from the change in distance between the two touch points.
	var other_index := 1 - moving_index
	var old_distance := _touch_points[moving_index].distance_to(_touch_points[other_index])
	var new_distance := event.position.distance_to(_touch_points[other_index])
	if old_distance > 0.0 and new_distance > 0.0:
		size = clampf(size * old_distance / new_distance, min_zoom, max_zoom)
	_touch_points[moving_index] = event.position

func _nearest_touch_index(position: Vector2) -> int:
	var nearest_index := -1
	var nearest_distance := INF
	for i in range(_touch_points.size()):
		var distance := _touch_points[i].distance_squared_to(position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = i
	return nearest_index

func _remove_touch_near(position: Vector2) -> void:
	var index := _nearest_touch_index(position)
	if index >= 0:
		_touch_points.remove_at(index)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_dragging = event.pressed
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		size = maxf(min_zoom, size - 1.0)
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		size = minf(max_zoom, size + 1.0)

func _pan(relative: Vector2) -> void:
	var scale := pan_speed * (size / 20.0)
	global_position -= global_basis.x * relative.x * scale
	global_position += global_basis.z * relative.y * scale
	global_position.x = clampf(global_position.x, -18.0, 18.0)
	global_position.z = clampf(global_position.z, -18.0, 18.0)
