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
const MEMBER_SCHEDULES := {
	"child_one": [
		{"start_minute": 0, "end_minute": 420, "activity": "sleeping", "label": "Спит"},
		{"start_minute": 420, "end_minute": 480, "activity": "at_home", "label": "Дома, собирается"},
		{"start_minute": 480, "end_minute": 840, "activity": "at_school", "label": "На занятиях"},
		{"start_minute": 840, "end_minute": 1020, "activity": "at_home", "label": "Дома"},
		{"start_minute": 1020, "end_minute": 1200, "activity": "walking", "label": "Гуляет"},
		{"start_minute": 1200, "end_minute": 1320, "activity": "at_home", "label": "Дома, отдыхает"},
		{"start_minute": 1320, "end_minute": 1440, "activity": "sleeping", "label": "Спит"}
	]
}
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
const PREFERENCE_LABELS := {
	"walking": "Любит прогулки",
	"at_home": "Предпочитает отдых дома"
}
const ACTION_PREFERENCE_LABELS := {
	"meal": "Любит домашнюю еду",
	"shower": "Ценит свежесть",
	"rest": "Любит спокойный отдых",
	"leisure": "Любит развлечения"
}
const MEMBER_TEMPLATES := {
	"first_neighbors": [
		{"id": "adult_one", "name": "Взрослый 1", "role": "Взрослый", "need_rates": {"energy": 1.0, "hunger": 1.0, "hygiene": 1.0, "leisure": 1.0}, "preferences": {"favorite_activity": "walking", "favorite_action": "leisure"}},
		{"id": "adult_two", "name": "Взрослый 2", "role": "Взрослый", "need_rates": {"energy": 0.9, "hunger": 1.05, "hygiene": 0.95, "leisure": 1.1}, "preferences": {"favorite_activity": "at_home", "favorite_action": "meal"}},
		{"id": "child_one", "name": "Ребёнок", "role": "Ребёнок", "need_rates": {"energy": 1.15, "hunger": 1.2, "hygiene": 1.0, "leisure": 1.25}, "preferences": {"favorite_activity": "walking", "favorite_action": "leisure"}}
	]
}
const MAX_SIMULATION_MINUTES := 10080
const RELATIONSHIP_DEFAULT := 60
const RELATIONSHIP_LABELS := {"very_good": "Очень хорошие", "good": "Хорошие", "neutral": "Нейтральные", "strained": "Напряжённые"}

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


func _record_family_event(state: Dictionary, description: String, source: String, total_minute: int) -> void:
	var history: Array = state.get("activity_history", []).duplicate(true)
	var day := int(total_minute / 1440)
	var minute_of_day := posmod(total_minute, 1440)
	history.append({
		"day": day,
		"hour": int(minute_of_day / 60),
		"minute": posmod(minute_of_day, 60),
		"description": description,
		"source": source
	})
	while history.size() > 8:
		history.pop_front()
	state["activity_history"] = history


func _relationship_key(first_id: String, second_id: String) -> String:
	var ids := [first_id, second_id]
	ids.sort()
	return "%s|%s" % [ids[0], ids[1]]


func _record_relationship_milestones(state: Dictionary, first_id: String, second_id: String, previous_score: int, new_score: int, source: String, total_minute: int) -> void:
	var thresholds := [
		{"value": 70, "direction": "up", "description": "отношения стали хорошими"},
		{"value": 85, "direction": "up", "description": "отношения стали очень хорошими"},
		{"value": 45, "direction": "down", "description": "отношения стали напряжёнными"}
	]
	var first_name := first_id
	var second_name := second_id
	for member_value in state.get("members", []):
		if not member_value is Dictionary:
			continue
		var member: Dictionary = member_value
		if str(member.get("id", "")) == first_id:
			first_name = str(member.get("name", first_id))
		elif str(member.get("id", "")) == second_id:
			second_name = str(member.get("name", second_id))
	var recorded: Dictionary = state.get("relationship_milestones", {}).duplicate(true)
	var pair_key := _relationship_key(first_id, second_id)
	for threshold_value in thresholds:
		var threshold: Dictionary = threshold_value
		var value := int(threshold["value"])
		var direction := str(threshold["direction"])
		var crossed := previous_score < value and new_score >= value if direction == "up" else previous_score >= value and new_score < value
		var milestone_key := "%s|%s|%d" % [pair_key, direction, value]
		if not crossed or bool(recorded.get(milestone_key, false)):
			continue
		recorded[milestone_key] = true
		var description := "%s и %s: %s (%d/100)" % [first_name, second_name, str(threshold["description"]), new_score]
		_record_family_event(state, description, source, total_minute)
	state["relationship_milestones"] = recorded


func _create_relationships(members: Array) -> Dictionary:
	var relationships: Dictionary = {}
	for i in range(members.size()):
		if not members[i] is Dictionary:
			continue
		for j in range(i + 1, members.size()):
			if not members[j] is Dictionary:
				continue
			var first: Dictionary = members[i]
			var second: Dictionary = members[j]
			relationships[_relationship_key(str(first.get("id", "")), str(second.get("id", "")))] = RELATIONSHIP_DEFAULT
	return relationships


