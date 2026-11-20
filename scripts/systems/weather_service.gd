extends RefCounted
class_name WeatherService

const SEASON_LENGTH_DAYS := 30
const SEASONS := ["spring", "summer", "autumn", "winter"]
const WEATHER_BY_SEASON := {
	"spring": ["clear", "clear", "cloudy", "rain", "rain", "fog"],
	"summer": ["clear", "clear", "clear", "cloudy", "rain", "fog"],
	"autumn": ["clear", "cloudy", "cloudy", "rain", "rain", "fog"],
	"winter": ["clear", "cloudy", "snow", "snow", "snow", "fog"]
}
const SEASON_LABELS := {
	"spring": "Весна",
	"summer": "Лето",
	"autumn": "Осень",
	"winter": "Зима"
}
const WEATHER_LABELS := {
	"clear": "Ясно",
	"cloudy": "Облачно",
	"rain": "Дождь",
	"snow": "Снег",
	"fog": "Туман"
}

var rng := RandomNumberGenerator.new()
var current_day: int = 1
var season_id: String = "spring"
var weather_id: String = "clear"
var next_weather_day: int = 3

func _init() -> void:
	rng.randomize()

func initialize_day(day: int) -> void:
	current_day = maxi(1, day)
	season_id = _get_season_for_day(current_day)
	weather_id = _roll_weather(season_id)
	next_weather_day = current_day + rng.randi_range(1, 3)

func process_day(day: int) -> bool:
	if day <= current_day:
		return false
	var previous_season := season_id
	var previous_weather := weather_id
	current_day = day
	season_id = _get_season_for_day(day)
	if season_id != previous_season or day >= next_weather_day:
		weather_id = _roll_weather(season_id)
		next_weather_day = day + rng.randi_range(1, 3)
	return season_id != previous_season or weather_id != previous_weather

func get_season_label() -> String:
	return str(SEASON_LABELS.get(season_id, "Весна"))

func get_weather_label() -> String:
	return str(WEATHER_LABELS.get(weather_id, "Ясно"))

func get_save_data() -> Dictionary:
	return {
		"current_day": current_day,
		"season_id": season_id,
		"weather_id": weather_id,
		"next_weather_day": next_weather_day,
		"rng_state": rng.state
	}

func load_save_data(data: Dictionary) -> void:
	current_day = maxi(1, int(data.get("current_day", 1)))
	season_id = str(data.get("season_id", _get_season_for_day(current_day)))
	if not SEASONS.has(season_id):
		season_id = _get_season_for_day(current_day)
	weather_id = str(data.get("weather_id", "clear"))
	if not WEATHER_LABELS.has(weather_id):
		weather_id = "clear"
	next_weather_day = maxi(current_day + 1, int(data.get("next_weather_day", current_day + 2)))
	var saved_rng_state := int(data.get("rng_state", 0))
	if saved_rng_state > 0:
		rng.state = saved_rng_state

func _get_season_for_day(day: int) -> String:
	var season_index := int(floor(float(maxi(1, day) - 1) / float(SEASON_LENGTH_DAYS))) % SEASONS.size()
	return str(SEASONS[season_index])

func _roll_weather(season: String) -> String:
	var options: Array = WEATHER_BY_SEASON.get(season, WEATHER_BY_SEASON["spring"])
	return str(options[rng.randi_range(0, options.size() - 1)])
