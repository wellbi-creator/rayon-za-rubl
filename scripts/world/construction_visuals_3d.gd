extends Node3D
class_name ConstructionVisuals3D

## Reusable visual-only construction sequence for the isolated 3D district prototype.
## Gameplay progress, costs, timers and save data remain owned by ConstructionService.

@export var auto_play_demo: bool = true

@onready var foundation: MeshInstance3D = $HouseFoundation
@onready var walls: MeshInstance3D = $HouseWalls
@onready var window_left: MeshInstance3D = $FrontWindowLeft
@onready var window_right: MeshInstance3D = $FrontWindowRight
@onready var front_door: MeshInstance3D = $FrontDoor
@onready var roof_left: MeshInstance3D = $RoofSlopeLeft
@onready var roof_right: MeshInstance3D = $RoofSlopeRight

var _final_transforms: Dictionary = {}

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

## Restores the empty plot state so the sequence can be replayed.
func reset_construction() -> void:
	for part in _get_construction_parts():
		var target: Dictionary = _final_transforms[part]
		var target_position: Vector3 = target["position"]
		var target_scale: Vector3 = target["scale"]
		part.visible = false
		part.scale = Vector3(target_scale.x, 0.01, target_scale.z)
		part.position = Vector3(
			target_position.x,
			target_position.y - target_scale.y * 0.5 + 0.005,
			target_position.z
		)

## Plays foundation -> rising walls -> windows/door -> roof.
## This is a visual prototype only; it does not advance or modify game construction data.
func play_construction() -> void:
	reset_construction()
	var sequence := create_tween()
	_reveal_and_raise(sequence, foundation, 0.75, 0.0)
	_reveal_and_raise(sequence, walls, 1.35, 0.18)
	_reveal_and_raise(sequence, window_left, 0.42, 0.12)
	_reveal_and_raise(sequence, window_right, 0.42, 0.0)
	_reveal_and_raise(sequence, front_door, 0.48, 0.0)
	_reveal_and_raise(sequence, roof_left, 0.72, 0.16)
	_reveal_and_raise(sequence, roof_right, 0.72, 0.0)

func _reveal_and_raise(sequence: Tween, part: MeshInstance3D, duration: float, delay: float) -> void:
	var target: Dictionary = _final_transforms[part]
	var target_position: Vector3 = target["position"]
	var target_scale: Vector3 = target["scale"]
	sequence.tween_callback(func() -> void: part.visible = true)
	sequence.tween_property(part, "scale:y", target_scale.y, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sequence.parallel().tween_property(part, "position:y", target_position.y, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