func _normalize_relationships(state: Dictionary) -> void:
	var members: Array = state.get("members", [])
	var relationships: Dictionary = state.get("relationships", {}).duplicate(true)
	for i in range(members.size()):
		if not members[i] is Dictionary:
			continue
		for j in range(i + 1, members.size()):
			if not members[j] is Dictionary:
				continue
			var first: Dictionary = members[i]
			var second: Dictionary = members[j]
			var key := _relationship_key(str(first.get("id", "")), str(second.get("id", "")))
			relationships[key] = clampi(int(relationships.get(key, RELATIONSHIP_DEFAULT)), 0, 100)
	state["relationships"] = relationships


func _get_member_relationship_average(state: Dictionary, member_id: String) -> float:
	var members: Array = state.get("members", [])
	var relationships: Dictionary = state.get("relationships", {})
	var total := 0.0
	var count := 0
	for other_value in members:
		if not other_value is Dictionary:
			continue
		var other: Dictionary = other_value
		var other_id := str(other.get("id", ""))
		if other_id == member_id:
			continue
		var key := _relationship_key(member_id, other_id)
		total += float(relationships.get(key, RELATIONSHIP_DEFAULT))
		count += 1
	return total / count if count > 0 else float(RELATIONSHIP_DEFAULT)


func _get_relationship_label(value: float) -> String:
	if value >= 85.0:
		return str(RELATIONSHIP_LABELS["very_good"])
	if value >= 70.0:
		return str(RELATIONSHIP_LABELS["good"])
	if value >= 45.0:
		return str(RELATIONSHIP_LABELS["neutral"])
	return str(RELATIONSHIP_LABELS["strained"])


func _update_relationships(state: Dictionary) -> void:
	var members: Array = state.get("members", [])
	var relationships: Dictionary = state.get("relationships", {}).duplicate(true)
	for i in range(members.size()):
		if not members[i] is Dictionary:
			continue
		var first: Dictionary = members[i]
		for j in range(i + 1, members.size()):
			if not members[j] is Dictionary:
				continue
			var second: Dictionary = members[j]
			var first_id := str(first.get("id", ""))
			var second_id := str(second.get("id", ""))
			var key := _relationship_key(first_id, second_id)
			var score := int(relationships.get(key, RELATIONSHIP_DEFAULT))
			var first_needs: Dictionary = first.get("needs", NEED_DEFAULTS)
			var second_needs: Dictionary = second.get("needs", NEED_DEFAULTS)
			var first_activity := str(first.get("activity", "at_home"))
			var second_activity := str(second.get("activity", "at_home"))
			var shared_activity := first_activity == second_activity and first_activity in ["at_home", "walking"]
			var first_ok := int(first.get("mood", 75)) >= 60 and float(first_needs.get("home_comfort", 75.0)) >= 40.0
			var second_ok := int(second.get("mood", 75)) >= 60 and float(second_needs.get("home_comfort", 75.0)) >= 40.0
			var first_strained := int(first.get("mood", 75)) < 35
			var second_strained := int(second.get("mood", 75)) < 35
			if shared_activity and first_ok and second_ok:
				score += 1
			elif first_strained or second_strained:
				score -= 1
			relationships[key] = clampi(score, 0, 100)
	state["relationships"] = relationships


func _apply_relationship_satisfaction(state: Dictionary, member: Dictionary) -> void:
	var average := _get_member_relationship_average(state, str(member.get("id", "")))
	var satisfaction := int(member.get("satisfaction", 75))
	if average >= 75.0:
		satisfaction += 1
	elif average < 35.0:
		satisfaction -= 1
	member["satisfaction"] = clampi(satisfaction, 0, 100)


func _create_member_states(family_id: String, starting_needs: Dictionary) -> Array:
	var result: Array = []
	var templates: Array = MEMBER_TEMPLATES.get(family_id, [])
	for template_value in templates:
		if not template_value is Dictionary:
			continue
		var template: Dictionary = template_value
		result.append({
			"id": str(template.get("id", "resident_%d" % result.size())),
			"name": str(template.get("name", "Житель")),
			"role": str(template.get("role", "Житель")),
			"preferences": template.get("preferences", {"favorite_activity": "walking", "favorite_action": "leisure"}).duplicate(true),
			"need_rates": template.get("need_rates", {}).duplicate(true),
			"needs": starting_needs.duplicate(true),
			"mood": 75,
			"satisfaction": 75,
			"autonomy_enabled": true,
			"action_cooldowns": {},
			"shared_time_cooldowns": {},
			"social_cooldown_until": -1,
			"last_action_label": "Пока действий не было",
			"last_action_minute": -1,
			"activity": str(_get_member_schedule_entry(str(template.get("id", "")), current_minute_of_day)["activity"]),
			"activity_label": str(_get_member_schedule_entry(str(template.get("id", "")), current_minute_of_day)["label"])
		})
	return result


