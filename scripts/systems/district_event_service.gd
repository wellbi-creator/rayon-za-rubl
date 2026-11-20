extends RefCounted
class_name DistrictEventService

const MAX_EVENT_HISTORY := 20
const EVENTS := [
	{
		"id": "streetlight_failure",
		"title": "Погас уличный фонарь",
		"description": "Жители сообщили, что уличный фонарь перестал работать. Вечером этот участок стал заметно темнее.",
		"service_id": "electricity",
		"discount_percent": 30,
		"choices": [
			{"id": "repair", "label": "Вызвать электрика", "cost": 2500, "reputation": 5, "experience": 25},
			{"id": "delay", "label": "Отложить ремонт", "cost": 0, "reputation": -3, "experience": 0}
		]
	},
	{
		"id": "blocked_drain",
		"title": "Засор ливневки",
		"description": "После дождя вода задерживается у дороги. Сантехники могут прочистить сток, пока проблема не стала серьёзнее.",
		"service_id": "plumbing",
		"discount_percent": 25,
		"choices": [
			{"id": "clear", "label": "Прочистить сток", "cost": 3200, "reputation": 6, "experience": 30},
			{"id": "ignore", "label": "Пока ничего не делать", "cost": 0, "reputation": -4, "experience": 0}
		]
	},
	{
		"id": "trash_overflow",
		"title": "Переполненные контейнеры",
		"description": "Контейнеры у домов переполнены. Жители просят организовать дополнительный вывоз мусора.",
		"service_id": "waste",
		"discount_percent": 30,
		"choices": [
			{"id": "collect", "label": "Организовать вывоз", "cost": 2000, "reputation": 4, "experience": 20},
			{"id": "postpone", "label": "Перенести на потом", "cost": 0, "reputation": -3, "experience": 0}
		]
	},
	{
		"id": "icy_road",
		"title": "Гололёд на улице",
		"description": "На дороге образовался лёд. Снегоуборочная служба может обработать опасный участок.",
		"service_id": "snow",
		"discount_percent": 35,
		"choices": [
			{"id": "treat", "label": "Обработать дорогу", "cost": 2200, "reputation": 5, "experience": 25},
			{"id": "wait", "label": "Дождаться потепления", "cost": 0, "reputation": -4, "experience": 0}
		]
	},
	{
		"id": "road_pothole",
		"title": "Яма на дороге",
		"description": "Жители заметили яму на проезжей части. Дорожные рабочие могут быстро устранить повреждение.",
		"service_id": "road",
		"discount_percent": 25,
		"choices": [
			{"id": "patch", "label": "Отремонтировать дорогу", "cost": 3800, "reputation": 7, "experience": 35},
			{"id": "mark", "label": "Пока только обозначить яму", "cost": 0, "reputation": -2, "experience": 0}
		]
	}
]

var rng := RandomNumberGenerator.new()
var active_event: Dictionary = {}
var event_history: Array[Dictionary] = []
var last_processed_day: int = 1
var next_event_day: int = 3

func _init() -> void:
	rng.randomize()

func process_day(day: int) -> bool:
	if day <= last_processed_day:
		return false
	last_processed_day = day
	if not active_event.is_empty() or day < next_event_day:
		return false
	var definition: Dictionary = EVENTS[rng.randi_range(0, EVENTS.size() - 1)].duplicate(true)
	definition["created_day"] = day
	active_event = definition
	return true

func has_active_event() -> bool:
	return not active_event.is_empty()

func get_active_event() -> Dictionary:
	return active_event.duplicate(true)

func get_choice_cost(choice_id: String, municipal_services: MunicipalServicesService) -> int:
	var choice := _get_choice(choice_id)
	if choice.is_empty():
		return -1
	var base_cost := maxi(0, int(choice.get("cost", 0)))
	var service_id := str(active_event.get("service_id", ""))
	var discount := clampi(int(active_event.get("discount_percent", 0)), 0, 80)
	if municipal_services != null and municipal_services.get_employee_count(service_id) > 0:
		return roundi(float(base_cost * (100 - discount)) / 100.0)
	return base_cost

