extends CanvasLayer
class_name AmmoHud

const MAGAZINE_LOAD_INDICATOR_SCRIPT := preload("res://scripts/ui/magazine_load_indicator.gd")

@export var player_path: NodePath = NodePath("../Player")

@onready var ammo_value: Label = $Root/Panel/Margin/Rows/AmmoValue
@onready var status_value: Label = $Root/Panel/Margin/Rows/StatusValue
@onready var magazine_row: HBoxContainer = $Root/Panel/Margin/Rows/MagazineRow

var _reload_remaining: float = 0.0
var _status_timer_label: String = "RELOAD"
var _field_loading_active: bool = false


func _ready() -> void:
	var player := get_node_or_null(player_path) as PlayerController
	if player == null:
		ammo_value.text = "AMMO -- / --"
		status_value.text = "NO PLAYER"
		return

	player.ammo_changed.connect(_on_ammo_changed)
	player.reload_started.connect(_on_reload_started)
	player.chambering_started.connect(_on_chambering_started)
	if player.has_signal("magazine_status_changed"):
		player.magazine_status_changed.connect(_on_magazine_status_changed)
	if player.has_method("get_active_magazine_statuses"):
		_on_magazine_status_changed(
			player.call("get_active_magazine_statuses"),
			int(player.call("get_field_magazine_loading_entry_id")),
			float(player.call("get_field_magazine_loading_progress")),
			bool(player.call("is_field_magazine_loading"))
		)
	_on_ammo_changed(player.current_ammo, player.reserve_ammo)


func _process(delta: float) -> void:
	if _reload_remaining <= 0.0:
		return

	_reload_remaining -= delta
	if _reload_remaining > 0.0:
		status_value.text = "%s %.1f" % [_status_timer_label, _reload_remaining]
	elif _field_loading_active:
		status_value.text = "LOAD"


func _on_ammo_changed(current_ammo: int, reserve_ammo: int) -> void:
	ammo_value.text = "AMMO %d / %d" % [current_ammo, reserve_ammo]
	_reload_remaining = 0.0

	if current_ammo <= 0 and reserve_ammo > 0:
		status_value.text = "EMPTY"
	elif current_ammo <= 0 and reserve_ammo <= 0:
		status_value.text = "NO AMMO"
	elif _field_loading_active:
		status_value.text = "LOAD"
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


func _on_magazine_status_changed(
	magazines: Array,
	loading_entry_id: int,
	loading_progress: float,
	is_loading: bool
) -> void:
	_field_loading_active = is_loading
	_clear_magazine_row()

	for magazine in magazines:
		var icon := _create_magazine_icon(magazine, loading_entry_id, loading_progress)
		magazine_row.add_child(icon)

	if _field_loading_active and _reload_remaining <= 0.0:
		status_value.text = "LOAD"


func _create_magazine_icon(magazine: Dictionary, loading_entry_id: int, loading_progress: float) -> Control:
	var capacity := maxi(int(magazine.get("capacity", 0)), 1)
	var ammo_count := clampi(int(magazine.get("ammo_count", 0)), 0, capacity)
	var entry_id := int(magazine.get("entry_id", -1))

	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(24, 38)
	icon.size = icon.custom_minimum_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_theme_stylebox_override("panel", _make_flat_style(Color(0.07, 0.09, 0.1, 0.92), Color(0.46, 0.5, 0.54, 1.0), 1))

	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = Color(0.28, 0.68, 0.78, 0.82)
	fill.anchor_left = 0.18
	fill.anchor_right = 0.82
	fill.anchor_bottom = 0.88
	fill.anchor_top = 0.88 - 0.72 * (float(ammo_count) / float(capacity))
	icon.add_child(fill)

	if entry_id == loading_entry_id:
		var indicator := MAGAZINE_LOAD_INDICATOR_SCRIPT.new() as Control
		indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
		indicator.set("progress", loading_progress)
		icon.add_child(indicator)

	return icon


func _clear_magazine_row() -> void:
	for child in magazine_row.get_children():
		magazine_row.remove_child(child)
		child.queue_free()


func _make_flat_style(background_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	return style
