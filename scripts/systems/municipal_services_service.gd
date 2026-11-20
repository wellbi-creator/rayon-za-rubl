extends RefCounted
class_name MunicipalServicesService

const MAX_EMPLOYEES_PER_SERVICE := 10
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

func _init() -> void:
	for service in SERVICES:
		employees[str(service["id"])] = 0

func get_service_definitions() -> Array:
	return SERVICES.duplicate(true)

func get_employee_count(service_id: String) -> int:
	return int(employees.get(service_id, 0))

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
		"unpaid_wages": unpaid_wages
	}

func load_save_data(data: Dictionary) -> void:
	for service in SERVICES:
		var service_id := str(service["id"])
		employees[service_id] = clampi(int(data.get("employees", {}).get(service_id, 0)), 0, MAX_EMPLOYEES_PER_SERVICE)
	last_payroll_day = maxi(1, int(data.get("last_payroll_day", 1)))
	unpaid_wages = maxi(0, int(data.get("unpaid_wages", 0)))

func _get_definition(service_id: String) -> Dictionary:
	for service in SERVICES:
		if str(service["id"]) == service_id:
			return service
	return {}