func _normalize_member_states(state: Dictionary) -> void:
	var members: Array = state.get("members", [])
	for member_value in members:
		if not member_value is Dictionary:
			continue
		var member: Dictionary = member_value
		if not member.get("needs", {}) is Dictionary:
			member["needs"] = state.get("needs", NEED_DEFAULTS).duplicate(true)
		else:
			var member_needs: Dictionary = member["needs"]
			for key in NEED_DEFAULTS:
				if not member_needs.has(key):
					member_needs[key] = NEED_DEFAULTS[key]
			member["needs"] = member_needs
		member["mood"] = clampi(int(member.get("mood", state.get("mood", 75))), 0, 100)
		member["satisfaction"] = clampi(int(member.get("satisfaction", state.get("satisfaction", 75))), 0, 100)
		member["need_rates"] = member.get("need_rates", {}).duplicate(true)
		member["social_cooldown_until"] = int(member.get("social_cooldown_until", -1))
		var preferences: Dictionary = member.get("preferences", {"favorite_activity": "walking", "favorite_action": "leisure"}).duplicate(true)
		if not PREFERENCE_LABELS.has(str(preferences.get("favorite_activity", ""))):
			preferences["favorite_activity"] = "walking"
		if not ACTION_PREFERENCE_LABELS.has(str(preferences.get("favorite_action", ""))):
			preferences["favorite_action"] = "leisure"
		member["preferences"] = preferences
		member["autonomy_enabled"] = bool(member.get("autonomy_enabled", true))
		member["action_cooldowns"] = member.get("action_cooldowns", {}).duplicate(true)
		member["shared_time_cooldowns"] = member.get("shared_time_cooldowns", {}).duplicate(true)
		member["last_action_label"] = str(member.get("last_action_label", "Пока действий не было"))
		member["last_action_minute"] = int(member.get("last_action_minute", -1))
		var member_schedule := _get_member_schedule_entry(str(member.get("id", "")), current_minute_of_day)
		member["activity"] = str(member.get("activity", member_schedule["activity"]))
		member["activity_label"] = str(member.get("activity_label", member_schedule["label"]))
	state["members"] = members


func _refresh_family_aggregates(state: Dictionary) -> void:
	var members: Array = state.get("members", [])
	if members.is_empty():
		return
	var totals := {"energy": 0.0, "hunger": 0.0, "hygiene": 0.0, "leisure": 0.0, "home_comfort": 0.0}
	var mood_total := 0
	var satisfaction_total := 0
	var count := 0
	for member_value in members:
		if not member_value is Dictionary:
			continue
		var member: Dictionary = member_value
		var needs: Dictionary = member.get("needs", NEED_DEFAULTS)
		for key in totals:
			totals[key] = float(totals[key]) + float(needs.get(key, NEED_DEFAULTS[key]))
		mood_total += int(member.get("mood", 75))
		satisfaction_total += int(member.get("satisfaction", 75))
		count += 1
	if count == 0:
		return
	for key in totals:
		totals[key] = float(totals[key]) / count
	state["needs"] = totals
	state["mood"] = roundi(float(mood_total) / count)
	state["satisfaction"] = roundi(float(satisfaction_total) / count)


