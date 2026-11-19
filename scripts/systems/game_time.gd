extends Node
class_name GameTime

signal time_changed(hour: int, minute: int, day: int)
signal day_changed(day: int)

# One in-game hour lasts five real minutes.
const REAL_SECONDS_PER_GAME_HOUR := 300.0
const GAME_SECONDS_PER_REAL_SECOND := 3600.0 / REAL_SECONDS_PER_GAME_HOUR
const SECONDS_PER_GAME_DAY := 24.0 * 60.0 * 60.0
const DEFAULT_START_HOUR := 8

var total_game_seconds: float = DEFAULT_START_HOUR * 60.0 * 60.0
var _last_emitted_minute: int = -1
var _last_emitted_day: int = -1

func _ready() -> void:
	_emit_time_if_changed(true)

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	total_game_seconds += delta * GAME_SECONDS_PER_REAL_SECOND
	_emit_time_if_changed()

func get_day() -> int:
	return int(floor(total_game_seconds / SECONDS_PER_GAME_DAY)) + 1

func get_hour() -> int:
	return int(floor(fposmod(total_game_seconds, SECONDS_PER_GAME_DAY) / 3600.0))

func get_minute() -> int:
	return int(floor(fposmod(total_game_seconds, 3600.0) / 60.0))

func get_save_data() -> Dictionary:
	return {
		"total_game_seconds": total_game_seconds,
		"clock_rate_version": 1
	}

func load_save_data(data: Dictionary, offline_real_seconds: int = 0) -> void:
	total_game_seconds = maxf(0.0, float(data.get("total_game_seconds", DEFAULT_START_HOUR * 3600.0)))
	# The game clock continues while the game is closed, using the same 5:1 scale.
	total_game_seconds += maxf(0.0, float(offline_real_seconds)) * GAME_SECONDS_PER_REAL_SECOND
	_last_emitted_minute = -1
	_last_emitted_day = -1
	_emit_time_if_changed(true)

func _emit_time_if_changed(force: bool = false) -> void:
	var current_minute := int(floor(total_game_seconds / 60.0))
	var current_day := get_day()
	if force or current_minute != _last_emitted_minute:
		_last_emitted_minute = current_minute
		time_changed.emit(get_hour(), get_minute(), current_day)
	if force or current_day != _last_emitted_day:
		_last_emitted_day = current_day
		day_changed.emit(current_day)
