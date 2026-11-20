extends Node
class_name EconomyService

signal balance_changed(new_balance: int)
signal transaction_completed(amount: int, reason: String)

const MAX_TRANSACTION_HISTORY := 100

var balance: int = 1000000
var transaction_history: Array[Dictionary] = []

func set_balance(value: int) -> void:
	balance = maxi(0, value)
	balance_changed.emit(balance)

func try_spend(amount: int, reason: String) -> bool:
	if amount <= 0 or balance < amount:
		return false
	balance -= amount
	_record_transaction(-amount, reason)
	balance_changed.emit(balance)
	transaction_completed.emit(-amount, reason)
	return true

func add_money(amount: int, reason: String) -> void:
	if amount <= 0:
		return
	balance += amount
	_record_transaction(amount, reason)
	balance_changed.emit(balance)
	transaction_completed.emit(amount, reason)

func _record_transaction(amount: int, reason: String) -> void:
	transaction_history.append({
		"amount": amount,
		"reason": reason,
		"balance_after": balance,
		"timestamp": int(Time.get_unix_time_from_system())
	})
	while transaction_history.size() > MAX_TRANSACTION_HISTORY:
		transaction_history.pop_front()

func get_transaction_history() -> Array[Dictionary]:
	return transaction_history.duplicate(true)

func load_transaction_history(entries: Array) -> void:
	transaction_history.clear()
	for entry in entries:
		if not entry is Dictionary:
			continue
		var amount := int(entry.get("amount", 0))
		var reason := str(entry.get("reason", "")).strip_edges()
		if amount == 0 or reason.is_empty():
			continue
		transaction_history.append({
			"amount": amount,
			"reason": reason,
			"balance_after": maxi(0, int(entry.get("balance_after", 0))),
			"timestamp": maxi(0, int(entry.get("timestamp", 0)))
		})
	while transaction_history.size() > MAX_TRANSACTION_HISTORY:
		transaction_history.pop_front()
