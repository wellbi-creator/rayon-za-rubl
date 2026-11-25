extends RefCounted
class_name TelegramPlatform

var available: bool = false
var platform: String = "offline"
var sdk_version: String = ""
var init_data: String = ""
var viewport_height: float = 0.0
var viewport_stable_height: float = 0.0
var is_expanded: bool = false


func initialize() -> bool:
	available = false
	platform = "offline"
	sdk_version = ""
	init_data = ""
	viewport_height = 0.0
	viewport_stable_height = 0.0
	is_expanded = false

	if not OS.has_feature("web"):
		return false

	var snapshot_json: Variant = JavaScriptBridge.eval(
		"window.RayonTelegramBridge ? window.RayonTelegramBridge.getSnapshot() : \"\""
	)
	if not snapshot_json is String or snapshot_json.is_empty():
		return false

	var parsed: Variant = JSON.parse_string(snapshot_json)
	if not parsed is Dictionary:
		return false

	available = bool(parsed.get("available", false))
	platform = str(parsed.get("platform", "browser")) if available else "browser"
	sdk_version = str(parsed.get("version", "")) if available else ""
	init_data = str(parsed.get("initData", "")) if available else ""
	viewport_height = float(parsed.get("viewportHeight", 0.0)) if available else 0.0
	viewport_stable_height = float(parsed.get("viewportStableHeight", 0.0)) if available else 0.0
	is_expanded = bool(parsed.get("isExpanded", false)) if available else false
	return available


func is_telegram_available() -> bool:
	return available


func get_init_data() -> String:
	return init_data
