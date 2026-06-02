extends CanvasLayer
class_name AmmoHud

const MAGAZINE_LOAD_INDICATOR_SCRIPT := preload("res://scripts/ui/magazine_load_indicator.gd")

@export var player_path: NodePath = NodePath("../Player")
@export var loaded_detail_visible_time: float = 5.0
@export var loaded_detail_fade_time: float = 0.75
@export var magazine_panel_margin: Vector2 = Vector2(32.0, 36.0)

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
var _magazine_panel: PanelContainer
var _loaded_detail_label: Label
var _last_magazines: Array = []
var _loaded_detail_hold_remaining: float = 0.0
var _loaded_detail_fade_remaining: float = 0.0


func _ready() -> void:
	_setup_status_panel()
	_setup_magazine_panel()

	var player := get_node_or_null(player_path) as PlayerController
	if player == null:
		status_value.text = "NO PLAYER"
		return

	_player = player
	_create_check_indicator()
	player.ammo_changed.connect(_on_ammo_changed)
	player.reload_started.connect(_on_reload_started)
	player.chambering_started.connect(_on_chambering_started)
	if player.has_signal("loaded_magazine_check_started"):
		player.loaded_magazine_check_started.connect(_on_loaded_magazine_check_started)
	if player.has_signal("loaded_magazine_check_finished"):
		player.loaded_magazine_check_finished.connect(_on_loaded_magazine_check_finished)
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
			_check_indicator.visible = true
			_check_indicator.set("progress", progress)

	_update_loaded_detail(delta)
	_layout_magazine_panel()
	_layout_check_indicator()


func _setup_status_panel() -> void:
	ammo_value.visible = false
	ammo_value.text = ""
	panel.custom_minimum_size = Vector2(150.0, 54.0)
	panel.size = panel.custom_minimum_size
	panel.add_theme_stylebox_override("panel", _make_flat_style(
		Color(0.04, 0.045, 0.05, 0.82),
		Color(0.24, 0.26, 0.28, 0.95),
		1
	))


func _setup_magazine_panel() -> void:
	var old_parent := magazine_row.get_parent()
	if old_parent != null:
		old_parent.remove_child(magazine_row)

	_magazine_panel = PanelContainer.new()
	_magazine_panel.name = "MagazinePanel"
	_magazine_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_magazine_panel.custom_minimum_size = Vector2(180.0, 68.0)
	_magazine_panel.add_theme_stylebox_override("panel", _make_flat_style(
		Color(0.035, 0.04, 0.045, 0.74),
		Color(0.22, 0.24, 0.26, 0.9),
		1
	))
	root.add_child(_magazine_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_magazine_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 4)
	margin.add_child(rows)

	magazine_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	magazine_row.add_theme_constant_override("separation", 8)
	rows.add_child(magazine_row)

	_loaded_detail_label = Label.new()
	_loaded_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loaded_detail_label.visible = false
	_loaded_detail_label.modulate = Color(0.88, 0.9, 0.86, 0.0)
	_loaded_detail_label.add_theme_font_size_override("font_size", 13)
	rows.add_child(_loaded_detail_label)


func _on_ammo_changed(current_ammo: int, reserve_ammo: int) -> void:
	ammo_value.visible = false
	_reload_remaining = 0.0

	if current_ammo <= 0 and reserve_ammo > 0:
		status_value.text = "EMPTY"
	elif current_ammo <= 0 and reserve_ammo <= 0:
		status_value.text = "NO AMMO"
	elif _field_loading_active:
		status_value.text = "LOAD"
	else:
		status_value.text = "READY"

	if _player != null and _player.has_method("get_loaded_ammo_detail"):
		var detail: Dictionary = _player.call("get_loaded_ammo_detail")
		if not bool(detail.get("is_checked", false)):
			_clear_loaded_detail()


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


func _on_loaded_magazine_check_finished(succeeded: bool) -> void:
	_check_remaining = 0.0
	if _check_indicator != null:
		_check_indicator.visible = false
	if succeeded:
		_show_loaded_detail()
	else:
		_clear_loaded_detail()


func _on_magazine_status_changed(
	magazines: Array,
	loading_entry_id: int,
	loading_progress: float,
	is_loading: bool
) -> void:
	_field_loading_active = is_loading
	_last_magazines = magazines.duplicate(true)
	_refresh_magazine_row(loading_entry_id, loading_progress)

	if _field_loading_active and _reload_remaining <= 0.0:
		status_value.text = "LOAD"


func _refresh_magazine_row(loading_entry_id: int = -1, loading_progress: float = 0.0) -> void:
	_clear_magazine_row()
	for magazine in _last_magazines:
		var icon := _create_magazine_icon(magazine, loading_entry_id, loading_progress)
		magazine_row.add_child(icon)
	_layout_magazine_panel()


func _create_magazine_icon(magazine: Dictionary, loading_entry_id: int, loading_progress: float) -> Control:
	var capacity := maxi(int(magazine.get("capacity", 0)), 1)
	var ammo_count := clampi(int(magazine.get("ammo_count", 0)), 0, capacity)
	var entry_id := int(magazine.get("entry_id", -1))
	var is_active := bool(magazine.get("is_active_magazine", false))
	var should_reveal_loaded := is_active and _is_loaded_detail_visible()

	var icon := Panel.new()
	icon.custom_minimum_size = Vector2(24.0, 38.0)
	icon.size = icon.custom_minimum_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_theme_stylebox_override("panel", _make_flat_style(
		Color(0.07, 0.09, 0.1, 0.92),
		Color(0.46, 0.5, 0.54, 1.0),
		1
	))

	if should_reveal_loaded:
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

	if is_active:
		return _wrap_active_magazine_icon(icon)
	return icon


