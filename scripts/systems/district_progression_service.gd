extends RefCounted
class_name DistrictProgressionService

const LEVEL_XP_THRESHOLDS := [0, 100, 250, 450, 700, 1000, 1400, 1850, 2350, 2900]
const MAX_RECENT_EVENTS := 20
const ACHIEVEMENTS := [
	{"id": "baba_helper", "title": "Доброе начало", "description": "Восстановить электрику в доме Бабы Зины"},
	{"id": "first_house", "title": "Первый дом", "description": "Завершить строительство первого дома"},
	{"id": "first_ready_home", "title": "Готов к жизни", "description": "Полностью подготовить дом к заселению"},
	{"id": "first_family", "title": "Новые соседи", "description": "Заселить первую семью"},
	{"id": "first_worker", "title": "Городские службы", "description": "Нанять первого работника коммунальной службы"},
	{"id": "first_district_event", "title": "На связи с жителями", "description": "Принять решение по первому районному событию"}
]

var experience: int = 0
var reputation: int = 0
var unlocked_achievements: Dictionary = {}
var recent_events: Array[Dictionary] = []

func get_level() -> int:
	var level := 1
	for index in range(LEVEL_XP_THRESHOLDS.size()):
		if experience >= int(LEVEL_XP_THRESHOLDS[index]):
			level = index + 1
	return level

func get_current_level_threshold() -> int:
	return int(LEVEL_XP_THRESHOLDS[get_level() - 1])

func get_next_level_threshold() -> int:
	var level := get_level()
	if level >= LEVEL_XP_THRESHOLDS.size():
		return int(LEVEL_XP_THRESHOLDS[LEVEL_XP_THRESHOLDS.size() - 1])
	return int(LEVEL_XP_THRESHOLDS[level])

func get_experience_progress() -> int:
	return maxi(0, experience - get_current_level_threshold())

func get_experience_needed() -> int:
	return maxi(0, get_next_level_threshold() - get_current_level_threshold())

func add_progress(experience_gain: int, reputation_gain: int, reason: String) -> void:
	var safe_xp := maxi(0, experience_gain)
	var safe_reputation := maxi(-100, reputation_gain)
	if safe_xp == 0 and safe_reputation == 0:
		return
	experience += safe_xp
	reputation = clampi(reputation + safe_reputation, 0, 100)
	recent_events.append({
		"experience": safe_xp,
		"reputation": safe_reputation,
		"reason": reason,
		"timestamp": int(Time.get_unix_time_from_system())
	})
	while recent_events.size() > MAX_RECENT_EVENTS:
		recent_events.pop_front()

func unlock_achievement(achievement_id: String) -> bool:
	if unlocked_achievements.has(achievement_id):
		return false
	for achievement in ACHIEVEMENTS:
		if str(achievement["id"]) == achievement_id:
			unlocked_achievements[achievement_id] = int(Time.get_unix_time_from_system())
			return true
	return false

func get_achievements() -> Array:
	var result: Array = []
	for achievement in ACHIEVEMENTS:
		var entry: Dictionary = achievement.duplicate(true)
		entry["unlocked"] = unlocked_achievements.has(str(entry["id"]))
		entry["unlocked_at"] = int(unlocked_achievements.get(str(entry["id"]), 0))
		result.append(entry)
	return result

func get_recent_events() -> Array[Dictionary]:
	return recent_events.duplicate(true)

func get_save_data() -> Dictionary:
	return {
		"experience": experience,
		"reputation": reputation,
		"unlocked_achievements": unlocked_achievements.duplicate(true),
		"recent_events": recent_events.duplicate(true)
	}

func load_save_data(data: Dictionary) -> void:
	experience = maxi(0, int(data.get("experience", 0)))
	reputation = clampi(int(data.get("reputation", 0)), 0, 100)
	unlocked_achievements.clear()
	var saved_achievements: Variant = data.get("unlocked_achievements", {})
	if saved_achievements is Dictionary:
		for achievement in ACHIEVEMENTS:
			var achievement_id := str(achievement["id"])
			if saved_achievements.has(achievement_id):
				unlocked_achievements[achievement_id] = maxi(0, int(saved_achievements[achievement_id]))
	recent_events.clear()
	var saved_events: Variant = data.get("recent_events", [])
	if saved_events is Array:
		for event in saved_events:
			if event is Dictionary:
				recent_events.append({
					"experience": maxi(0, int(event.get("experience", 0))),
					"reputation": int(event.get("reputation", 0)),
					"reason": str(event.get("reason", "Развитие района")),
					"timestamp": maxi(0, int(event.get("timestamp", 0)))
				})
	while recent_events.size() > MAX_RECENT_EVENTS:
		recent_events.pop_front()
