extends RefCounted
class_name MunicipalServicesService

const MAX_EMPLOYEES_PER_SERVICE := 10
const EMPLOYEES_FOR_FULL_EFFICIENCY := 5
const MAINTENANCE_BASE_COST := 150
const MAINTENANCE_COST_PER_EMPLOYEE := 100
const DISTRICT_PLOT_COUNT := 10
const EQUIPMENT_UPGRADE_COSTS := [12000, 28000, 50000]
const EQUIPMENT_EFFICIENCY_PER_LEVEL := 10
const EQUIPMENT_MAINTENANCE_PER_LEVEL := 75
const SERVICES := [
	{"id": "road", "label": "Дорожные рабочие", "hire_cost": 4000, "daily_salary": 500},
	{"id": "electricity", "label": "Электрики", "hire_cost": 5000, "daily_salary": 650},
	{"id": "plumbing", "label": "Сантехники", "hire_cost": 5000, "daily_salary": 650},
	{"id": "cleaning", "label": "Уборщики", "hire_cost": 3000, "daily_salary": 400},
	{"id": "waste", "label": "Вывоз мусора", "hire_cost": 4500, "daily_salary": 550},
	{"id": "snow", "label": "Снегоуборщики", "hire_cost": 3500, "daily_salary": 450}
]

var employees: Dictionary = {}
var last_payroll_day: int = 1
var unpaid_wages: int = 0
var work_orders_completed: Dictionary = {}
var last_work_day: Dictionary = {}
var total_work_spent: Dictionary = {}
var service_quality: Dictionary = {}
var automatic_maintenance_enabled: Dictionary = {}
var last_maintenance_day: Dictionary = {}
var service_zone_plot_ids: Dictionary = {}
var equipment_levels: Dictionary = {}
var plot_infrastructure_condition: Dictionary = {}
var available_plot_ids: Array[int] = [0, 1, 2, 3, 4, 5]
var last_infrastructure_day: int = 1

func _init() -> void:
	for service in SERVICES:
		var service_id := str(service["id"])
		employees[service_id] = 0
		work_orders_completed[service_id] = 0
		last_work_day[service_id] = 0
		total_work_spent[service_id] = 0
		service_quality[service_id] = 100
		automatic_maintenance_enabled[service_id] = false
		last_maintenance_day[service_id] = 1
		service_zone_plot_ids[service_id] = []
		equipment_levels[service_id] = 0
	for plot_id in range(DISTRICT_PLOT_COUNT):
		plot_infrastructure_condition[str(plot_id)] = 100

func get_service_definitions() -> Array:
	return SERVICES.duplicate(true)

func set_available_plot_ids(plot_ids: Array) -> void:
	var validated: Array[int] = []
	for value in plot_ids:
		var plot_id := int(value)
		if plot_id >= 0 and plot_id < DISTRICT_PLOT_COUNT and not validated.has(plot_id):
			validated.append(plot_id)
	if validated.is_empty():
		validated = [0]
	available_plot_ids = validated
	for service in SERVICES:
		var service_id := str(service["id"])
		var filtered: Array[int] = []
		for plot_id in get_service_zone_plot_ids(service_id):
			if available_plot_ids.has(plot_id):
				filtered.append(plot_id)
		service_zone_plot_ids[service_id] = filtered

func get_employee_count(service_id: String) -> int:
	return int(employees.get(service_id, 0))

func get_service_efficiency_percent(service_id: String) -> int:
	var staff_efficiency := roundi(float(mini(get_employee_count(service_id), EMPLOYEES_FOR_FULL_EFFICIENCY)) / float(EMPLOYEES_FOR_FULL_EFFICIENCY) * 100.0)
	var equipment_bonus := get_equipment_level(service_id) * EQUIPMENT_EFFICIENCY_PER_LEVEL
	return mini(100, staff_efficiency + equipment_bonus)

func get_equipment_level(service_id: String) -> int:
	return clampi(int(equipment_levels.get(service_id, 0)), 0, EQUIPMENT_UPGRADE_COSTS.size())

func get_equipment_upgrade_cost(service_id: String) -> int:
	var level := get_equipment_level(service_id)
	if _get_definition(service_id).is_empty() or level >= EQUIPMENT_UPGRADE_COSTS.size():
		return -1
	return int(EQUIPMENT_UPGRADE_COSTS[level])

func upgrade_equipment(service_id: String, economy: EconomyService) -> bool:
	var cost := get_equipment_upgrade_cost(service_id)
	if cost < 0 or economy == null:
		return false
	if not economy.try_spend(cost, "Оборудование: %s" % str(_get_definition(service_id)["label"])):
		return false
	equipment_levels[service_id] = get_equipment_level(service_id) + 1
	return true

