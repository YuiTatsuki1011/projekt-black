extends CanvasLayer
class_name StaminaHud

@export var player_path: NodePath = NodePath("../Player")

@onready var fill: ColorRect = $Root/Panel/Margin/Rows/Bar/Fill
@onready var label: Label = $Root/Panel/Margin/Rows/Label
@onready var status_label: Label = $Root/Panel/Margin/Rows/StatusLabel

var _bar_width: float = 220.0


func _ready() -> void:
	var player := get_node_or_null(player_path)
	if player == null:
		_update_value(0.0, 1.0, true)
		return

	if player.has_signal("stamina_changed"):
		player.stamina_changed.connect(_update_value)

	var current := float(player.get("current_stamina"))
	var maximum := float(player.get("max_stamina"))
	var overheated := bool(player.get("is_stamina_overheated"))
	_update_value(current, maximum, overheated)


func _update_value(current: float, maximum: float, overheated: bool) -> void:
	var safe_maximum := maxf(maximum, 1.0)
	var ratio := clampf(current / safe_maximum, 0.0, 1.0)
	fill.size.x = _bar_width * ratio
	label.text = "STAMINA %d / %d" % [roundi(current), roundi(safe_maximum)]

	if overheated:
		fill.color = Color(0.42, 0.42, 0.42, 1.0)
		status_label.text = "OVERHEAT"
	else:
		fill.color = Color(0.8, 0.62, 0.16, 1.0)
		status_label.text = "READY"