func _get_member_display_data(state: Dictionary) -> Array:
	var result: Array = []
	for member_value in state.get("members", []):
		if not member_value is Dictionary:
			continue
		var member: Dictionary = member_value
		var preferences: Dictionary = member.get("preferences", {})
		var favorite_activity := str(preferences.get("favorite_activity", "walking"))
		var favorite_action := str(preferences.get("favorite_action", "leisure"))
		result.append({
			"id": str(member.get("id", "")),
			"name": str(member.get("name", "Житель")),
			"role": str(member.get("role", "Житель")),
			"preferences": preferences.duplicate(true),
			"preferences_label": "%s • %s" % [
				str(PREFERENCE_LABELS.get(favorite_activity, "Любит прогулки")),
				str(ACTION_PREFERENCE_LABELS.get(favorite_action, "Любит развлечения"))
			],
			"relationship_average": _get_member_relationship_average(state, str(member.get("id", ""))),
			"relationship_label": _get_relationship_label(_get_member_relationship_average(state, str(member.get("id", "")))),
			"needs": member.get("needs", NEED_DEFAULTS).duplicate(true),
			"mood": int(member.get("mood", 75)),
			"satisfaction": int(member.get("satisfaction", 75)),
			"autonomy_enabled": bool(member.get("autonomy_enabled", true)),
			"last_action_label": str(member.get("last_action_label", "Пока действий не было")),
			"last_action_minute": int(member.get("last_action_minute", -1)),
			"activity": str(member.get("activity", "at_home")),
			"activity_label": str(member.get("activity_label", "Дома"))
		})
	return result

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
	profile["autonomy_enabled"] = bool(state.get("autonomy_enabled", true))
	profile["last_action_label"] = str(state.get("last_action_label", "Пока действий не было"))
	profile["last_action_source"] = str(state.get("last_action_source", ""))
	profile["last_action_minute"] = int(state.get("last_action_minute", -1))
	profile["needs"] = state.get("needs", NEED_DEFAULTS).duplicate(true)
	profile["members"] = _get_member_display_data(state)
	profile["activity_history"] = state.get("activity_history", []).duplicate(true)
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
		"autonomy_enabled": true,
		"last_action_label": "Пока действий не было",
		"last_action_source": "",
		"last_action_minute": -1,
		"needs": NEED_DEFAULTS.duplicate(true),
		"members": _create_member_states(family_id, NEED_DEFAULTS),
		"activity_history": [],
		"relationship_milestones": {}
	}
	moved_families[family_id]["relationships"] = _create_relationships(moved_families[family_id]["members"])
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
	for family_id in moved_families:
		var state: Dictionary = moved_families[family_id]
		var members: Array = state.get("members", [])
		for member_value in members:
			if not member_value is Dictionary:
				continue
			var member: Dictionary = member_value
			var schedule := _get_member_schedule_entry(str(member.get("id", "")), minute_of_day)
			var member_activity := str(schedule["activity"])
			member["activity"] = member_activity
			member["activity_label"] = str(schedule["label"])
			var sleeping := member_activity == "sleeping"
			var needs: Dictionary = member.get("needs", NEED_DEFAULTS).duplicate(true)
			var rates: Dictionary = member.get("need_rates", {})
			needs["hunger"] = clampf(float(needs.get("hunger", 80.0)) - 0.10 * float(rates.get("hunger", 1.0)), 0.0, 100.0)
			needs["hygiene"] = clampf(float(needs.get("hygiene", 80.0)) - 0.045 * float(rates.get("hygiene", 1.0)), 0.0, 100.0)
			needs["leisure"] = clampf(float(needs.get("leisure", 75.0)) - 0.035 * float(rates.get("leisure", 1.0)), 0.0, 100.0)
			if sleeping:
				needs["energy"] = clampf(float(needs.get("energy", 75.0)) + 0.35 * float(rates.get("energy", 1.0)), 0.0, 100.0)
			else:
				needs["energy"] = clampf(float(needs.get("energy", 75.0)) - 0.055 * float(rates.get("energy", 1.0)), 0.0, 100.0)
			member["needs"] = needs
		state["members"] = members
		_run_autonomous_action(state, total_minute, str(state.get("activity", "at_home")))
		if posmod(total_minute, 60) == 0:
			_run_autonomous_social_interaction(state, total_minute)
			_run_autonomous_shared_time(state, total_minute)
		if minute_of_day % 60 == 0:
			_update_relationships(state)
			members = state.get("members", [])
			for member_value in members:
				if not member_value is Dictionary:
					continue
				var member: Dictionary = member_value
				_update_mood_and_satisfaction(member, member.get("needs", NEED_DEFAULTS))
				_apply_relationship_satisfaction(state, member)
			state["members"] = members
			_refresh_family_aggregates(state)

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
	var preferences: Dictionary = state.get("preferences", {})
	var favorite_activity := str(preferences.get("favorite_activity", ""))
	if not favorite_activity.is_empty() and str(state.get("activity", "")) == favorite_activity and total / 5.0 >= 60.0:
		satisfaction += 1
	state["satisfaction"] = clampi(satisfaction, 0, 100)


func talk_to_family(plot_id: int, member_id: String) -> bool:
	if not occupied_homes.has(plot_id):
		return false
	var family_id := str(occupied_homes[plot_id])
	var state: Dictionary = moved_families.get(family_id, {})
	if state.is_empty():
		return false
	var members: Array = state.get("members", [])
	var speaker: Dictionary = {}
	for member_value in members:
		if member_value is Dictionary and str(member_value.get("id", "")) == member_id:
			speaker = member_value
			break
	if speaker.is_empty():
		return false
	var total_minute := _get_total_game_minutes()
	if total_minute < int(speaker.get("social_cooldown_until", -1)):
		return false
	if str(speaker.get("activity", "")) not in ["at_home", "walking"]:
		return false
	var relationships: Dictionary = state.get("relationships", {}).duplicate(true)
	var interacted := false
	for member_value in members:
		if not member_value is Dictionary:
			continue
		var other: Dictionary = member_value
		var other_id := str(other.get("id", ""))
		if other_id == member_id or str(other.get("activity", "")) not in ["at_home", "walking"]:
			continue
		var key := _relationship_key(member_id, other_id)
		relationships[key] = clampi(int(relationships.get(key, RELATIONSHIP_DEFAULT)) + 5, 0, 100)
		other["mood"] = clampi(int(other.get("mood", 75)) + 1, 0, 100)
		other["satisfaction"] = clampi(int(other.get("satisfaction", 75)) + 1, 0, 100)
		interacted = true
	if not interacted:
		return false
	speaker["mood"] = clampi(int(speaker.get("mood", 75)) + 1, 0, 100)
	speaker["satisfaction"] = clampi(int(speaker.get("satisfaction", 75)) + 1, 0, 100)
	speaker["social_cooldown_until"] = total_minute + 120
	speaker["last_action_label"] = "Поговорил(а) с семьёй"
	speaker["last_action_minute"] = total_minute
	_record_family_event(state, "%s поговорил(а) с семьёй" % str(speaker.get("name", "Житель")), "player", total_minute)
	state["relationships"] = relationships
	state["members"] = members
	_refresh_family_aggregates(state)
	residents_changed.emit(plot_id)
	return true


