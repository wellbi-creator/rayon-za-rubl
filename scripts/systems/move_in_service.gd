extends Node
class_name MoveInService

signal readiness_updated(plot_id: int, completed_count: int, total_count: int)
signal house_ready(plot_id: int)

const REQUIREMENTS := [
	{"id": "electricity", "label": "Электричество", "cost": 18000},
	{"id": "water", "label": "Водоснабжение", "cost": 16000},
	{"id": "heating", "label": "Отопление", "cost": 22000},
	{"id": "plumbing", "label": "Сантехника", "cost": 14000},
	{"id": "finishing", "label": "Внутренняя отделка", "cost": 28000},
	{"id": "furniture", "label": "Мебель", "cost": 32000},
	{"id": "lighting", "label": "Освещение", "cost": 9000},
	{"id": "landscaping", "label": "Благоустройство", "cost": 11000}
]

var house_checklists: Dictionary = {}

func get_requirements() -> Array:
	return REQUIREMENTS.duplicate(true)

func get_checklist(plot_id: int) -> Dictionary:
	if not house_checklists.has(plot_id):
		house_checklists[plot_id] = {}
	return (house_checklists[plot_id] as Dictionary).duplicate(true)

func complete_requirement(plot_id: int, requirement_id: String) -> bool:
	var known_requirement := false
	for requirement in REQUIREMENTS:
		if str(requirement["id"]) == requirement_id:
			known_requirement = true
			break
	if not known_requirement:
		return false
	if not house_checklists.has(plot_id):
		house_checklists[plot_id] = {}
	var checklist: Dictionary = house_checklists[plot_id]
	if bool(checklist.get(requirement_id, false)):
		return false
	checklist[requirement_id] = true
	var completed := get_completed_count(plot_id)
	readiness_updated.emit(plot_id, completed, REQUIREMENTS.size())
	if completed == REQUIREMENTS.size():
		house_ready.emit(plot_id)
	return true

func get_completed_count(plot_id: int) -> int:
	var checklist: Dictionary = house_checklists.get(plot_id, {})
	var count := 0
	for requirement in REQUIREMENTS:
		if bool(checklist.get(str(requirement["id"]), false)):
			count += 1
	return count

func is_ready(plot_id: int) -> bool:
	return get_completed_count(plot_id) == REQUIREMENTS.size()

func get_save_data() -> Dictionary:
	return {"house_checklists": house_checklists.duplicate(true)}

func load_save_data(data: Dictionary) -> void:
	house_checklists.clear()
	var saved: Variant = data.get("house_checklists", {})
	if saved is Dictionary:
		for key in saved:
			var value: Variant = saved[key]
			if value is Dictionary:
				house_checklists[int(key)] = value.duplicate(true)
