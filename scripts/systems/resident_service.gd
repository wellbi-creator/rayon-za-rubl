extends Node
class_name ResidentService

signal residents_changed(plot_id: int)
signal family_moved_in(plot_id: int, family_id: String)

# Daily routine is deliberately data-driven so later families can have individual schedules.
const DAILY_SCHEDULE := [
	{"start_minute": 0, "end_minute": 360, "activity": "sleeping", "label": "Спят"},
	{"start_minute": 360, "end_minute": 480, "activity": "at_home", "label": "Дома, собираются"},
	{"start_minute": 480, "end_minute": 1020, "activity": "at_work", "label": "На работе"},
	{"start_minute": 1020, "end_minute": 1200, "activity": "walking", "label": "Гуляют в районе"},
	{"start_minute": 1200, "end_minute": 1320, "activity": "at_home", "label": "Дома, отдыхают"},
	{"start_minute": 1320, "end_minute": 1440, "activity": "sleeping", "label": "Спят"}
]

const FAMILY_CATALOG := {
	"first_neighbors": {
		"id": "first_neighbors",
		"title": "Первые соседи",
		"members_count": 3,
		"description": "Первая семья, которая готова начать новую жизнь в восстановленном районе.",
		"initial_mood": 75,
		"initial_satisfaction": 75
	}
}

var occupied_homes: Dictionary = {}
var moved_families: Dictionary = {}
var current_minute_of_day: int = 480
var current_day: int = 1

func get_family_catalog() -> Array:
	var result: Array = []
	for family_id in FAMILY_CATALOG:
		result.append((FAMILY_CATALOG[family_id] as Dictionary).duplicate(true))
	return result

func get_available_families() -> Array:
	var result: Array = []
	for family_id in FAMILY_CATALOG:
		if not moved_families.has(family_id):
			result.append((FAMILY_CATALOG[family_id] as Dictionary).duplicate(true))
	return result

func get_family_at_plot(plot_id: int) -> Dictionary:
	var family_id := str(occupied_homes.get(plot_id, ""))
	if family_id.is_empty() or not FAMILY_CATALOG.has(family_id):
		return {}
	var profile: Dictionary = FAMILY_CATALOG[family_id].duplicate(true)
	var state: Dictionary = moved_families[family_id]
	profile["mood"] = int(state.get("mood", profile["initial_mood"]))
	profile["satisfaction"] = int(state.get("satisfaction", profile["initial_satisfaction"]))
	profile["relationship"] = int(state.get("relationship", 0))
	profile["activity"] = str(state.get("activity", "at_home"))
	profile["activity_label"] = str(state.get("activity_label", "Дома"))
	return profile

func is_plot_occupied(plot_id: int) -> bool:
	return occupied_homes.has(plot_id)

func move_family_in(family_id: String, plot_id: int, house_ready: bool) -> bool:
	if not house_ready or plot_id < 1 or is_plot_occupied(plot_id):
		return false
	if not FAMILY_CATALOG.has(family_id) or moved_families.has(family_id):
		return false
	var profile: Dictionary = FAMILY_CATALOG[family_id]
	var schedule: Dictionary = _get_schedule_entry(current_minute_of_day)
	occupied_homes[plot_id] = family_id
	moved_families[family_id] = {
		"plot_id": plot_id,
		"mood": int(profile["initial_mood"]),
		"satisfaction": int(profile["initial_satisfaction"]),
		"relationship": 0,
		"moved_in_at": int(Time.get_unix_time_from_system()),
		"activity": str(schedule["activity"]),
		"activity_label": str(schedule["label"])
	}
	residents_changed.emit(plot_id)
	family_moved_in.emit(plot_id, family_id)
	return true

func update_time(hour: int, minute: int, day: int) -> void:
	current_minute_of_day = posmod(hour * 60 + minute, 1440)
	current_day = maxi(1, day)
	var schedule := _get_schedule_entry(current_minute_of_day)
	for family_id in moved_families:
		var state: Dictionary = moved_families[family_id]
		var next_activity := str(schedule["activity"])
		if str(state.get("activity", "")) == next_activity:
			continue
		state["activity"] = next_activity
		state["activity_label"] = str(schedule["label"])
		state["last_schedule_day"] = current_day
		residents_changed.emit(int(state.get("plot_id", -1)))

func _get_schedule_entry(minute_of_day: int) -> Dictionary:
	for entry in DAILY_SCHEDULE:
		if minute_of_day >= int(entry["start_minute"]) and minute_of_day < int(entry["end_minute"]):
			return entry
	return DAILY_SCHEDULE[0]

func get_daily_schedule() -> Array:
	return DAILY_SCHEDULE.duplicate(true)

func get_occupied_home_count() -> int:
	return occupied_homes.size()

func get_resident_display_data() -> Array:
	var result: Array = []
	for plot_id in occupied_homes:
		var family_id := str(occupied_homes[plot_id])
		var profile: Dictionary = FAMILY_CATALOG.get(family_id, {})
		var state: Dictionary = moved_families.get(family_id, {})
		result.append({
			"plot_id": int(plot_id),
			"members_count": int(profile.get("members_count", 0)),
			"activity": str(state.get("activity", "at_home")),
			"activity_label": str(state.get("activity_label", "Дома"))
		})
	return result

func get_total_resident_count() -> int:
	var total := 0
	for family_id in moved_families:
		var profile: Dictionary = FAMILY_CATALOG.get(family_id, {})
		total += int(profile.get("members_count", 0))
	return total

func get_save_data() -> Dictionary:
	return {
		"occupied_homes": occupied_homes.duplicate(true),
		"moved_families": moved_families.duplicate(true)
	}

func load_save_data(data: Dictionary) -> void:
	occupied_homes.clear()
	moved_families.clear()
	var saved_homes: Variant = data.get("occupied_homes", {})
	var saved_families: Variant = data.get("moved_families", {})
	if saved_homes is Dictionary:
		for plot_id in saved_homes:
			var family_id := str(saved_homes[plot_id])
			if FAMILY_CATALOG.has(family_id):
				occupied_homes[int(plot_id)] = family_id
	if saved_families is Dictionary:
		for family_id in saved_families:
			var saved_profile: Variant = saved_families[family_id]
			if FAMILY_CATALOG.has(str(family_id)) and saved_profile is Dictionary:
				moved_families[str(family_id)] = saved_profile.duplicate(true)
