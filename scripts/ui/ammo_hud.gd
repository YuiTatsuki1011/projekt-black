extends CanvasLayer
class_name AmmoHud

const MAGAZINE_LOAD_INDICATOR_SCRIPT := preload("res://scripts/ui/magazine_load_indicator.gd")

const MAGAZINE_SLOT_SIZE := Vector2(44.0, 66.0)
const MAGAZINE_ICON_SIZE := Vector2(32.0, 52.0)
const MAGAZINE_PANEL_PADDING := Vector2(14.0, 12.0)
const MAGAZINE_INFO_HEIGHT := 72.0
const MAGAZINE_ROW_SEPARATION := 6.0
const ACTIVE_BORDER_WIDTH := 3
const CURSOR_INDICATOR_SIZE := Vector2(96.0, 96.0)
const GUN_ICON_SIZE := Vector2(68.0, 42.0)
const GUN_INFO_GAP := 12.0

@export var player_path: NodePath = NodePath("../Player")
@export var magazine_panel_margin: Vector2 = Vector2(32.0, 36.0)

@onready var ammo_value: Label = $Root/Panel/Margin/Rows/AmmoValue
@onready var status_value: Label = $Root/Panel/Margin/Rows/StatusValue
@onready var magazine_row: HBoxContainer = $Root/Panel/Margin/Rows/MagazineRow
@onready var panel: PanelContainer = $Root/Panel
@onready var root: Control = $Root

var _player: PlayerController
var _magazine_panel: Panel
var _weapon_icon: Control
var _weapon_status_label: Label
var _cursor_operation_indicator: Control
var _last_magazines: Array = []
var _active_magazine_frames: Array[Control] = []
var _cursor_operation_remaining: float = 0.0
var _cursor_operation_duration: float = 0.0
var _active_border_blink_time: float = 0.0


func _ready() -> void:
	_hide_status_panel()
	_setup_magazine_panel()
	_create_cursor_operation_indicator()

	var player := get_node_or_null(player_path) as PlayerController
	if player == null:
		_update_weapon_status()
		return

	_player = player
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
	_update_weapon_status()


func _process(delta: float) -> void:
	_update_cursor_operation(delta)
	_update_active_frame_blink(delta)
	_layout_magazine_panel()
	_layout_cursor_operation_indicator()


func _hide_status_panel() -> void:
	panel.visible = false
	ammo_value.visible = false
	ammo_value.text = ""
	status_value.visible = false
	status_value.text = ""


func _setup_magazine_panel() -> void:
	var old_parent := magazine_row.get_parent()
	if old_parent != null:
		old_parent.remove_child(magazine_row)

	_magazine_panel = Panel.new()
	_magazine_panel.name = "MagazinePanel"
	_magazine_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_magazine_panel.add_theme_stylebox_override("panel", _make_flat_style(
		Color(0.035, 0.04, 0.045, 0.78),
		Color(0.22, 0.24, 0.26, 0.92),
		1
	))
	root.add_child(_magazine_panel)

	_weapon_icon = _create_gun_icon()
	_magazine_panel.add_child(_weapon_icon)

	_weapon_status_label = Label.new()
	_weapon_status_label.name = "WeaponStatusLabel"
	_weapon_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_status_label.add_theme_font_size_override("font_size", 29)
	_weapon_status_label.add_theme_color_override("font_color", Color(0.88, 0.9, 0.86, 1.0))
	_weapon_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_weapon_status_label.add_theme_constant_override("shadow_offset_x", 1)
	_weapon_status_label.add_theme_constant_override("shadow_offset_y", 1)
	_magazine_panel.add_child(_weapon_status_label)

	magazine_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	magazine_row.add_theme_constant_override("separation", int(MAGAZINE_ROW_SEPARATION))
	_magazine_panel.add_child(magazine_row)


