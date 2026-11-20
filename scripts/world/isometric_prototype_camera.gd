extends Camera3D

## Standalone prototype camera: desktop drag / wheel and reliable touch drag / pinch zoom.
@export var pan_speed: float = 0.018
@export var min_zoom: float = 11.0
@export var max_zoom: float = 30.0

var _dragging := false
var _touch_positions: Dictionary = {}

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 20.0
	look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = maxf(min_zoom, size - 1.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size = minf(max_zoom, size + 1.0)
	elif event is InputEventMouseMotion and _dragging:
		_pan(event.relative)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_positions[event.index] = event.position
		else:
			_touch_positions.erase(event.index)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event)
	elif event is InputEventMagnifyGesture:
		# Keep native magnify support where the platform provides it.
		size = clampf(size / event.factor, min_zoom, max_zoom)

func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	var previous_position: Vector2 = _touch_positions.get(event.index, event.position)
	if _touch_positions.size() >= 2:
		var other_index = -1
		for touch_index in _touch_positions:
			if touch_index != event.index:
				other_index = touch_index
				break
		if other_index != -1:
			var other_position: Vector2 = _touch_positions[other_index]
			var old_distance := previous_position.distance_to(other_position)
			var new_distance := event.position.distance_to(other_position)
			if old_distance > 0.0 and new_distance > 0.0:
				size = clampf(size * old_distance / new_distance, min_zoom, max_zoom)
		_touch_positions[event.index] = event.position
		return

	_touch_positions[event.index] = event.position
	_pan(event.relative)

func _pan(relative: Vector2) -> void:
	var scale := pan_speed * (size / 20.0)
	global_position -= global_basis.x * relative.x * scale
	global_position += global_basis.z * relative.y * scale
	global_position.x = clampf(global_position.x, -18.0, 18.0)
	global_position.z = clampf(global_position.z, -18.0, 18.0)
