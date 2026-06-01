extends CanvasLayer
class_name StaminaHud

@export var player_path: NodePath = NodePath("../Player")

@onready var panel: PanelContainer = $Root/Panel
@onready var fill: ColorRect = $Root/Panel/Margin/Rows/Bar/Fill
@onready var label: Label = $Root/Panel/Margin/Rows/Label
@onready var status_label: Label = $Root/Panel/Margin/Rows/StatusLabel

var _bar_width: float = 220.0
var _base_panel_position: Vector2 = Vector2.ZERO
var _shake_tween: Tween


func _ready() -> void:
	_base_panel_position = panel.position
	var player := get_node_or_null(player_path)
	if player == null:
		_update_value(0.0, 1.0, true, false)
		return

	if player.has_signal("stamina_changed"):
		player.stamina_changed.connect(_update_value)
	if player.has_signal("stamina_use_failed"):
		player.stamina_use_failed.connect(_play_failed_feedback)

	var current := float(player.get("current_stamina"))
	var maximum := float(player.get("max_stamina"))
	var overheated := bool(player.get("is_stamina_overheated"))
	var minimum := float(player.get("melee_min_stamina_to_use"))
	_update_value(current, maximum, overheated, current >= minimum and not overheated)


func _update_value(current: float, maximum: float, overheated: bool, melee_available: bool) -> void:
	var safe_maximum := maxf(maximum, 1.0)
	var ratio := clampf(current / safe_maximum, 0.0, 1.0)
	fill.size.x = _bar_width * ratio
	label.text = "STAMINA %d / %d" % [roundi(current), roundi(safe_maximum)]

	if overheated:
		fill.color = Color(0.42, 0.42, 0.42, 1.0)
		status_label.text = "OVERHEAT"
	elif not melee_available:
		fill.color = Color(0.48, 0.48, 0.48, 1.0)
		status_label.text = "LOW STAMINA"
	else:
		fill.color = Color(0.8, 0.62, 0.16, 1.0)
		status_label.text = "READY"


func _play_failed_feedback() -> void:
	if _shake_tween != null:
		_shake_tween.kill()

	panel.position = _base_panel_position
	_shake_tween = create_tween()
	_shake_tween.tween_property(panel, "position", _base_panel_position + Vector2(7, 0), 0.035)
	_shake_tween.tween_property(panel, "position", _base_panel_position + Vector2(-7, 0), 0.055)
	_shake_tween.tween_property(panel, "position", _base_panel_position + Vector2(4, 0), 0.045)
	_shake_tween.tween_property(panel, "position", _base_panel_position, 0.045)
