extends RefCounted
class_name BusinessService

const OPENING_COST := 100000
const DAILY_REVENUE := 16000
const DAILY_OPERATING_COST := 6000
const CUSTOMER_SPEND := 200
const BUSINESS_TYPES := {
	"corner_shop": {"title": "Магазин у дома", "opening_cost": 100000, "customer_spend": 200, "daily_expenses": 6000},
	"bakery": {"title": "Пекарня", "opening_cost": 140000, "customer_spend": 260, "daily_expenses": 8500},
	"cafe": {"title": "Кафе", "opening_cost": 180000, "customer_spend": 320, "daily_expenses": 11000}
}
const BASE_DAILY_CUSTOMERS := 80
const RESIDENT_CUSTOMER_BONUS := 3
const REPUTATION_CUSTOMER_BONUS := 0.2
const SATISFACTION_CUSTOMER_BONUS := 0.1
const SUPPORTED_BUSINESS := "corner_shop"
const BUSINESS_UPGRADE_COSTS := [35000, 75000]
const BUSINESS_UPGRADE_DAILY_COST := 500
const BUSINESS_BASE_ATTRACTION := 100
const BUSINESS_UPGRADE_ATTRACTION := 25
const BUSINESS_DAILY_RENT := {
	"corner_shop": 3500,
	"bakery": 4500,
	"cafe": 5500
}

var businesses: Dictionary = {}
var last_processed_day: int = 1
var unpaid_operating_costs: int = 0
var total_rent_received: int = 0

func initialize_day(day: int) -> void:
	last_processed_day = maxi(1, day)
	unpaid_operating_costs = 0

func get_opening_cost(business_type: String = SUPPORTED_BUSINESS) -> int:
	var type_data: Dictionary = BUSINESS_TYPES.get(business_type, BUSINESS_TYPES[SUPPORTED_BUSINESS])
	return int(type_data.get("opening_cost", OPENING_COST))

func get_business_type_title(business_type: String) -> String:
	var type_data: Dictionary = BUSINESS_TYPES.get(business_type, BUSINESS_TYPES[SUPPORTED_BUSINESS])
	return str(type_data.get("title", "Магазин у дома"))

func get_business_type_ids() -> Array[String]:
	return ["corner_shop", "bakery", "cafe"]

func get_business_upgrade_level(plot_id: int) -> int:
	var business := get_business(plot_id)
	return clampi(int(business.get("upgrade_level", 0)), 0, BUSINESS_UPGRADE_COSTS.size())

func get_business_upgrade_cost(plot_id: int) -> int:
	var level := get_business_upgrade_level(plot_id)
	if level >= BUSINESS_UPGRADE_COSTS.size():
		return 0
	return int(BUSINESS_UPGRADE_COSTS[level])

func is_business_leased(plot_id: int) -> bool:
	var business := get_business(plot_id)
	return bool(business.get("leased", false))

func get_daily_rent(plot_id: int) -> int:
	var business := get_business(plot_id)
	if business.is_empty():
		return 0
	var business_type := str(business.get("type", SUPPORTED_BUSINESS))
	return int(BUSINESS_DAILY_RENT.get(business_type, BUSINESS_DAILY_RENT[SUPPORTED_BUSINESS]))

func lease_business(plot_id: int) -> bool:
	if not businesses.has(plot_id) or is_business_leased(plot_id):
		return false
	var business: Dictionary = businesses[plot_id]
	business["leased"] = true
	business["active"] = true
	businesses[plot_id] = business
	return true

func terminate_business_lease(plot_id: int) -> bool:
	if not businesses.has(plot_id) or not is_business_leased(plot_id):
		return false
	var business: Dictionary = businesses[plot_id]
	business["leased"] = false
	business["active"] = false
	businesses[plot_id] = business
	return true

func get_business_daily_expenses(plot_id: int) -> int:
	var business := get_business(plot_id)
	if business.is_empty():
		return 0
	var business_type := str(business.get("type", SUPPORTED_BUSINESS))
	var upgrade_level := get_business_upgrade_level(plot_id)
	return get_daily_expenses(business_type) + upgrade_level * BUSINESS_UPGRADE_DAILY_COST

func purchase_business_upgrade(plot_id: int, economy: EconomyService) -> bool:
	if economy == null or not businesses.has(plot_id):
		return false
	var upgrade_level := get_business_upgrade_level(plot_id)
	var upgrade_cost := get_business_upgrade_cost(plot_id)
	if upgrade_cost <= 0 or is_business_leased(plot_id) or not economy.try_spend(upgrade_cost, "Улучшение заведения"):
		return false
	var business: Dictionary = businesses[plot_id]
	business["upgrade_level"] = upgrade_level + 1
	businesses[plot_id] = business
	return true

func _get_business_attraction_weight(business: Dictionary) -> int:
	var upgrade_level := clampi(int(business.get("upgrade_level", 0)), 0, BUSINESS_UPGRADE_COSTS.size())
	return BUSINESS_BASE_ATTRACTION + upgrade_level * BUSINESS_UPGRADE_ATTRACTION

func get_daily_revenue() -> int:
	return DAILY_REVENUE

func get_daily_expenses(business_type: String = SUPPORTED_BUSINESS) -> int:
	var type_data: Dictionary = BUSINESS_TYPES.get(business_type, BUSINESS_TYPES[SUPPORTED_BUSINESS])
	return int(type_data.get("daily_expenses", DAILY_OPERATING_COST))

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