func talk_to_member(plot_id: int, speaker_id: String, target_id: String) -> bool:
	if not occupied_homes.has(plot_id) or speaker_id == target_id:
		return false
	var family_id := str(occupied_homes[plot_id])
	var state: Dictionary = moved_families.get(family_id, {})
	if state.is_empty():
		return false
	var members: Array = state.get("members", [])
	var speaker: Dictionary = {}
	var target: Dictionary = {}
	for member_value in members:
		if not member_value is Dictionary:
			continue
		var member: Dictionary = member_value
		if str(member.get("id", "")) == speaker_id:
			speaker = member
		elif str(member.get("id", "")) == target_id:
			target = member
	if speaker.is_empty() or target.is_empty():
		return false
	if str(speaker.get("activity", "")) not in ["at_home", "walking"] or str(target.get("activity", "")) not in ["at_home", "walking"]:
		return false
	var total_minute := _get_total_game_minutes()
	var cooldowns: Dictionary = speaker.get("targeted_social_cooldowns", {}).duplicate(true)
	if total_minute < int(cooldowns.get(target_id, -1)):
		return false
	var relationships: Dictionary = state.get("relationships", {}).duplicate(true)
	var key := _relationship_key(speaker_id, target_id)
	var previous_score := int(relationships.get(key, RELATIONSHIP_DEFAULT))
	var new_score := clampi(previous_score + 3, 0, 100)
	relationships[key] = new_score
	_record_relationship_milestones(state, speaker_id, target_id, previous_score, new_score, "player", total_minute)
	speaker["mood"] = clampi(int(speaker.get("mood", 75)) + 1, 0, 100)
	speaker["satisfaction"] = clampi(int(speaker.get("satisfaction", 75)) + 1, 0, 100)
	target["mood"] = clampi(int(target.get("mood", 75)) + 1, 0, 100)
	target["satisfaction"] = clampi(int(target.get("satisfaction", 75)) + 1, 0, 100)
	cooldowns[target_id] = total_minute + 60
	speaker["targeted_social_cooldowns"] = cooldowns
	speaker["last_action_label"] = "Поговорил(а) с %s" % str(target.get("name", "родственником"))
	speaker["last_action_minute"] = total_minute
	target["last_action_label"] = "Поговорил(а) с %s" % str(speaker.get("name", "родственником"))
	target["last_action_minute"] = total_minute
	state["relationships"] = relationships
	state["members"] = members
	_record_family_event(state, "%s поговорил(а) с %s" % [str(speaker.get("name", "Житель")), str(target.get("name", "родственником"))], "player", total_minute)
	_refresh_family_aggregates(state)
	residents_changed.emit(plot_id)
	return true


func spend_time_with_member(plot_id: int, speaker_id: String, target_id: String) -> bool:
	if not occupied_homes.has(plot_id) or speaker_id == target_id:
		return false
	var family_id := str(occupied_homes[plot_id])
	var state: Dictionary = moved_families.get(family_id, {})
	if state.is_empty():
		return false
	var members: Array = state.get("members", [])
	var speaker: Dictionary = {}
	var target: Dictionary = {}
	for member_value in members:
		if not member_value is Dictionary:
			continue
		var member: Dictionary = member_value
		if str(member.get("id", "")) == speaker_id:
			speaker = member
		elif str(member.get("id", "")) == target_id:
			target = member
	if speaker.is_empty() or target.is_empty():
		return false
	if str(speaker.get("activity", "")) not in ["at_home", "walking"] or str(target.get("activity", "")) not in ["at_home", "walking"]:
		return false
	var total_minute := _get_total_game_minutes()
	var cooldowns: Dictionary = speaker.get("shared_time_cooldowns", {}).duplicate(true)
	if total_minute < int(cooldowns.get(target_id, -1)):
		return false
	var relationships: Dictionary = state.get("relationships", {}).duplicate(true)
	var key := _relationship_key(speaker_id, target_id)
	var previous_score := int(relationships.get(key, RELATIONSHIP_DEFAULT))
	var new_score := clampi(previous_score + 5, 0, 100)
	relationships[key] = new_score
	_record_relationship_milestones(state, speaker_id, target_id, previous_score, new_score, "player", total_minute)
	for participant in [speaker, target]:
		participant["mood"] = clampi(int(participant.get("mood", 75)) + 2, 0, 100)
		participant["satisfaction"] = clampi(int(participant.get("satisfaction", 75)) + 2, 0, 100)
	cooldowns[target_id] = total_minute + 180
	speaker["shared_time_cooldowns"] = cooldowns
	speaker["last_action_label"] = "Провёл(а) время с %s" % str(target.get("name", "родственником"))
	speaker["last_action_minute"] = total_minute
	target["last_action_label"] = "Провёл(а) время с %s" % str(speaker.get("name", "родственником"))
	target["last_action_minute"] = total_minute
	state["relationships"] = relationships
	state["members"] = members
	_record_family_event(state, "%s провёл(а) время с %s" % [str(speaker.get("name", "Житель")), str(target.get("name", "родственником"))], "player", total_minute)
	_refresh_family_aggregates(state)
	residents_changed.emit(plot_id)
	return true


func get_shared_time_cooldown_remaining(plot_id: int, speaker_id: String, target_id: String) -> int:
	if not occupied_homes.has(plot_id):
		return -1
	var family_id := str(occupied_homes[plot_id])
	var state: Dictionary = moved_families.get(family_id, {})
	for member_value in state.get("members", []):
		if member_value is Dictionary and str(member_value.get("id", "")) == speaker_id:
			var cooldowns: Dictionary = member_value.get("shared_time_cooldowns", {})
			return maxi(0, int(cooldowns.get(target_id, -1)) - _get_total_game_minutes())
	return -1


