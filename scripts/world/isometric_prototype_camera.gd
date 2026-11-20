extends Camera3D

## Standalone prototype camera: desktop drag / wheel and touch drag / pinch-like zoom.
@export var pan_speed: float = 0.018
@export var min_zoom: float = 11.0
@export var max_zoom: float = 30.0

var _dragging := false

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 20.0
	look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = maxf(min_zoom, size - 1.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size = minf(max_zoom, size + 1.0)
	elif event is InputEventMouseMotion and _dragging:
		_pan(event.relative)
	elif event is InputEventScreenDrag:
		_pan(event.relative)
	elif event is InputEventMagnifyGesture:
		size = clampf(size / event.factor, min_zoom, max_zoom)

func _pan(relative: Vector2) -> void:
	var scale := pan_speed * (size / 20.0)
	global_position -= global_basis.x * relative.x * scale
	global_position += global_basis.z * relative.y * scale
	global_position.x = clampf(global_position.x, -18.0, 18.0)
	global_position.z = clampf(global_position.z, -18.0, 18.0)
