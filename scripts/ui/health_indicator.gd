extends Node2D
class_name HealthIndicator

@export var health_path: NodePath = NodePath("../Health")
@export var bar_width: float = 42.0
@export var bar_height: float = 5.0
@export var text_offset_y: float = -17.0

@onready var fill: ColorRect = $BarBackground/Fill
@onready var value_label: Label = $ValueLabel

var _max_health: int = 1
var _current_health: int = 1


func _ready() -> void:
	var health: Node = get_node_or_null(health_path)
	if health == null:
		_set_value(0, 1)
		return

	health.health_changed.connect(_set_value)
	_set_value(health.current_health, health.max_health)


func _set_value(current_health: int, max_health: int) -> void:
	_current_health = current_health
	_max_health = maxi(max_health, 1)

	var health_ratio := clampf(float(_current_health) / float(_max_health), 0.0, 1.0)
	fill.size.x = bar_width * health_ratio
	value_label.text = "%d/%d" % [_current_health, _max_health]
