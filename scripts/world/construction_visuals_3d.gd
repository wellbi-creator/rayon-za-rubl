extends Node3D
class_name ConstructionVisuals3D

## Progress-driven 3D construction visuals.
## ConstructionService remains the source of truth for gameplay progress and saves.

@export var auto_play_demo: bool = true
@export_range(0.1, 60.0, 0.1) var demo_duration_seconds: float = 8.0

const FOUNDATION_START := 0.12
const WALLS_START := 0.28
const WINDOWS_START := 0.55
const ROOF_START := 0.72
const UTILITIES_START := 0.86

@onready var foundation: MeshInstance3D = $HouseFoundation
@onready var walls: MeshInstance3D = $HouseWalls
@onready var window_left: MeshInstance3D = $FrontWindowLeft
@onready var window_right: MeshInstance3D = $FrontWindowRight
@onready var front_door: MeshInstance3D = $FrontDoor
@onready var roof_left: MeshInstance3D = $RoofSlopeLeft
@onready var roof_right: MeshInstance3D = $RoofSlopeRight

var _final_transforms: Dictionary = {}
var _construction_tween: Tween


func _ready() -> void:
	_cache_final_transforms()
	reset_construction()
	if auto_play_demo:
		play_construction()


func _cache_final_transforms() -> void:
	for part in _get_construction_parts():
		_final_transforms[part] = {
			"position": part.position,
			"scale": part.scale
		}


func _get_construction_parts() -> Array[MeshInstance3D]:
	return [
		foundation,
		walls,
		window_left,
		window_right,
		front_door,
		roof_left,
		roof_right
	]


## Sets all building parts to the empty-plot state and stops the demo tween.
func reset_construction() -> void:
	_stop_demo_tween()
	set_construction_progress(0.0)


## Applies normalized ConstructionService progress (0.0 to 1.0).
## The same stage thresholds are used by ConstructionService and the 2D district renderer.
## Set auto_play_demo to false when driving this node from live gameplay progress.
func set_construction_progress(progress: float) -> void:
	var p := clampf(progress, 0.0, 1.0)
	_set_part_progress(foundation, inverse_lerp(FOUNDATION_START, WALLS_START, p))
	_set_part_progress(walls, inverse_lerp(WALLS_START, WINDOWS_START, p))
	_set_part_progress(window_left, inverse_lerp(WINDOWS_START, ROOF_START, p))
	_set_part_progress(window_right, inverse_lerp(WINDOWS_START, ROOF_START, p))
	_set_part_progress(front_door, inverse_lerp(WINDOWS_START, ROOF_START, p))
	_set_part_progress(roof_left, inverse_lerp(ROOF_START, UTILITIES_START, p))
	_set_part_progress(roof_right, inverse_lerp(ROOF_START, UTILITIES_START, p))


func _set_part_progress(part: MeshInstance3D, amount: float) -> void:
	var t := clampf(amount, 0.0, 1.0)
	var target: Dictionary = _final_transforms[part]
	var target_position: Vector3 = target["position"]
	var target_scale: Vector3 = target["scale"]
	var base_y := target_position.y - target_scale.y * 0.5 + 0.005
	part.visible = t > 0.001
	part.scale = Vector3(target_scale.x, lerpf(0.01, target_scale.y, t), target_scale.z)
	part.position = Vector3(
		target_position.x,
		lerpf(base_y, target_position.y, t),
		target_position.z
	)


## Plays a short standalone demo using the same progress mapping as live construction.
func play_construction() -> void:
	reset_construction()
	_construction_tween = create_tween()
	_construction_tween.tween_method(
		set_construction_progress,
		0.0,
		1.0,
		maxf(0.1, demo_duration_seconds)
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _stop_demo_tween() -> void:
	if _construction_tween != null and _construction_tween.is_running():
		_construction_tween.kill()
	_construction_tween = null