func get_service_quality_percent(service_id: String) -> int:
	return clampi(int(service_quality.get(service_id, 100)), 0, 100)

func get_service_discount_percent(service_id: String, maximum_discount: int) -> int:
	var effective_percent := get_service_efficiency_percent(service_id) * get_service_quality_percent(service_id)
	return roundi(float(clampi(maximum_discount, 0, 80) * effective_percent) / 10000.0)

func get_service_zone_plot_ids(service_id: String) -> Array[int]:
	var result: Array[int] = []
	var saved_ids: Variant = service_zone_plot_ids.get(service_id, [])
	if saved_ids is Array:
		for value in saved_ids:
			var plot_id := int(value)
			if plot_id >= 0 and plot_id < DISTRICT_PLOT_COUNT and available_plot_ids.has(plot_id) and not result.has(plot_id):
				result.append(plot_id)
	return result

func is_plot_assigned_to_service(service_id: String, plot_id: int) -> bool:
	return get_employee_count(service_id) > 0 and get_service_zone_plot_ids(service_id).has(plot_id)

func set_service_zone_plot_ids(service_id: String, plot_ids: Array) -> bool:
	if _get_definition(service_id).is_empty() or plot_ids.size() > get_employee_count(service_id):
		return false
	var validated: Array[int] = []
	for value in plot_ids:
		var plot_id := int(value)
		if plot_id < 0 or plot_id >= DISTRICT_PLOT_COUNT or not available_plot_ids.has(plot_id) or validated.has(plot_id):
			return false
		validated.append(plot_id)
	service_zone_plot_ids[service_id] = validated
	return true

func _get_first_unassigned_plot(service_id: String) -> int:
	var assigned := get_service_zone_plot_ids(service_id)
	for plot_id in available_plot_ids:
		if not assigned.has(plot_id):
			return plot_id
	return -1

func is_automatic_maintenance_enabled(service_id: String) -> bool:
	return bool(automatic_maintenance_enabled.get(service_id, false))

func set_automatic_maintenance_enabled(service_id: String, enabled: bool) -> bool:
	if _get_definition(service_id).is_empty():
		return false
	if enabled and get_employee_count(service_id) <= 0:
		return false
	automatic_maintenance_enabled[service_id] = enabled
	return true

func get_maintenance_cost(service_id: String) -> int:
	if get_employee_count(service_id) <= 0:
		return 0
	return MAINTENANCE_BASE_COST + get_employee_count(service_id) * MAINTENANCE_COST_PER_EMPLOYEE + get_equipment_level(service_id) * EQUIPMENT_MAINTENANCE_PER_LEVEL

func get_average_service_quality() -> int:
	var total := 0
	for service in SERVICES:
		total += get_service_quality_percent(str(service["id"]))
	return roundi(float(total) / float(SERVICES.size()))

func get_automatic_maintenance_count() -> int:
	var total := 0
	for service in SERVICES:
		if is_automatic_maintenance_enabled(str(service["id"])):
			total += 1
	return total

func get_plot_service_quality_by_plot() -> Dictionary:
	var result: Dictionary = {}
	for plot_id in available_plot_ids:
		var total_quality := 0
		var covered_services := 0
		for service in SERVICES:
			var service_id := str(service["id"])
			if get_employee_count(service_id) <= 0 or not is_plot_assigned_to_service(service_id, plot_id):
				continue
			total_quality += get_service_quality_percent(service_id)
			covered_services += 1
		if covered_services > 0:
			result[str(plot_id)] = roundi(float(total_quality) / covered_services)
	return result

func get_plot_infrastructure_condition_data() -> Dictionary:
	return plot_infrastructure_condition.duplicate(true)

func get_plot_infrastructure_condition(plot_id: int) -> int:
	return clampi(int(plot_infrastructure_condition.get(str(plot_id), 100)), 0, 100)

func get_average_infrastructure_condition() -> int:
	var total := 0
	for plot_id in available_plot_ids:
		total += get_plot_infrastructure_condition(plot_id)
	return roundi(float(total) / maxi(1, available_plot_ids.size()))

func process_daily_infrastructure(day: int) -> bool:
	if day <= last_infrastructure_day:
		return false
	for processed_day in range(last_infrastructure_day + 1, day + 1):
		var quality_by_plot := get_plot_service_quality_by_plot()
		for plot_id in available_plot_ids:
			var key := str(plot_id)
			if not quality_by_plot.has(key):
				continue
			var condition := get_plot_infrastructure_condition(plot_id)
			var quality := int(quality_by_plot[key])
			if quality >= 80:
				condition = mini(100, condition + 1)
			elif quality <= 35:
				condition = maxi(0, condition - 1)
			plot_infrastructure_condition[key] = condition
	last_infrastructure_day = day
	return true

