extends Node
class_name EconomyService

signal balance_changed(new_balance: int)
signal transaction_completed(amount: int, reason: String)

var balance: int = 1000000

func try_spend(amount: int, reason: String) -> bool:
	if amount <= 0 or balance < amount:
		return false
	balance -= amount
	balance_changed.emit(balance)
	transaction_completed.emit(-amount, reason)
	return true

func add_money(amount: int, reason: String) -> void:
	if amount <= 0:
		return
	balance += amount
	balance_changed.emit(balance)
	transaction_completed.emit(amount, reason)
