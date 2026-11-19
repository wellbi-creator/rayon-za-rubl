extends Node
class_name ResidentService

signal residents_changed(plot_id: int)
signal family_moved_in(plot_id: int, family_id: String)

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
const NEED_DEFAULTS := {"energy": 75.0, "hunger": 80.0, "hygiene": 80.0, "leisure": 75.0, "home_comfort": 75.0}
const MAX_SIMULATION_MINUTES := 10080

const HOUSEHOLD_ACTIONS := {
	"meal": {"label": "Приготовить еду", "need": "hunger", "gain": 35.0, "cooldown": 180, "allowed": ["at_home"]},
	"shower": {"label": "Принять душ", "need": "hygiene", "gain": 45.0, "cooldown": 240, "allowed": ["at_home"]},
	"rest": {"label": "Отдохнуть", "need": "energy", "gain": 30.0, "cooldown": 180, "allowed": ["at_home", "sleeping"]},
	"leisure": {"label": "Досуг", "need": "leisure", "gain": 35.0, "cooldown": 180, "allowed": ["at_home", "walking"]}
}

var occupied_homes: Dictionary = {}
var moved_families: Dictionary = {}
var current_minute_of_day: int = 480
var current_day: int = 1
var last_simulated_total_minute: int = -1

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
	profile["needs"] = state.get("needs", NEED_DEFAULTS).duplicate(true)
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
		"activity_label": str(schedule["label"]),
		"needs": NEED_DEFAULTS.duplicate(true)
	}
	last_simulated_total_minute = _get_total_game_minutes()
	residents_changed.emit(plot_id)
	family_moved_in.emit(plot_id, family_id)
	return true

func update_time(hour: int, minute: int, day: int) -> void:
	current_minute_of_day = posmod(hour * 60 + minute, 1440)
	current_day = maxi(1, day)
	var total_minutes := _get_total_game_minutes()
	if last_simulated_total_minute < 0:
		last_simulated_total_minute = total_minutes
		_update_activities()
		return
	var elapsed := maxi(0, total_minutes - last_simulated_total_minute)
	var simulated := mini(elapsed, MAX_SIMULATION_MINUTES)
	if elapsed > MAX_SIMULATION_MINUTES:
		last_simulated_total_minute = total_minutes - MAX_SIMULATION_MINUTES
	for _minute in simulated:
		last_simulated_total_minute += 1
		_simulate_needs_minute(last_simulated_total_minute)
	last_simulated_total_minute = total_minutes
	_update_activities()
	if simulated > 0:
		for family_id in moved_families:
			var state: Dictionary = moved_families[family_id]
			residents_changed.emit(int(state.get("plot_id", -1)))

func _get_total_game_minutes() -> int:
	return current_day * 1440 + current_minute_of_day

func _simulate_needs_minute(total_minute: int) -> void:
	var minute_of_day := posmod(total_minute, 1440)
	var schedule := _get_schedule_entry(minute_of_day)
	var sleeping := str(schedule["activity"]) == "sleeping"
	for family_id in moved_families:
		var state: Dictionary = moved_families[family_id]
		var needs: Dictionary = state.get("needs", NEED_DEFAULTS).duplicate(true)
		needs["hunger"] = clampf(float(needs.get("hunger", 80.0)) - 0.10, 0.0, 100.0)
		needs["hygiene"] = clampf(float(needs.get("hygiene", 80.0)) - 0.045, 0.0, 100.0)
		needs["leisure"] = clampf(float(needs.get("leisure", 75.0)) - 0.035, 0.0, 100.0)
		if sleeping:
			needs["energy"] = clampf(float(needs.get("energy", 75.0)) + 0.35, 0.0, 100.0)
		else:
			needs["energy"] = clampf(float(needs.get("energy", 75.0)) - 0.055, 0.0, 100.0)
		state["needs"] = needs
		var activity := str(schedule["activity"])
		_run_autonomous_action(state, total_minute, activity)
		if minute_of_day % 60 == 0:
			_update_mood_and_satisfaction(state, state.get("needs", needs))

func _update_mood_and_satisfaction(state: Dictionary, needs: Dictionary) -> void:
	var critical_count := 0
	var total := 0.0
	for key in ["energy", "hunger", "hygiene", "leisure", "home_comfort"]:
		var value := float(needs.get(key, 75.0))
		total += value
		if value < 30.0:
			critical_count += 1
	var mood := int(state.get("mood", 75))
	if critical_count > 0:
		mood -= mini(2, critical_count)
	elif total / 5.0 >= 65.0:
		mood += 1
	state["mood"] = clampi(mood, 0, 100)
	var satisfaction := int(state.get("satisfaction", 75))
	if float(needs.get("home_comfort", 75.0)) < 35.0:
		satisfaction -= 1
	elif total / 5.0 >= 70.0:
		satisfaction += 1
	state["satisfaction"] = clampi(satisfaction, 0, 100)