func resolve_choice(choice_id: String, day: int, economy: EconomyService, municipal_services: MunicipalServicesService) -> Dictionary:
	if active_event.is_empty():
		return {"success": false, "message": "Сейчас нет активного события."}
	var choice := _get_choice(choice_id)
	if choice.is_empty():
		return {"success": false, "message": "Этот вариант решения больше недоступен."}
	var cost := get_choice_cost(choice_id, municipal_services)
	if cost < 0:
		return {"success": false, "message": "Не удалось рассчитать стоимость решения."}
	if cost > 0 and (economy == null or not economy.try_spend(cost, "Решение события: %s" % str(active_event.get("title", "Событие района")))):
		return {"success": false, "message": "Не хватает средств. Выбери другой вариант или найди деньги."}
	var title := str(active_event.get("title", "Событие района"))
	var reason := "Решение события: %s" % title
	var result := {
		"success": true,
		"message": "Событие решено: %s. Изменение репутации: %d." % [title, int(choice.get("reputation", 0))],
		"reason": reason,
		"experience": maxi(0, int(choice.get("experience", 0))),
		"reputation": int(choice.get("reputation", 0)),
		"cost": cost
	}
	event_history.append({
		"title": title,
		"choice": str(choice.get("label", "Решение")),
		"day": day,
		"cost": cost,
		"timestamp": int(Time.get_unix_time_from_system())
	})
	while event_history.size() > MAX_EVENT_HISTORY:
		event_history.pop_front()
	active_event.clear()
	next_event_day = day + rng.randi_range(3, 5)
	return result

func initialize_day(day: int) -> void:
	last_processed_day = maxi(1, day)
	next_event_day = last_processed_day + 3
	active_event.clear()

func get_event_history() -> Array[Dictionary]:
	return event_history.duplicate(true)

func get_save_data() -> Dictionary:
	return {
		"active_event": active_event.duplicate(true),
		"event_history": event_history.duplicate(true),
		"last_processed_day": last_processed_day,
		"next_event_day": next_event_day,
		"rng_state": rng.state
	}

func load_save_data(data: Dictionary) -> void:
	last_processed_day = maxi(1, int(data.get("last_processed_day", 1)))
	next_event_day = maxi(last_processed_day + 1, int(data.get("next_event_day", last_processed_day + 3)))
	active_event.clear()
	var saved_active: Variant = data.get("active_event", {})
	if saved_active is Dictionary and not saved_active.is_empty():
		var definition := _get_event_definition(str(saved_active.get("id", "")))
		if not definition.is_empty():
			active_event = definition.duplicate(true)
			active_event["created_day"] = maxi(1, int(saved_active.get("created_day", last_processed_day)))
	event_history.clear()
	var saved_history: Variant = data.get("event_history", [])
	if saved_history is Array:
		for entry in saved_history:
			if entry is Dictionary:
				event_history.append({
					"title": str(entry.get("title", "Событие района")),
					"choice": str(entry.get("choice", "Решение")),
					"day": maxi(1, int(entry.get("day", 1))),
					"cost": maxi(0, int(entry.get("cost", 0))),
					"timestamp": maxi(0, int(entry.get("timestamp", 0)))
				})
	while event_history.size() > MAX_EVENT_HISTORY:
		event_history.pop_front()
	var saved_rng_state := int(data.get("rng_state", 0))
	if saved_rng_state > 0:
		rng.state = saved_rng_state

func _get_choice(choice_id: String) -> Dictionary:
	var choices: Variant = active_event.get("choices", [])
	if choices is Array:
		for choice in choices:
			if choice is Dictionary and str(choice.get("id", "")) == choice_id:
				return choice
	return {}

func _get_event_definition(event_id: String) -> Dictionary:
	for event in EVENTS:
		if str(event.get("id", "")) == event_id:
			return event
	return {}