func process_daily_maintenance(day: int, economy: EconomyService) -> bool:
	var processed := false
	for service in SERVICES:
		var service_id := str(service["id"])
		var last_day := int(last_maintenance_day.get(service_id, 1))
		if day <= last_day:
			continue
		var employee_count := get_employee_count(service_id)
		last_maintenance_day[service_id] = day
		if employee_count <= 0:
			continue
		processed = true
		for maintenance_day in range(last_day + 1, day + 1):
			if not is_automatic_maintenance_enabled(service_id):
				service_quality[service_id] = maxi(0, get_service_quality_percent(service_id) - 2)
				continue
			var worn_quality := maxi(0, get_service_quality_percent(service_id) - 2)
			service_quality[service_id] = worn_quality
			var cost := get_maintenance_cost(service_id)
			if economy == null or not economy.try_spend(cost, "Плановое обслуживание: %s" % str(service["label"])):
				service_quality[service_id] = maxi(0, worn_quality - 1)
				continue
			var quality_gain := 3 + roundi(float(get_service_efficiency_percent(service_id)) / 20.0)
			service_quality[service_id] = mini(100, worn_quality + quality_gain)
			record_work_order(service_id, maintenance_day, cost)
	return processed

func get_hire_cost(service_id: String) -> int:
	var definition := _get_definition(service_id)
	return int(definition.get("hire_cost", 0))

func get_daily_salary(service_id: String) -> int:
	var definition := _get_definition(service_id)
	return int(definition.get("daily_salary", 0))

func get_total_employee_count() -> int:
	var total := 0
	for service_id in employees:
		total += int(employees[service_id])
	return total

func get_total_daily_payroll() -> int:
	var total := 0
	for service in SERVICES:
		var service_id := str(service["id"])
		total += get_employee_count(service_id) * int(service["daily_salary"])
	return total

func get_unpaid_wages() -> int:
	return unpaid_wages

func get_work_orders_completed(service_id: String) -> int:
	return int(work_orders_completed.get(service_id, 0))

func get_last_work_day(service_id: String) -> int:
	return int(last_work_day.get(service_id, 0))

func get_total_work_spent(service_id: String) -> int:
	return int(total_work_spent.get(service_id, 0))

func get_total_work_orders_completed() -> int:
	var total := 0
	for service_id in work_orders_completed:
		total += int(work_orders_completed[service_id])
	return total

func record_work_order(service_id: String, day: int, cost: int) -> bool:
	if _get_definition(service_id).is_empty() or get_employee_count(service_id) <= 0:
		return false
	work_orders_completed[service_id] = get_work_orders_completed(service_id) + 1
	last_work_day[service_id] = maxi(1, day)
	total_work_spent[service_id] = get_total_work_spent(service_id) + maxi(0, cost)
	return true

func hire_employee(service_id: String, economy: EconomyService) -> bool:
	var definition := _get_definition(service_id)
	if definition.is_empty() or economy == null:
		return false
	if get_employee_count(service_id) >= MAX_EMPLOYEES_PER_SERVICE:
		return false
	var cost := int(definition["hire_cost"])
	if not economy.try_spend(cost, "Найм: %s" % str(definition["label"])):
		return false
	employees[service_id] = get_employee_count(service_id) + 1
	var next_plot_id := _get_first_unassigned_plot(service_id)
	if next_plot_id >= 0:
		var assigned := get_service_zone_plot_ids(service_id)
		assigned.append(next_plot_id)
		service_zone_plot_ids[service_id] = assigned
	return true

func fire_employee(service_id: String) -> bool:
	if not employees.has(service_id) or get_employee_count(service_id) <= 0:
		return false
	employees[service_id] = get_employee_count(service_id) - 1
	var assigned := get_service_zone_plot_ids(service_id)
	while assigned.size() > get_employee_count(service_id):
		assigned.pop_back()
	service_zone_plot_ids[service_id] = assigned
	return true

func process_day(day: int, economy: EconomyService) -> bool:
	var elapsed_days := day - last_payroll_day
	if elapsed_days <= 0:
		return false
	unpaid_wages += get_total_daily_payroll() * elapsed_days
	last_payroll_day = day
	if unpaid_wages > 0 and economy != null and economy.balance > 0:
		var payment := mini(unpaid_wages, economy.balance)
		if payment > 0 and economy.try_spend(payment, "Зарплата коммунальных служб"):
			unpaid_wages -= payment
	return true

func initialize_day(day: int) -> void:
	last_payroll_day = maxi(1, day)
	unpaid_wages = 0
	for service in SERVICES:
		last_maintenance_day[str(service["id"])] = last_payroll_day
	last_infrastructure_day = last_payroll_day