func _wrap_active_magazine_icon(icon: Control) -> Control:
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.custom_minimum_size = Vector2(36.0, 44.0)
	wrapper.size = wrapper.custom_minimum_size
	icon.position = Vector2(6.0, 3.0)
	wrapper.add_child(icon)

	_add_bracket_rect(wrapper, Vector2(0.0, 6.0), Vector2(2.0, 32.0))
	_add_bracket_rect(wrapper, Vector2(0.0, 6.0), Vector2(7.0, 2.0))
	_add_bracket_rect(wrapper, Vector2(0.0, 36.0), Vector2(7.0, 2.0))
	_add_bracket_rect(wrapper, Vector2(34.0, 6.0), Vector2(2.0, 32.0))
	_add_bracket_rect(wrapper, Vector2(29.0, 6.0), Vector2(7.0, 2.0))
	_add_bracket_rect(wrapper, Vector2(29.0, 36.0), Vector2(7.0, 2.0))
	return wrapper


func _add_bracket_rect(parent: Control, position: Vector2, size: Vector2) -> void:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = position
	rect.size = size
	rect.color = Color(1.0, 0.5, 0.12, 0.95)
	parent.add_child(rect)


func _show_loaded_detail() -> void:
	if _player == null or not _player.has_method("get_loaded_ammo_detail"):
		return

	var detail: Dictionary = _player.call("get_loaded_ammo_detail")
	if detail.is_empty() or not bool(detail.get("is_checked", false)):
		return

	var total := int(detail.get("total_loaded_ammo", 0))
	var magazine_ammo := int(detail.get("magazine_ammo", 0))
	var magazine_capacity := int(detail.get("magazine_capacity", 0))
	var chamber_ammo := int(detail.get("chamber_ammo", 0))
	var chamber_capacity := int(detail.get("chamber_capacity", 0))
	var ammo_name := str(detail.get("ammo_name", "Ammo"))
	_loaded_detail_label.text = "LOADED %d  |  %s\nMAG %d/%d + CH %d/%d" % [
		total,
		ammo_name,
		magazine_ammo,
		magazine_capacity,
		chamber_ammo,
		chamber_capacity,
	]
	_loaded_detail_label.visible = true
	_loaded_detail_label.modulate.a = 1.0
	_loaded_detail_hold_remaining = loaded_detail_visible_time
	_loaded_detail_fade_remaining = loaded_detail_fade_time
	_refresh_magazine_row()


func _clear_loaded_detail() -> void:
	_loaded_detail_hold_remaining = 0.0
	_loaded_detail_fade_remaining = 0.0
	if _loaded_detail_label != null:
		_loaded_detail_label.visible = false
		_loaded_detail_label.modulate.a = 0.0
	_refresh_magazine_row()


func _update_loaded_detail(delta: float) -> void:
	var was_visible := _is_loaded_detail_visible()
	if _loaded_detail_hold_remaining > 0.0:
		_loaded_detail_hold_remaining = maxf(_loaded_detail_hold_remaining - delta, 0.0)
		if _loaded_detail_label != null:
			_loaded_detail_label.modulate.a = 1.0
	elif _loaded_detail_fade_remaining > 0.0:
		_loaded_detail_fade_remaining = maxf(_loaded_detail_fade_remaining - delta, 0.0)
		if _loaded_detail_label != null:
			_loaded_detail_label.modulate.a = clampf(
				_loaded_detail_fade_remaining / maxf(loaded_detail_fade_time, 0.01),
				0.0,
				1.0
			)
	elif _loaded_detail_label != null:
		_loaded_detail_label.visible = false

	if was_visible and not _is_loaded_detail_visible():
		_refresh_magazine_row()


func _is_loaded_detail_visible() -> bool:
	return _loaded_detail_hold_remaining > 0.0 or _loaded_detail_fade_remaining > 0.0


func _clear_magazine_row() -> void:
	for child in magazine_row.get_children():
		magazine_row.remove_child(child)
		child.queue_free()


func _create_check_indicator() -> void:
	_check_indicator = MAGAZINE_LOAD_INDICATOR_SCRIPT.new() as Control
	_check_indicator.name = "LoadedMagazineCheckIndicator"
	_check_indicator.visible = false
	_check_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_check_indicator.size = Vector2(42.0, 42.0)
	_check_indicator.set("progress", 0.0)
	root.add_child(_check_indicator)


func _layout_magazine_panel() -> void:
	if _magazine_panel == null:
		return

	_magazine_panel.size = _magazine_panel.get_combined_minimum_size()
	var viewport_size := get_viewport().get_visible_rect().size
	_magazine_panel.position = Vector2(
		magazine_panel_margin.x,
		maxf(magazine_panel_margin.y, viewport_size.y - _magazine_panel.size.y - magazine_panel_margin.y)
	)


func _layout_check_indicator() -> void:
	if _check_indicator == null or _magazine_panel == null:
		return

	_check_indicator.position = _magazine_panel.position + Vector2(_magazine_panel.size.x + 8.0, 6.0)


func _make_flat_style(background_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	return style
