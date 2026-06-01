extends StaticBody2D
class_name TrainingTarget

@onready var health: Node = $Health


func _ready() -> void:
	health.died.connect(_on_died)


func _on_died() -> void:
	queue_free()