func get_save_data() -> Dictionary:
	return {
		"employees": employees.duplicate(true),
		"last_payroll_day": last_payroll_day,
		"unpaid_wages": unpaid_wages,
		"work_orders_completed": work_orders_completed.duplicate(true),
		"last_work_day": last_work_day.duplicate(true),
		"total_work_spent": total_work_spent.duplicate(true),
		"service_quality": service_quality.duplicate(true),
		"automatic_maintenance_enabled": automatic_maintenance_enabled.duplicate(true),
		"last_maintenance_day": last_maintenance_day.duplicate(true),
		"service_zone_plot_ids": service_zone_plot_ids.duplicate(true),
		"equipment_levels": equipment_levels.duplicate(true),
		"plot_infrastructure_condition": plot_infrastructure_condition.duplicate(true),
		"last_infrastructure_day": last_infrastructure_day
	}

func load_save_data(data: Dictionary) -> void:
	var saved_employees: Variant = data.get("employees", {})
	for service in SERVICES:
		var service_id := str(service["id"])
		var saved_count := int(saved_employees.get(service_id, 0)) if saved_employees is Dictionary else 0
		employees[service_id] = clampi(saved_count, 0, MAX_EMPLOYEES_PER_SERVICE)
	last_payroll_day = maxi(1, int(data.get("last_payroll_day", 1)))
	unpaid_wages = maxi(0, int(data.get("unpaid_wages", 0)))
	var saved_work_orders: Variant = data.get("work_orders_completed", {})
	var saved_last_work_day: Variant = data.get("last_work_day", {})
	var saved_work_spent: Variant = data.get("total_work_spent", {})
	var saved_quality: Variant = data.get("service_quality", {})
	var saved_maintenance: Variant = data.get("automatic_maintenance_enabled", {})
	var saved_maintenance_day: Variant = data.get("last_maintenance_day", {})
	var saved_zones: Variant = data.get("service_zone_plot_ids", {})
	var saved_equipment: Variant = data.get("equipment_levels", {})
	var saved_infrastructure: Variant = data.get("plot_infrastructure_condition", {})
	last_infrastructure_day = maxi(last_payroll_day, int(data.get("last_infrastructure_day", last_payroll_day)))
	for service in SERVICES:
		var service_id := str(service["id"])
		work_orders_completed[service_id] = maxi(0, int(saved_work_orders.get(service_id, 0))) if saved_work_orders is Dictionary else 0
		last_work_day[service_id] = maxi(0, int(saved_last_work_day.get(service_id, 0))) if saved_last_work_day is Dictionary else 0
		total_work_spent[service_id] = maxi(0, int(saved_work_spent.get(service_id, 0))) if saved_work_spent is Dictionary else 0
		service_quality[service_id] = clampi(int(saved_quality.get(service_id, 100)), 0, 100) if saved_quality is Dictionary else 100
		automatic_maintenance_enabled[service_id] = bool(saved_maintenance.get(service_id, false)) if saved_maintenance is Dictionary else false
		last_maintenance_day[service_id] = maxi(last_payroll_day, int(saved_maintenance_day.get(service_id, last_payroll_day))) if saved_maintenance_day is Dictionary else last_payroll_day
		var restored_zones: Array[int] = []
		if saved_zones is Dictionary and saved_zones.has(service_id) and saved_zones[service_id] is Array:
			for value in saved_zones[service_id]:
				var plot_id := int(value)
				if plot_id >= 0 and plot_id < DISTRICT_PLOT_COUNT and not restored_zones.has(plot_id):
					restored_zones.append(plot_id)
		elif get_employee_count(service_id) > 0:
			# Older saves receive a safe starter allocation, one plot per available employee.
			for plot_id in range(mini(get_employee_count(service_id), DISTRICT_PLOT_COUNT)):
				restored_zones.append(plot_id)
		while restored_zones.size() > get_employee_count(service_id):
			restored_zones.pop_back()
		service_zone_plot_ids[service_id] = restored_zones
		equipment_levels[service_id] = clampi(int(saved_equipment.get(service_id, 0)), 0, EQUIPMENT_UPGRADE_COSTS.size()) if saved_equipment is Dictionary else 0
	for plot_id in range(DISTRICT_PLOT_COUNT):
		var key := str(plot_id)
		plot_infrastructure_condition[key] = clampi(int(saved_infrastructure.get(key, 100)), 0, 100) if saved_infrastructure is Dictionary else 100

func _get_definition(service_id: String) -> Dictionary:
	for service in SERVICES:
		if str(service["id"]) == service_id:
			return service
	return {}