func get_targeted_social_cooldown_remaining(plot_id: int, speaker_id: String, target_id: String) -> int:
	if not occupied_homes.has(plot_id):
		return -1
	var family_id := str(occupied_homes[plot_id])
	var state: Dictionary = moved_families.get(family_id, {})
	for member_value in state.get("members", []):
		if member_value is Dictionary and str(member_value.get("id", "")) == speaker_id:
			var cooldowns: Dictionary = member_value.get("targeted_social_cooldowns", {})
			return maxi(0, int(cooldowns.get(target_id, -1)) - _get_total_game_minutes())
	return -1


func get_targeted_relationship_data(plot_id: int, speaker_id: String, target_id: String) -> Dictionary:
	if not occupied_homes.has(plot_id) or speaker_id == target_id:
		return {}
	var family_id := str(occupied_homes[plot_id])
	var state: Dictionary = moved_families.get(family_id, {})
	if state.is_empty():
		return {}
	var members: Array = state.get("members", [])
	var speaker: Dictionary = {}
	var target: Dictionary = {}
	for member_value in members:
		if not member_value is Dictionary:
			continue
		var member: Dictionary = member_value
		if str(member.get("id", "")) == speaker_id:
			speaker = member
		elif str(member.get("id", "")) == target_id:
			target = member
	if speaker.is_empty() or target.is_empty():
		return {}
	var key := _relationship_key(speaker_id, target_id)
	var relationships: Dictionary = state.get("relationships", {})
	var remaining := get_targeted_social_cooldown_remaining(plot_id, speaker_id, target_id)
	var participants_available := str(speaker.get("activity", "")) in ["at_home", "walking"] and str(target.get("activity", "")) in ["at_home", "walking"]
	var score := float(relationships.get(key, RELATIONSHIP_DEFAULT))
	return {
		"score": score,
		"label": _get_relationship_label(score),
		"cooldown_remaining": remaining,
		"participants_available": participants_available,
		"available": participants_available and remaining <= 0
	}


func get_social_cooldown_remaining(plot_id: int, member_id: String) -> int:
	if not occupied_homes.has(plot_id):
		return -1
	var family_id := str(occupied_homes[plot_id])
	var state: Dictionary = moved_families.get(family_id, {})
	for member_value in state.get("members", []):
		if member_value is Dictionary and str(member_value.get("id", "")) == member_id:
			return maxi(0, int(member_value.get("social_cooldown_until", -1)) - _get_total_game_minutes())
	return -1


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
	var updated_needs: Dictionary = state.get("needs", NEED_DEFAULTS)
	_update_mood_and_satisfaction(state, updated_needs)
	residents_changed.emit(plot_id)
	return true

func _apply_action_to_state(state: Dictionary, action_id: String, total_minute: int, activity: String, source: String = "player") -> bool:
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
	var members: Array = state.get("members", [])
	var need_key := str(action["need"])
	for member_value in members:
		if not member_value is Dictionary:
			continue
		var member: Dictionary = member_value
		var needs: Dictionary = member.get("needs", NEED_DEFAULTS).duplicate(true)
		needs[need_key] = clampf(float(needs.get(need_key, 0.0)) + float(action["gain"]), 0.0, 100.0)
		member["needs"] = needs
	state["members"] = members
	_refresh_family_aggregates(state)
	cooldowns[action_id] = total_minute
	state["action_cooldowns"] = cooldowns
	state["last_action_label"] = str(action["label"])
	state["last_action_source"] = source
	state["last_action_minute"] = total_minute
	_record_family_event(state, "%s: %s" % [str(action["label"]), "действие игрока"], source, total_minute)
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
	var members: Array = state.get("members", [])
	for member_value in members:
		if not member_value is Dictionary:
			continue
		var member: Dictionary = member_value
		if not bool(member.get("autonomy_enabled", true)):
			continue
		var needs: Dictionary = member.get("needs", NEED_DEFAULTS)
		var member_activity := str(member.get("activity", activity))
		var candidates: Array = []
		if member_activity == "at_home":
			if float(needs.get("hunger", 100.0)) < 55.0:
				candidates.append("meal")
			if float(needs.get("hygiene", 100.0)) < 45.0:
				candidates.append("shower")
			if float(needs.get("energy", 100.0)) < 35.0:
				candidates.append("rest")
			if float(needs.get("leisure", 100.0)) < 45.0:
				candidates.append("leisure")
		elif member_activity == "walking" and float(needs.get("leisure", 100.0)) < 45.0:
			candidates.append("leisure")
		var preferences: Dictionary = member.get("preferences", {})
		var favorite_action := str(preferences.get("favorite_action", ""))
		if candidates.has(favorite_action):
			candidates.erase(favorite_action)
			candidates.push_front(favorite_action)
		for action_id in candidates:
			if _apply_action_to_member(member, str(action_id), total_minute, member_activity):
				state["last_action_label"] = "%s: %s" % [str(member.get("name", "Житель")), str(HOUSEHOLD_ACTIONS[action_id]["label"])]
				state["last_action_source"] = "autonomous"
				state["last_action_minute"] = total_minute
				_record_family_event(state, "%s самостоятельно: %s" % [str(member.get("name", "Житель")), str(HOUSEHOLD_ACTIONS[action_id]["label"])], "autonomous", total_minute)
				break
	state["members"] = members
	_refresh_family_aggregates(state)