func apply_household_action(plot_id: int, action_id: String) -> bool:
	if not occupied_homes.has(plot_id) or not HOUSEHOLD_ACTIONS.has(action_id):
		return false
	var family_id := str(occupied_homes[plot_id])
	if not moved_families.has(family_id):
		return false
	var action: Dictionary = HOUSEHOLD_ACTIONS[action_id]
	var state: Dictionary = moved_families[family_id]
	var activity := str(state.get("activity", "at_home"))
	if not _apply_action_to_state(state, action_id, _get_total_game_minutes(), activity):
		return false
	_update_mood_and_satisfaction(state, state.get("needs", NEED_DEFAULTS))
	residents_changed.emit(plot_id)
	return true

func _apply_action_to_state(state: Dictionary, action_id: String, total_minute: int, activity: String) -> bool:
	if not HOUSEHOLD_ACTIONS.has(action_id):
		return false
	var action: Dictionary = HOUSEHOLD_ACTIONS[action_id]
	var allowed_activities: Array = action.get("allowed", [])
	if not allowed_activities.has(activity):
		return false
	var cooldowns: Dictionary = state.get("action_cooldowns", {}).duplicate(true)
	var last_used := int(cooldowns.get(action_id, -1000000))
	if total_minute - last_used < int(action["cooldown"]):
		return false
	var needs: Dictionary = state.get("needs", NEED_DEFAULTS).duplicate(true)
	var need_key := str(action["need"])
	needs[need_key] = clampf(float(needs.get(need_key, 0.0)) + float(action["gain"]), 0.0, 100.0)
	state["needs"] = needs
	cooldowns[action_id] = total_minute
	state["action_cooldowns"] = cooldowns
	return true

func set_autonomy_enabled(plot_id: int, enabled: bool) -> bool:
	if not occupied_homes.has(plot_id):
		return false
	var family_id := str(occupied_homes[plot_id])
	if not moved_families.has(family_id):
		return false
	var state: Dictionary = moved_families[family_id]
	state["autonomy_enabled"] = enabled
	residents_changed.emit(plot_id)
	return true

func is_autonomy_enabled(plot_id: int) -> bool:
	if not occupied_homes.has(plot_id):
		return false
	var family_id := str(occupied_homes[plot_id])
	var state: Dictionary = moved_families.get(family_id, {})
	return bool(state.get("autonomy_enabled", true))

func _run_autonomous_action(state: Dictionary, total_minute: int, activity: String) -> void:
	if not bool(state.get("autonomy_enabled", true)):
		return
	var needs: Dictionary = state.get("needs", NEED_DEFAULTS)
	var candidates: Array = []
	if activity == "at_home":
		if float(needs.get("hunger", 100.0)) < 55.0:
			candidates.append("meal")
		if float(needs.get("hygiene", 100.0)) < 45.0:
			candidates.append("shower")
		if float(needs.get("energy", 100.0)) < 35.0:
			candidates.append("rest")
		if float(needs.get("leisure", 100.0)) < 45.0:
			candidates.append("leisure")
	elif activity == "walking" and float(needs.get("leisure", 100.0)) < 45.0:
		candidates.append("leisure")
	for action_id in candidates:
		if _apply_action_to_state(state, str(action_id), total_minute, activity):
			return

func get_household_action_cooldown(plot_id: int, action_id: String) -> int:
	if not occupied_homes.has(plot_id) or not HOUSEHOLD_ACTIONS.has(action_id):
		return -1
	var family_id := str(occupied_homes[plot_id])
	var state: Dictionary = moved_families.get(family_id, {})
	var cooldowns: Dictionary = state.get("action_cooldowns", {})
	var last_used := int(cooldowns.get(action_id, -1000000))
	return maxi(0, int(HOUSEHOLD_ACTIONS[action_id]["cooldown"]) - (_get_total_game_minutes() - last_used))

func get_household_action_label(action_id: String) -> String:
	if not HOUSEHOLD_ACTIONS.has(action_id):
		return ""
	return str(HOUSEHOLD_ACTIONS[action_id]["label"])

func _update_activities() -> void:
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
		"moved_families": moved_families.duplicate(true),
		"last_simulated_total_minute": last_simulated_total_minute
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
				var restored: Dictionary = saved_profile.duplicate(true)
				if not restored.has("needs") or not restored["needs"] is Dictionary:
					restored["needs"] = NEED_DEFAULTS.duplicate(true)
				else:
					for need_key in NEED_DEFAULTS:
						if not restored["needs"].has(need_key):
							restored["needs"][need_key] = NEED_DEFAULTS[need_key]
				moved_families[str(family_id)] = restored
	last_simulated_total_minute = int(data.get("last_simulated_total_minute", -1))
