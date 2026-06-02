extends CanvasLayer
class_name AmmoHud

const MAGAZINE_LOAD_INDICATOR_SCRIPT := preload("res://scripts/ui/magazine_load_indicator.gd")

@export var player_path: NodePath = NodePath("../Player")

@onready var ammo_value: Label = $Root/Panel/Margin/Rows/AmmoValue
@onready var status_value: Label = $Root/Panel/Margin/Rows/StatusValue
@onready var magazine_row: HBoxContainer = $Root/Panel/Margin/Rows/MagazineRow
@onready var panel: PanelContainer = $Root/Panel
@onready var root: Control = $Root

var _player: PlayerController
var _reload_remaining: float = 0.0
var _status_timer_label: String = "RELOAD"
var _field_loading_active: bool = false
var _check_remaining: float = 0.0
var _check_duration: float = 0.0
var _check_indicator: Control


func _ready() -> void:
	var player := get_node_or_null(player_path) as PlayerController
	if player == null:
		ammo_value.text = "AMMO -- / --"
		status_value.text = "NO PLAYER"
		return

	_player = player
	_create_check_indicator()
	player.ammo_changed.connect(_on_ammo_changed)
	player.reload_started.connect(_on_reload_started)
	player.chambering_started.connect(_on_chambering_started)
	if player.has_signal("loaded_magazine_check_started"):
		player.loaded_magazine_check_started.connect(_on_loaded_magazine_check_started)
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
	if _reload_remaining > 0.0:
		_reload_remaining -= delta
		if _reload_remaining > 0.0:
			status_value.text = "%s %.1f" % [_status_timer_label, _reload_remaining]
		elif _field_loading_active:
			status_value.text = "LOAD"

	if _check_remaining > 0.0:
		_check_remaining -= delta
		var progress := 1.0 - clampf(_check_remaining / maxf(_check_duration, 0.01), 0.0, 1.0)
		status_value.text = "CHECK %.1f" % maxf(_check_remaining, 0.0)
		if _check_indicator != null:
			_check_indicator.position = panel.position + Vector2(panel.size.x - 52.0, 14.0)
			_check_indicator.visible = true
			_check_indicator.set("progress", progress)
		if _check_remaining <= 0.0 and _check_indicator != null:
			_check_indicator.visible = false


func _on_ammo_changed(current_ammo: int, reserve_ammo: int) -> void:
	var current_display := str(current_ammo)
	var reserve_display := str(reserve_ammo)
	if _player != null and _player.has_method("get_ammo_display_pair"):
		var display_pair: Dictionary = _player.call("get_ammo_display_pair")
		current_display = str(display_pair.get("current", current_display))
		reserve_display = str(display_pair.get("reserve", reserve_display))

	ammo_value.text = "AMMO %s / %s" % [current_display, reserve_display]
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


func _on_loaded_magazine_check_started(duration: float) -> void:
	_check_duration = maxf(duration, 0.01)
	_check_remaining = _check_duration
	status_value.text = "CHECK %.1f" % _check_remaining
	if _check_indicator != null:
		_check_indicator.visible = true
		_check_indicator.set("progress", 0.0)


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
	var is_checked := bool(magazine.get("is_checked", false))

	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(24, 38)
	icon.size = icon.custom_minimum_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_theme_stylebox_override("panel", _make_flat_style(Color(0.07, 0.09, 0.1, 0.92), Color(0.46, 0.5, 0.54, 1.0), 1))

	if is_checked:
		var fill := ColorRect.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.color = Color(0.28, 0.68, 0.78, 0.82)
		fill.anchor_left = 0.18
		fill.anchor_right = 0.82
		fill.anchor_bottom = 0.88
		fill.anchor_top = 0.88 - 0.72 * (float(ammo_count) / float(capacity))
		icon.add_child(fill)
	else:
		var unknown := Label.new()
		unknown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unknown.set_anchors_preset(Control.PRESET_FULL_RECT)
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unknown.text = "?"
		unknown.modulate = Color(0.88, 0.9, 0.86, 1.0)
		unknown.add_theme_font_size_override("font_size", 20)
		icon.add_child(unknown)

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


func _create_check_indicator() -> void:
	_check_indicator = MAGAZINE_LOAD_INDICATOR_SCRIPT.new() as Control
	_check_indicator.name = "LoadedMagazineCheckIndicator"
	_check_indicator.visible = false
	_check_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_check_indicator.size = Vector2(42, 42)
	_check_indicator.position = panel.position + Vector2(panel.size.x - 52.0, 14.0)
	_check_indicator.set("progress", 0.0)
	root.add_child(_check_indicator)


func _make_flat_style(background_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	return style