func _run_autonomous_social_interaction(state: Dictionary, total_minute: int) -> void:
	if not bool(state.get("autonomy_enabled", true)):
		return
	var members: Array = state.get("members", [])
	if members.size() < 2:
		return
	var start_index := posmod(int(total_minute / 60), members.size())
	for offset in range(members.size()):
		var candidate_value: Variant = members[posmod(start_index + offset, members.size())]
		if not candidate_value is Dictionary:
			continue
		var speaker: Dictionary = candidate_value
		var speaker_id := str(speaker.get("id", ""))
		if not bool(speaker.get("autonomy_enabled", true)):
			continue
		if total_minute < int(speaker.get("social_cooldown_until", -1)):
			continue
		if str(speaker.get("activity", "")) not in ["at_home", "walking"]:
			continue
		var relationships: Dictionary = state.get("relationships", {}).duplicate(true)
		var participants := 0
		for other_value in members:
			if not other_value is Dictionary:
				continue
			var other: Dictionary = other_value
			var other_id := str(other.get("id", ""))
			if other_id == speaker_id or str(other.get("activity", "")) not in ["at_home", "walking"]:
				continue
			var key := _relationship_key(speaker_id, other_id)
			var previous_score := int(relationships.get(key, RELATIONSHIP_DEFAULT))
			var new_score := clampi(previous_score + 1, 0, 100)
			relationships[key] = new_score
			_record_relationship_milestones(state, speaker_id, other_id, previous_score, new_score, "autonomous", total_minute)
			other["mood"] = clampi(int(other.get("mood", 75)) + 1, 0, 100)
			other["satisfaction"] = clampi(int(other.get("satisfaction", 75)) + 1, 0, 100)
			participants += 1
		if participants == 0:
			continue
		speaker["mood"] = clampi(int(speaker.get("mood", 75)) + 1, 0, 100)
		speaker["satisfaction"] = clampi(int(speaker.get("satisfaction", 75)) + 1, 0, 100)
		speaker["social_cooldown_until"] = total_minute + 120
		speaker["last_action_label"] = "Самостоятельно поговорил(а) с семьёй"
		speaker["last_action_minute"] = total_minute
		state["relationships"] = relationships
		state["members"] = members
		state["last_action_label"] = "%s: разговор с семьёй" % str(speaker.get("name", "Житель"))
		state["last_action_source"] = "autonomous"
		state["last_action_minute"] = total_minute
		_record_family_event(state, "%s самостоятельно поговорил(а) с семьёй" % str(speaker.get("name", "Житель")), "autonomous", total_minute)
		_refresh_family_aggregates(state)
		return


func _run_autonomous_shared_time(state: Dictionary, total_minute: int) -> void:
	if not bool(state.get("autonomy_enabled", true)):
		return
	if str(state.get("last_action_source", "")) == "autonomous" and int(state.get("last_action_minute", -1)) == total_minute:
		return
	var members: Array = state.get("members", [])
	if members.size() < 2:
		return
	var start_index := posmod(int(total_minute / 60) + 1, members.size())
	var relationships: Dictionary = state.get("relationships", {}).duplicate(true)
	for speaker_offset in range(members.size()):
		var speaker_value: Variant = members[posmod(start_index + speaker_offset, members.size())]
		if not speaker_value is Dictionary:
			continue
		var speaker: Dictionary = speaker_value
		if not bool(speaker.get("autonomy_enabled", true)):
			continue
		if str(speaker.get("activity", "")) not in ["at_home", "walking"]:
			continue
		var speaker_id := str(speaker.get("id", ""))
		var cooldowns: Dictionary = speaker.get("shared_time_cooldowns", {}).duplicate(true)
		for target_offset in range(members.size()):
			var target_value: Variant = members[posmod(start_index + target_offset, members.size())]
			if not target_value is Dictionary:
				continue
			var target: Dictionary = target_value
			var target_id := str(target.get("id", ""))
			if target_id == speaker_id or not bool(target.get("autonomy_enabled", true)):
				continue
			if str(target.get("activity", "")) not in ["at_home", "walking"]:
				continue
			if total_minute < int(cooldowns.get(target_id, -1)):
				continue
			var key := _relationship_key(speaker_id, target_id)
			var previous_score := int(relationships.get(key, RELATIONSHIP_DEFAULT))
			if previous_score >= 100:
				continue
			var new_score := clampi(previous_score + 2, 0, 100)
			relationships[key] = new_score
			_record_relationship_milestones(state, speaker_id, target_id, previous_score, new_score, "autonomous", total_minute)
			for participant in [speaker, target]:
				participant["mood"] = clampi(int(participant.get("mood", 75)) + 1, 0, 100)
				participant["satisfaction"] = clampi(int(participant.get("satisfaction", 75)) + 1, 0, 100)
			cooldowns[target_id] = total_minute + 180
			speaker["shared_time_cooldowns"] = cooldowns
			speaker["last_action_label"] = "Провёл(а) время с %s" % str(target.get("name", "родственником"))
			speaker["last_action_minute"] = total_minute
			target["last_action_label"] = "Провёл(а) время с %s" % str(speaker.get("name", "родственником"))
			target["last_action_minute"] = total_minute
			state["relationships"] = relationships
			state["members"] = members
			state["last_action_label"] = "%s провёл(а) время с %s" % [str(speaker.get("name", "Житель")), str(target.get("name", "родственником"))]
			state["last_action_source"] = "autonomous"
			state["last_action_minute"] = total_minute
			_record_family_event(state, "%s самостоятельно провёл(а) время с %s" % [str(speaker.get("name", "Житель")), str(target.get("name", "родственником"))], "autonomous", total_minute)
			_refresh_family_aggregates(state)
			return


