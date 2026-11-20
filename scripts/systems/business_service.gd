extends RefCounted
class_name BusinessService

const OPENING_COST := 100000
const DAILY_REVENUE := 16000
const DAILY_OPERATING_COST := 6000
const CUSTOMER_SPEND := 200
const BASE_DAILY_CUSTOMERS := 80
const RESIDENT_CUSTOMER_BONUS := 3
const REPUTATION_CUSTOMER_BONUS := 0.2
const SATISFACTION_CUSTOMER_BONUS := 0.1
const SUPPORTED_BUSINESS := "corner_shop"

var businesses: Dictionary = {}
var last_processed_day: int = 1
var unpaid_operating_costs: int = 0

func initialize_day(day: int) -> void:
	last_processed_day = maxi(1, day)
	unpaid_operating_costs = 0

func get_opening_cost() -> int:
	return OPENING_COST

func get_daily_revenue() -> int:
	return DAILY_REVENUE

func get_daily_expenses() -> int:
	return DAILY_OPERATING_COST

func get_daily_profit() -> int:
	return DAILY_REVENUE - DAILY_OPERATING_COST

func get_business(plot_id: int) -> Dictionary:
	if not businesses.has(plot_id):
		return {}
	return businesses[plot_id].duplicate(true)

func get_business_visual_data() -> Dictionary:
	var result: Dictionary = {}
	for key in businesses.keys():
		var business: Dictionary = businesses[key]
		result[int(key)] = bool(business.get("active", false))
	return result

func get_daily_customer_count(resident_count: int, average_satisfaction: float, reputation: int, weather_id: String) -> int:
	var base_customers := BASE_DAILY_CUSTOMERS
	base_customers += maxi(0, resident_count) * RESIDENT_CUSTOMER_BONUS
	base_customers += roundi(clampi(reputation, 0, 100) * REPUTATION_CUSTOMER_BONUS)
	base_customers += roundi((clampf(average_satisfaction, 0.0, 100.0) - 50.0) * SATISFACTION_CUSTOMER_BONUS)
	var weather_multiplier := 1.0
	match weather_id:
		"cloudy":
			weather_multiplier = 0.95
		"rain":
			weather_multiplier = 0.85
		"snow":
			weather_multiplier = 0.8
		"fog":
			weather_multiplier = 0.9
		"storm":
			weather_multiplier = 0.7
		"heatwave":
			weather_multiplier = 0.9
	return maxi(10, roundi(float(base_customers) * weather_multiplier))

func open_business(plot_id: int, economy: EconomyService) -> bool:
	if plot_id < 1 or plot_id >= 10 or economy == null or businesses.has(plot_id):
		return false
	if not economy.try_spend(OPENING_COST, "Открытие магазина у дома"):
		return false
	businesses[plot_id] = {
		"type": SUPPORTED_BUSINESS,
		"active": true,
		"opened_day": last_processed_day,
		"last_daily_customers": BASE_DAILY_CUSTOMERS,
		"last_daily_revenue": DAILY_REVENUE
	}
	return true

func set_business_active(plot_id: int, active: bool) -> bool:
	if not businesses.has(plot_id):
		return false
	var business: Dictionary = businesses[plot_id]
	business["active"] = active
	businesses[plot_id] = business
	return true

func process_day(day: int, economy: EconomyService, resident_count: int = 0, average_satisfaction: float = 75.0, reputation: int = 0, weather_id: String = "clear") -> bool:
	if economy == null:
		return false
	var elapsed_days := day - last_processed_day
	if elapsed_days <= 0:
		return false
	last_processed_day = day
	var active_count := 0
	var daily_customers := get_daily_customer_count(resident_count, average_satisfaction, reputation, weather_id)
	var daily_revenue := daily_customers * CUSTOMER_SPEND
	for key in businesses.keys():
		var business: Dictionary = businesses[key]
		if not bool(business.get("active", false)):
			continue
		active_count += 1
		business["last_daily_customers"] = daily_customers
		business["last_daily_revenue"] = daily_revenue
		businesses[key] = business
	if active_count > 0:
		economy.add_money(active_count * daily_revenue * elapsed_days, "Выручка магазинов района")
		unpaid_operating_costs += active_count * DAILY_OPERATING_COST * elapsed_days
	if unpaid_operating_costs > 0 and economy.balance > 0:
		var payment := mini(unpaid_operating_costs, economy.balance)
		if payment > 0 and economy.try_spend(payment, "Операционные расходы магазинов"):
			unpaid_operating_costs -= payment
	return true

func get_save_data() -> Dictionary:
	var saved_businesses: Array[Dictionary] = []
	for key in businesses.keys():
		var business: Dictionary = businesses[key]
		saved_businesses.append({
			"plot_id": int(key),
			"type": str(business.get("type", SUPPORTED_BUSINESS)),
			"active": bool(business.get("active", false)),
			"opened_day": maxi(1, int(business.get("opened_day", 1))),
			"last_daily_customers": maxi(0, int(business.get("last_daily_customers", BASE_DAILY_CUSTOMERS))),
			"last_daily_revenue": maxi(0, int(business.get("last_daily_revenue", DAILY_REVENUE)))
		})
	return {
		"businesses": saved_businesses,
		"last_processed_day": last_processed_day,
		"unpaid_operating_costs": unpaid_operating_costs
	}

func load_save_data(data: Dictionary) -> void:
	businesses.clear()
	last_processed_day = maxi(1, int(data.get("last_processed_day", 1)))
	unpaid_operating_costs = maxi(0, int(data.get("unpaid_operating_costs", 0)))
	var saved_businesses: Variant = data.get("businesses", [])
	if not saved_businesses is Array:
		return
	for entry in saved_businesses:
		if not entry is Dictionary:
			continue
		var plot_id := int(entry.get("plot_id", -1))
		var business_type := str(entry.get("type", SUPPORTED_BUSINESS))
		if plot_id < 1 or plot_id >= 10 or business_type != SUPPORTED_BUSINESS:
			continue
		businesses[plot_id] = {
			"type": business_type,
			"active": bool(entry.get("active", false)),
			"opened_day": maxi(1, int(entry.get("opened_day", 1))),
			"last_daily_customers": maxi(0, int(entry.get("last_daily_customers", BASE_DAILY_CUSTOMERS))),
			"last_daily_revenue": maxi(0, int(entry.get("last_daily_revenue", DAILY_REVENUE)))
		}
