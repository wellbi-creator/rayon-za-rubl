extends RefCounted
class_name MunicipalServicesService

const MAX_EMPLOYEES_PER_SERVICE := 10
const EMPLOYEES_FOR_FULL_EFFICIENCY := 5
const MAINTENANCE_BASE_COST := 150
const MAINTENANCE_COST_PER_EMPLOYEE := 100
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

func get_service_definitions() -> Array:
	return SERVICES.duplicate(true)

func get_employee_count(service_id: String) -> int:
	return int(employees.get(service_id, 0))

func get_service_efficiency_percent(service_id: String) -> int:
	return roundi(float(mini(get_employee_count(service_id), EMPLOYEES_FOR_FULL_EFFICIENCY)) / float(EMPLOYEES_FOR_FULL_EFFICIENCY) * 100.0)

func get_service_quality_percent(service_id: String) -> int:
	return clampi(int(service_quality.get(service_id, 100)), 0, 100)

func get_service_discount_percent(service_id: String, maximum_discount: int) -> int:
	var effective_percent := get_service_efficiency_percent(service_id) * get_service_quality_percent(service_id)
	return roundi(float(clampi(maximum_discount, 0, 80) * effective_percent) / 10000.0)

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
	return MAINTENANCE_BASE_COST + get_employee_count(service_id) * MAINTENANCE_COST_PER_EMPLOYEE

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

func process_daily_maintenance(day: int, economy: EconomyService) -> bool:
	var processed := false
	for service in SERVICES:
		var service_id := str(service["id"])
		if day <= int(last_maintenance_day.get(service_id, 1)):
			continue
		last_maintenance_day[service_id] = day
		var employee_count := get_employee_count(service_id)
		if employee_count <= 0:
			continue
		processed = true
		if not is_automatic_maintenance_enabled(service_id):
			service_quality[service_id] = maxi(0, get_service_quality_percent(service_id) - 2)
			continue
		if get_service_quality_percent(service_id) >= 100:
			continue
		var cost := get_maintenance_cost(service_id)
		if economy == null or not economy.try_spend(cost, "Плановое обслуживание: %s" % str(service["label"])):
			service_quality[service_id] = maxi(0, get_service_quality_percent(service_id) - 3)
			continue
		var quality_gain := 3 + roundi(float(get_service_efficiency_percent(service_id)) / 20.0)
		service_quality[service_id] = mini(100, get_service_quality_percent(service_id) + quality_gain)
		record_work_order(service_id, day, cost)
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
	return true

func fire_employee(service_id: String) -> bool:
	if not employees.has(service_id) or get_employee_count(service_id) <= 0:
		return false
	employees[service_id] = get_employee_count(service_id) - 1
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
		"last_maintenance_day": last_maintenance_day.duplicate(true)
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
	for service in SERVICES:
		var service_id := str(service["id"])
		work_orders_completed[service_id] = maxi(0, int(saved_work_orders.get(service_id, 0))) if saved_work_orders is Dictionary else 0
		last_work_day[service_id] = maxi(0, int(saved_last_work_day.get(service_id, 0))) if saved_last_work_day is Dictionary else 0
		total_work_spent[service_id] = maxi(0, int(saved_work_spent.get(service_id, 0))) if saved_work_spent is Dictionary else 0
		service_quality[service_id] = clampi(int(saved_quality.get(service_id, 100)), 0, 100) if saved_quality is Dictionary else 100
		automatic_maintenance_enabled[service_id] = bool(saved_maintenance.get(service_id, false)) if saved_maintenance is Dictionary else false
		last_maintenance_day[service_id] = maxi(last_payroll_day, int(saved_maintenance_day.get(service_id, last_payroll_day))) if saved_maintenance_day is Dictionary else last_payroll_day

func _get_definition(service_id: String) -> Dictionary:
	for service in SERVICES:
		if str(service["id"]) == service_id:
			return service
	return {}