func _apply_action_to_member(member: Dictionary, action_id: String, total_minute: int, activity: String) -> bool:
	if not HOUSEHOLD_ACTIONS.has(action_id):
		return false
	var action: Dictionary = HOUSEHOLD_ACTIONS[action_id]
	var allowed_activities: Array = action.get("allowed", [])
	if not allowed_activities.has(activity):
		return false
	var cooldowns: Dictionary = member.get("action_cooldowns", {}).duplicate(true)
	var last_used := int(cooldowns.get(action_id, -1000000))
	if total_minute - last_used < int(action["cooldown"]):
		return false
	var needs: Dictionary = member.get("needs", NEED_DEFAULTS).duplicate(true)
	var need_key := str(action["need"])
	needs[need_key] = clampf(float(needs.get(need_key, 0.0)) + float(action["gain"]), 0.0, 100.0)
	member["needs"] = needs
	cooldowns[action_id] = total_minute
	member["action_cooldowns"] = cooldowns
	member["last_action_label"] = str(action["label"])
	member["last_action_minute"] = total_minute
	return true


func set_member_autonomy_enabled(plot_id: int, member_id: String, enabled: bool) -> bool:
	if not occupied_homes.has(plot_id):
		return false
	var family_id := str(occupied_homes[plot_id])
	var state: Dictionary = moved_families.get(family_id, {})
	var members: Array = state.get("members", [])
	for member_value in members:
		if not member_value is Dictionary:
			continue
		var member: Dictionary = member_value
		if str(member.get("id", "")) == member_id:
			member["autonomy_enabled"] = enabled
			state["members"] = members
			residents_changed.emit(plot_id)
			return true
	return false

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
	var family_schedule := _get_schedule_entry(current_minute_of_day)
	for family_id in moved_families:
		var state: Dictionary = moved_families[family_id]
		var changed := false
		var next_activity := str(family_schedule["activity"])
		if str(state.get("activity", "")) != next_activity:
			state["activity"] = next_activity
			state["activity_label"] = str(family_schedule["label"])
			state["last_schedule_day"] = current_day
			changed = true
		var members: Array = state.get("members", [])
		for member_value in members:
			if not member_value is Dictionary:
				continue
			var member: Dictionary = member_value
			var member_schedule := _get_member_schedule_entry(str(member.get("id", "")), current_minute_of_day)
			if str(member.get("activity", "")) != str(member_schedule["activity"]):
				member["activity"] = str(member_schedule["activity"])
				member["activity_label"] = str(member_schedule["label"])
				changed = true
		state["members"] = members
		if changed:
			residents_changed.emit(int(state.get("plot_id", -1)))

func _get_member_schedule_entry(member_id: String, minute_of_day: int) -> Dictionary:
	var schedule: Array = MEMBER_SCHEDULES.get(member_id, DAILY_SCHEDULE)
	for entry in schedule:
		if minute_of_day >= int(entry["start_minute"]) and minute_of_day < int(entry["end_minute"]):
			return entry
	return schedule[0]

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
			"activity_label": str(state.get("activity_label", "Дома")),
			"members": _get_member_display_data(state)
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
				if not restored.get("activity_history", []) is Array:
					restored["activity_history"] = []
				else:
					restored["activity_history"] = restored["activity_history"].duplicate(true)
				if not restored.get("relationship_milestones", {}) is Dictionary:
					restored["relationship_milestones"] = {}
				else:
					restored["relationship_milestones"] = restored["relationship_milestones"].duplicate(true)
				restored["autonomy_enabled"] = bool(restored.get("autonomy_enabled", true))
				if not restored.has("needs") or not restored["needs"] is Dictionary:
					restored["needs"] = NEED_DEFAULTS.duplicate(true)
				else:
					for need_key in NEED_DEFAULTS:
						if not restored["needs"].has(need_key):
							restored["needs"][need_key] = NEED_DEFAULTS[need_key]
				if not restored.has("members") or not restored["members"] is Array or restored["members"].is_empty():
					restored["members"] = _create_member_states(str(family_id), restored["needs"])
				else:
					_normalize_member_states(restored)
				_normalize_relationships(restored)
				_refresh_family_aggregates(restored)
				moved_families[str(family_id)] = restored
	last_simulated_total_minute = int(data.get("last_simulated_total_minute", -1))