func open_business(plot_id: int, economy: EconomyService, business_type: String = SUPPORTED_BUSINESS) -> bool:
	if plot_id < 1 or plot_id >= 10 or economy == null or businesses.has(plot_id) or not BUSINESS_TYPES.has(business_type):
		return false
	var opening_cost := get_opening_cost(business_type)
	if not economy.try_spend(opening_cost, "Открытие: " + get_business_type_title(business_type)):
		return false
	businesses[plot_id] = {
		"type": business_type,
		"upgrade_level": 0,
		"active": true,
		"opened_day": last_processed_day,
		"last_daily_customers": BASE_DAILY_CUSTOMERS,
		"last_daily_revenue": BASE_DAILY_CUSTOMERS * int(BUSINESS_TYPES[business_type].get("customer_spend", CUSTOMER_SPEND))
	}
	return true

func set_business_active(plot_id: int, active: bool) -> bool:
	if not businesses.has(plot_id) or is_business_leased(plot_id):
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
	var active_plot_ids: Array[int] = []
	for key in businesses.keys():
		var business: Dictionary = businesses[key]
		if bool(business.get("active", false)) and not bool(business.get("leased", false)):
			active_plot_ids.append(int(key))
	active_plot_ids.sort()
	var active_count := active_plot_ids.size()
	if active_count > 0:
		var total_daily_customers := get_daily_customer_count(resident_count, average_satisfaction, reputation, weather_id)
		var total_weight := 0
		for plot_id in active_plot_ids:
			total_weight += _get_business_attraction_weight(businesses[plot_id])
		var allocated_customers := 0
		var customer_allocations: Dictionary = {}
		for plot_id in active_plot_ids:
			var weight := _get_business_attraction_weight(businesses[plot_id])
			var allocated := floori(float(total_daily_customers * weight) / float(maxi(1, total_weight)))
			customer_allocations[plot_id] = allocated
			allocated_customers += allocated
		var remaining_customers := total_daily_customers - allocated_customers
		for plot_id in active_plot_ids:
			if remaining_customers <= 0:
				break
			customer_allocations[plot_id] = int(customer_allocations[plot_id]) + 1
			remaining_customers -= 1
		var total_daily_revenue := 0
		for index in range(active_count):
			var plot_id := active_plot_ids[index]
			var store_customers := int(customer_allocations.get(plot_id, 0))
			var business: Dictionary = businesses[plot_id]
			var business_type := str(business.get("type", SUPPORTED_BUSINESS))
			var type_data: Dictionary = BUSINESS_TYPES.get(business_type, BUSINESS_TYPES[SUPPORTED_BUSINESS])
			var store_revenue := store_customers * int(type_data.get("customer_spend", CUSTOMER_SPEND))
			business["last_daily_customers"] = store_customers
			business["last_daily_revenue"] = store_revenue
			businesses[plot_id] = business
			total_daily_revenue += store_revenue
		economy.add_money(total_daily_revenue * elapsed_days, "Выручка магазинов района")
		var daily_expenses := 0
		for plot_id in active_plot_ids:
			var business: Dictionary = businesses[plot_id]
			daily_expenses += get_daily_expenses(str(business.get("type", SUPPORTED_BUSINESS))) + get_business_upgrade_level(plot_id) * BUSINESS_UPGRADE_DAILY_COST
		unpaid_operating_costs += daily_expenses * elapsed_days
	var daily_rent_income := 0
	for key in businesses.keys():
		var business: Dictionary = businesses[key]
		if bool(business.get("leased", false)):
			var business_type := str(business.get("type", SUPPORTED_BUSINESS))
			daily_rent_income += int(BUSINESS_DAILY_RENT.get(business_type, BUSINESS_DAILY_RENT[SUPPORTED_BUSINESS]))
	if daily_rent_income > 0:
		var rent_payment := daily_rent_income * elapsed_days
		economy.add_money(rent_payment, "Арендная плата за коммерческие помещения")
		total_rent_received += rent_payment
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
			"leased": bool(business.get("leased", false)),
			"upgrade_level": clampi(int(business.get("upgrade_level", 0)), 0, BUSINESS_UPGRADE_COSTS.size()),
			"active": bool(business.get("active", false)),
			"opened_day": maxi(1, int(business.get("opened_day", 1))),
			"last_daily_customers": maxi(0, int(business.get("last_daily_customers", BASE_DAILY_CUSTOMERS))),
			"last_daily_revenue": maxi(0, int(business.get("last_daily_revenue", DAILY_REVENUE)))
		})
	return {
		"businesses": saved_businesses,
		"last_processed_day": last_processed_day,
		"unpaid_operating_costs": unpaid_operating_costs,
		"total_rent_received": total_rent_received
	}

func load_save_data(data: Dictionary) -> void:
	businesses.clear()
	last_processed_day = maxi(1, int(data.get("last_processed_day", 1)))
	unpaid_operating_costs = maxi(0, int(data.get("unpaid_operating_costs", 0)))
	total_rent_received = maxi(0, int(data.get("total_rent_received", 0)))
	var saved_businesses: Variant = data.get("businesses", [])
	if not saved_businesses is Array:
		return
	for entry in saved_businesses:
		if not entry is Dictionary:
			continue
		var plot_id := int(entry.get("plot_id", -1))
		var business_type := str(entry.get("type", SUPPORTED_BUSINESS))
		if plot_id < 1 or plot_id >= 10 or not BUSINESS_TYPES.has(business_type):
			continue
		businesses[plot_id] = {
			"type": business_type,
			"leased": bool(entry.get("leased", false)),
			"upgrade_level": clampi(int(entry.get("upgrade_level", 0)), 0, BUSINESS_UPGRADE_COSTS.size()),
			"active": bool(entry.get("active", false)),
			"opened_day": maxi(1, int(entry.get("opened_day", 1))),
			"last_daily_customers": maxi(0, int(entry.get("last_daily_customers", BASE_DAILY_CUSTOMERS))),
			"last_daily_revenue": maxi(0, int(entry.get("last_daily_revenue", DAILY_REVENUE)))
		}
