extends Node
class_name Health

signal health_changed(current_health: int, max_health: int)
signal damaged(amount: int, current_health: int, max_health: int)
signal died

@export var max_health: int = 100
@export var current_health: int = 100

var is_dead: bool = false
var _invulnerability_remaining: float = 0.0


func _ready() -> void:
	current_health = clampi(current_health, 0, max_health)
	is_dead = current_health <= 0
	health_changed.emit(current_health, max_health)


func _process(delta: float) -> void:
	if _invulnerability_remaining <= 0.0:
		return

	_invulnerability_remaining -= delta
	if _invulnerability_remaining < 0.0:
		_invulnerability_remaining = 0.0


func apply_damage(amount: int) -> bool:
	if is_dead or amount <= 0 or is_damage_blocked():
		return false

	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	damaged.emit(amount, current_health, max_health)

	if current_health <= 0:
		is_dead = true
		died.emit()

	return true


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func reset_health() -> void:
	is_dead = false
	_invulnerability_remaining = 0.0
	current_health = max_health
	health_changed.emit(current_health, max_health)


func set_invulnerable_for(duration: float) -> void:
	_invulnerability_remaining = maxf(_invulnerability_remaining, duration)


func is_damage_blocked() -> bool:
	return _invulnerability_remaining > 0.0
