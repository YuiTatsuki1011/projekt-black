extends CanvasLayer
class_name AmmoHud

@export var player_path: NodePath = NodePath("../Player")

@onready var ammo_value: Label = $Root/Panel/Margin/Rows/AmmoValue
@onready var status_value: Label = $Root/Panel/Margin/Rows/StatusValue

var _reload_remaining: float = 0.0
var _status_timer_label: String = "RELOAD"


func _ready() -> void:
	var player := get_node_or_null(player_path) as PlayerController
	if player == null:
		ammo_value.text = "AMMO -- / --"
		status_value.text = "NO PLAYER"
		return

	player.ammo_changed.connect(_on_ammo_changed)
	player.reload_started.connect(_on_reload_started)
	player.chambering_started.connect(_on_chambering_started)
	_on_ammo_changed(player.current_ammo, player.reserve_ammo)


func _process(delta: float) -> void:
	if _reload_remaining <= 0.0:
		return

	_reload_remaining -= delta
	if _reload_remaining > 0.0:
		status_value.text = "%s %.1f" % [_status_timer_label, _reload_remaining]


func _on_ammo_changed(current_ammo: int, reserve_ammo: int) -> void:
	ammo_value.text = "AMMO %d / %d" % [current_ammo, reserve_ammo]
	_reload_remaining = 0.0

	if current_ammo <= 0 and reserve_ammo > 0:
		status_value.text = "EMPTY"
	elif current_ammo <= 0 and reserve_ammo <= 0:
		status_value.text = "NO AMMO"
	else:
		status_value.text = "READY"


func _on_reload_started(duration: float) -> void:
	_status_timer_label = "RELOAD"
	_reload_remaining = duration
	status_value.text = "RELOAD %.1f" % _reload_remaining


func _on_chambering_started(duration: float) -> void:
	_status_timer_label = "CHAMBER"
	_reload_remaining = duration
	status_value.text = "CHAMBER %.1f" % _reload_remaining
