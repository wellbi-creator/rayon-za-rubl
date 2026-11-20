extends RefCounted
class_name DistrictUpkeepService

# A deliberately modest prototype rate; balance can be tuned after playtesting.
const DAILY_COST_PER_RESIDENT := 150

var last_billed_day: int = 1
var unpaid_balance: int = 0

func initialize_day(day: int) -> void:
	last_billed_day = maxi(1, day)
	unpaid_balance = 0

func process_day(day: int, resident_count: int, economy: EconomyService) -> bool:
	var elapsed_days := day - last_billed_day
	if elapsed_days <= 0:
		return false
	var safe_resident_count := maxi(0, resident_count)
	var new_charges := elapsed_days * safe_resident_count * DAILY_COST_PER_RESIDENT
	unpaid_balance += new_charges
	last_billed_day = day
	if unpaid_balance > 0 and economy != null and economy.balance > 0:
		var payment := mini(unpaid_balance, economy.balance)
		if payment > 0 and economy.try_spend(payment, "Коммунальные расходы района"):
			unpaid_balance -= payment
	return true

func get_daily_cost(resident_count: int) -> int:
	return maxi(0, resident_count) * DAILY_COST_PER_RESIDENT

func get_save_data() -> Dictionary:
	return {
		"last_billed_day": last_billed_day,
		"unpaid_balance": unpaid_balance
	}

func load_save_data(data: Dictionary) -> void:
	last_billed_day = maxi(1, int(data.get("last_billed_day", 1)))
	unpaid_balance = maxi(0, int(data.get("unpaid_balance", 0)))
