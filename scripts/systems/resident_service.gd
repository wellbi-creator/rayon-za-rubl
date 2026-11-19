extends Node
class_name ResidentService

signal residents_changed(plot_id: int)
signal family_moved_in(plot_id: int, family_id: String)

# Starter content is data-driven. Story names and individual biographies can be authored later.
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
	profile["mood"] = int(moved_families[family_id].get("mood", profile["initial_mood"]))
	profile["satisfaction"] = int(moved_families[family_id].get("satisfaction", profile["initial_satisfaction"]))
	profile["relationship"] = int(moved_families[family_id].get("relationship", 0))
	return profile

func is_plot_occupied(plot_id: int) -> bool:
	return occupied_homes.has(plot_id)

func move_family_in(family_id: String, plot_id: int, house_ready: bool) -> bool:
	if not house_ready or plot_id < 1 or is_plot_occupied(plot_id):
		return false
	if not FAMILY_CATALOG.has(family_id) or moved_families.has(family_id):
		return false
	var profile: Dictionary = FAMILY_CATALOG[family_id]
	occupied_homes[plot_id] = family_id
	moved_families[family_id] = {
		"plot_id": plot_id,
		"mood": int(profile["initial_mood"]),
		"satisfaction": int(profile["initial_satisfaction"]),
		"relationship": 0,
		"moved_in_at": int(Time.get_unix_time_from_system())
	}
	residents_changed.emit(plot_id)
	family_moved_in.emit(plot_id, family_id)
	return true

func get_occupied_home_count() -> int:
	return occupied_homes.size()

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
