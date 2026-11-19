extends Node
class_name SaveService

const SAVE_PATH := "user://rayon_save.json"
const SAVE_VERSION := 1

func save_game(data: Dictionary) -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"game": data
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось открыть файл сохранения для записи.")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть файл сохранения.")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_warning("Файл сохранения повреждён или имеет неверный формат.")
		return {}
	if int(parsed.get("version", -1)) != SAVE_VERSION:
		push_warning("Версия сохранения не поддерживается.")
		return {}
	var game: Variant = parsed.get("game", {})
	if not game is Dictionary:
		return {}
	var restored: Dictionary = game.duplicate(true)
	restored["saved_at"] = int(parsed.get("saved_at", 0))
	return restored

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
