extends Node
class_name ConstructionService

signal project_updated(plot_id: int, progress: float, stage: String)
signal project_completed(plot_id: int)
signal crew_count_changed(count: int)

const HOUSE_TYPES := {
	"ordinary": {"duration": 600.0, "label": "Обычный дом"},
	"advanced": {"duration": 1800.0, "label": "Продвинутый дом"},
	"premium": {"duration": 3600.0, "label": "Премиум-дом"}
}
const STAGES := [
	{"at": 0.0, "id": "site", "label": "Подготовка участка"},
	{"at": 0.12, "id": "foundation", "label": "Фундамент"},
	{"at": 0.28, "id": "walls", "label": "Стены"},
	{"at": 0.55, "id": "roof", "label": "Крыша"},
	{"at": 0.72, "id": "windows", "label": "Окна и двери"},
	{"at": 0.86, "id": "utilities", "label": "Коммуникации"},
	{"at": 0.96, "id": "finish", "label": "Отделка"}
]

var crew_count: int = 1
var projects: Dictionary = {}

func _process(delta: float) -> void:
	if projects.is_empty():
		return
	var completed: Array[int] = []
	for key in projects.keys():
		var plot_id := int(key)
		var project: Dictionary = projects[key]
		project["elapsed"] = minf(float(project["duration"]), float(project["elapsed"]) + delta)
		var progress := float(project["elapsed"]) / float(project["duration"])
		project_updated.emit(plot_id, progress, get_stage(progress))
		if progress >= 1.0:
			completed.append(plot_id)
	for plot_id in completed:
		projects.erase(plot_id)
		project_completed.emit(plot_id)

func start_project(plot_id: int, house_type: String = "ordinary") -> bool:
	if not HOUSE_TYPES.has(house_type) or projects.has(plot_id):
		return false
	if projects.size() >= crew_count:
		return false
	var config: Dictionary = HOUSE_TYPES[house_type]
	projects[plot_id] = {
		"type": house_type,
		"duration": float(config["duration"]),
		"elapsed": 0.0,
		"started_at": int(Time.get_unix_time_from_system())
	}
	return true

func hire_crew() -> void:
	crew_count += 1
	crew_count_changed.emit(crew_count)

func get_stage(progress: float) -> String:
	var result := "Подготовка участка"
	for stage in STAGES:
		if progress >= float(stage["at"]):
			result = str(stage["label"])
	return result

func get_project(plot_id: int) -> Dictionary:
	if not projects.has(plot_id):
		return {}
	return (projects[plot_id] as Dictionary).duplicate(true)

func apply_offline_progress(seconds: int) -> void:
	var completed: Array[int] = []
	for key in projects.keys():
		var plot_id := int(key)
		var project: Dictionary = projects[key]
		project["elapsed"] = minf(float(project["duration"]), float(project["elapsed"]) + float(maxi(0, seconds)))
		if float(project["elapsed"]) >= float(project["duration"]):
			completed.append(plot_id)
	for plot_id in completed:
		projects.erase(plot_id)
		project_completed.emit(plot_id)

func get_save_data() -> Dictionary:
	return {"crew_count": crew_count, "projects": projects.duplicate(true)}

func load_save_data(data: Dictionary, offline_seconds: int = 0) -> void:
	crew_count = maxi(1, int(data.get("crew_count", 1)))
	projects.clear()
	var saved: Variant = data.get("projects", {})
	if saved is Dictionary:
		for key in saved.keys():
			var item: Variant = saved[key]
			if item is Dictionary and HOUSE_TYPES.has(str(item.get("type", ""))):
				var type_id := str(item["type"])
				var duration := float(HOUSE_TYPES[type_id]["duration"])
				projects[int(key)] = {
					"type": type_id,
					"duration": duration,
					"elapsed": clampf(float(item.get("elapsed", 0.0)), 0.0, duration),
					"started_at": int(item.get("started_at", 0))
				}
	apply_offline_progress(offline_seconds)
	crew_count_changed.emit(crew_count)