func _create_gun_icon() -> Control:
	var holder := Control.new()
	holder.name = "GunIcon"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = GUN_ICON_SIZE
	holder.size = GUN_ICON_SIZE

	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_stylebox_override("panel", _make_flat_style(
		Color(0.06, 0.07, 0.075, 0.92),
		Color(0.33, 0.36, 0.39, 0.95),
		1
	))
	holder.add_child(frame)

	_add_icon_rect(holder, Vector2(14, 16), Vector2(36, 8), Color(0.56, 0.6, 0.62, 1.0))
	_add_icon_rect(holder, Vector2(43, 20), Vector2(10, 5), Color(0.56, 0.6, 0.62, 1.0))
	_add_icon_rect(holder, Vector2(25, 24), Vector2(10, 14), Color(0.42, 0.46, 0.48, 1.0))
	_add_icon_rect(holder, Vector2(38, 25), Vector2(7, 10), Color(0.42, 0.46, 0.48, 1.0))
	return holder


func _add_icon_rect(parent: Node, position: Vector2, size: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = position
	rect.size = size
	rect.color = color
	parent.add_child(rect)


func _create_cursor_operation_indicator() -> void:
	_cursor_operation_indicator = MAGAZINE_LOAD_INDICATOR_SCRIPT.new() as Control
	_cursor_operation_indicator.name = "CursorOperationIndicator"
	_cursor_operation_indicator.visible = false
	_cursor_operation_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_operation_indicator.size = CURSOR_INDICATOR_SIZE
	_cursor_operation_indicator.set("progress", 0.0)
	root.add_child(_cursor_operation_indicator)


func _on_ammo_changed(_current_ammo: int, _reserve_ammo: int) -> void:
	_update_weapon_status()


func _on_reload_started(duration: float) -> void:
	_start_cursor_operation(duration)


func _on_chambering_started(duration: float) -> void:
	_start_cursor_operation(duration)


func _on_magazine_status_changed(
	magazines: Array,
	loading_entry_id: int,
	loading_progress: float,
	_is_loading: bool
) -> void:
	_last_magazines = magazines.duplicate(true)
	_update_weapon_status()
	_refresh_magazine_row(loading_entry_id, loading_progress)


func _refresh_magazine_row(loading_entry_id: int = -1, loading_progress: float = 0.0) -> void:
	_clear_magazine_row()
	_active_magazine_frames.clear()
	for magazine in _last_magazines:
		var icon := _create_magazine_slot(magazine, loading_entry_id, loading_progress)
		magazine_row.add_child(icon)
	_layout_magazine_panel()


func _create_magazine_slot(magazine: Dictionary, loading_entry_id: int, loading_progress: float) -> Control:
	var capacity := maxi(int(magazine.get("capacity", 0)), 1)
	var ammo_count := clampi(int(magazine.get("ammo_count", 0)), 0, capacity)
	var entry_id := int(magazine.get("entry_id", -1))
	var is_active := bool(magazine.get("is_active_magazine", false))

	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = MAGAZINE_SLOT_SIZE
	slot.size = MAGAZINE_SLOT_SIZE

	var icon := Panel.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = (MAGAZINE_SLOT_SIZE - MAGAZINE_ICON_SIZE) * 0.5
	icon.size = MAGAZINE_ICON_SIZE
	icon.add_theme_stylebox_override("panel", _make_flat_style(
		Color(0.07, 0.09, 0.1, 0.92),
		Color(0.46, 0.5, 0.54, 1.0),
		1
	))
	slot.add_child(icon)

	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = Color(0.28, 0.68, 0.78, 0.86)
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
		var active_frame := Panel.new()
		active_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		active_frame.position = Vector2.ZERO
		active_frame.size = MAGAZINE_SLOT_SIZE
		active_frame.add_theme_stylebox_override("panel", _make_flat_style(
			Color(0, 0, 0, 0),
			Color(1.0, 0.5, 0.12, 1.0),
			ACTIVE_BORDER_WIDTH
		))
		slot.add_child(active_frame)
		_active_magazine_frames.append(active_frame)

	return slot


func _update_weapon_status() -> void:
	if _weapon_status_label == null:
		return

	var weapon_name := "NO FIREARM"
	var loaded_ammo := 0
	var max_loaded_ammo := 0
	var magazine_count := _last_magazines.size()

	if _player != null and _player.has_method("get_firearm_hud_info"):
		var info: Dictionary = _player.call("get_firearm_hud_info")
		weapon_name = str(info.get("weapon_name", weapon_name)).to_upper()
		loaded_ammo = int(info.get("current_loaded_ammo", loaded_ammo))
		max_loaded_ammo = int(info.get("max_loaded_ammo", max_loaded_ammo))
		magazine_count = int(info.get("magazine_count", magazine_count))

	_weapon_status_label.text = "%s  %d/%d\nMAGS x%d" % [
		weapon_name,
		loaded_ammo,
		max_loaded_ammo,
		magazine_count,
	]
	_weapon_icon.modulate.a = 1.0 if max_loaded_ammo > 0 else 0.38


func _start_cursor_operation(duration: float) -> void:
	_cursor_operation_duration = maxf(duration, 0.01)
	_cursor_operation_remaining = _cursor_operation_duration
	if _cursor_operation_indicator != null:
		_cursor_operation_indicator.visible = true
		_cursor_operation_indicator.set("progress", 0.0)
		_layout_cursor_operation_indicator()


func _update_cursor_operation(delta: float) -> void:
	if _cursor_operation_remaining <= 0.0:
		return

	_cursor_operation_remaining = maxf(_cursor_operation_remaining - delta, 0.0)
	var progress := 1.0 - clampf(_cursor_operation_remaining / maxf(_cursor_operation_duration, 0.01), 0.0, 1.0)
	if _cursor_operation_indicator != null:
		_cursor_operation_indicator.visible = true
		_cursor_operation_indicator.set("progress", progress)
	if _cursor_operation_remaining <= 0.0 and _cursor_operation_indicator != null:
		_cursor_operation_indicator.visible = false


func _update_active_frame_blink(delta: float) -> void:
	_active_border_blink_time += delta
	var alpha: float = 0.35 + 0.65 * ((sin(_active_border_blink_time * 5.6) + 1.0) * 0.5)
	for frame in _active_magazine_frames:
		if is_instance_valid(frame):
			frame.modulate.a = alpha


func _clear_magazine_row() -> void:
	for child in magazine_row.get_children():
		magazine_row.remove_child(child)
		child.queue_free()


func _layout_magazine_panel() -> void:
	if _magazine_panel == null:
		return

	var row_width := _get_magazine_row_width()
	var info_width := GUN_ICON_SIZE.x + GUN_INFO_GAP + _weapon_status_label.get_minimum_size().x
	var panel_width := maxf(320.0, maxf(row_width, info_width) + MAGAZINE_PANEL_PADDING.x * 2.0)
	var panel_height := (
		MAGAZINE_PANEL_PADDING.y * 2.0
		+ MAGAZINE_INFO_HEIGHT
		+ MAGAZINE_SLOT_SIZE.y
		+ MAGAZINE_ROW_SEPARATION
	)
	_magazine_panel.size = Vector2(panel_width, panel_height)

	_weapon_icon.position = MAGAZINE_PANEL_PADDING + Vector2(0.0, 8.0)
	_weapon_icon.size = GUN_ICON_SIZE
	_weapon_status_label.position = MAGAZINE_PANEL_PADDING + Vector2(GUN_ICON_SIZE.x + GUN_INFO_GAP, 0.0)
	_weapon_status_label.size = Vector2(
		panel_width - MAGAZINE_PANEL_PADDING.x * 2.0 - GUN_ICON_SIZE.x - GUN_INFO_GAP,
		MAGAZINE_INFO_HEIGHT
	)

	magazine_row.position = Vector2(
		MAGAZINE_PANEL_PADDING.x,
		MAGAZINE_PANEL_PADDING.y + MAGAZINE_INFO_HEIGHT + MAGAZINE_ROW_SEPARATION
	)

	var viewport_size := get_viewport().get_visible_rect().size
	_magazine_panel.position = Vector2(
		magazine_panel_margin.x,
		maxf(magazine_panel_margin.y, viewport_size.y - panel_height - magazine_panel_margin.y)
	)


func _get_magazine_row_width() -> float:
	var count := magazine_row.get_child_count()
	if count <= 0:
		return 0.0
	return float(count) * MAGAZINE_SLOT_SIZE.x + float(count - 1) * MAGAZINE_ROW_SEPARATION


func _layout_cursor_operation_indicator() -> void:
	if _cursor_operation_indicator == null:
		return

	_cursor_operation_indicator.size = CURSOR_INDICATOR_SIZE
	_cursor_operation_indicator.position = get_viewport().get_mouse_position() - CURSOR_INDICATOR_SIZE * 0.5


func _make_flat_style(background_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	return style
