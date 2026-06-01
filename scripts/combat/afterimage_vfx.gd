extends Node2D
class_name AfterimageVfx

@export var lifetime: float = 0.18

var _age: float = 0.0


func _process(delta: float) -> void:
	_age += delta
	var ratio := clampf(_age / lifetime, 0.0, 1.0)
	modulate.a = 1.0 - ratio

	if _age >= lifetime:
		queue_free()
