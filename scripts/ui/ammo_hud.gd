extends CanvasLayer
class_name AmmoHud

const MAGAZINE_LOAD_INDICATOR_SCRIPT := preload("res://scripts/ui/magazine_load_indicator.gd")

const MAGAZINE_SLOT_SIZE := Vector2(88.0, 132.0)
const MAGAZINE_ICON_SIZE := Vector2(66.0, 104.0)
const MAGAZINE_PANEL_PADDING := Vector2(14.0, 12.0)
const MAGAZINE_DETAIL_HEIGHT := 78.0
const MAGAZINE_ROW_SEPARATION := 10.0
const ACTIVE_BORDER_WIDTH := 5
const CURSOR_INDICATOR_SIZE := Vector2(96.0, 96.0)

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
var _field_loading_active: bool = false
var _magazine_panel: Panel
var _loaded_detail_label: Label
var _cursor_operation_indicator: Control
var _last_magazines: Array = []
var _active_magazine_frames: Array[Control] = []
var _loaded_detail_hold_remaining: float = 0.0
var _loaded_detail_fade_remaining: float = 0.0
var _cursor_operation_remaining: float = 0.0
var _cursor_operation_duration: float = 0.0
var _active_border_blink_time: float = 0.0


func _ready() -> void:
	_hide_status_panel()
	_setup_magazine_panel()
	_create_cursor_operation_indicator()

	var player := get_node_or_null(player_path) as PlayerController
	if player == null:
		return

	_player = player
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


func _process(delta: float) -> void:
	_update_cursor_operation(delta)
	_update_loaded_detail(delta)
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
		Color(0.035, 0.04, 0.045, 0.76),
		Color(0.22, 0.24, 0.26, 0.92),
		1
	))
	root.add_child(_magazine_panel)

	_loaded_detail_label = Label.new()
	_loaded_detail_label.name = "LoadedDetailLabel"
	_loaded_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loaded_detail_label.visible = false
	_loaded_detail_label.modulate = Color(0.88, 0.9, 0.86, 0.0)
	_loaded_detail_label.add_theme_font_size_override("font_size", 29)
	_loaded_detail_label.add_theme_color_override("font_color", Color(0.88, 0.9, 0.86, 1.0))
	_magazine_panel.add_child(_loaded_detail_label)

	magazine_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	magazine_row.add_theme_constant_override("separation", int(MAGAZINE_ROW_SEPARATION))
	_magazine_panel.add_child(magazine_row)


func _create_cursor_operation_indicator() -> void:
	_cursor_operation_indicator = MAGAZINE_LOAD_INDICATOR_SCRIPT.new() as Control
	_cursor_operation_indicator.name = "CursorOperationIndicator"
	_cursor_operation_indicator.visible = false
	_cursor_operation_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_operation_indicator.size = CURSOR_INDICATOR_SIZE
	_cursor_operation_indicator.set("progress", 0.0)
	root.add_child(_cursor_operation_indicator)


func _on_ammo_changed(_current_ammo: int, _reserve_ammo: int) -> void:
	if _player != null and _player.has_method("get_loaded_ammo_detail"):
		var detail: Dictionary = _player.call("get_loaded_ammo_detail")
		if not bool(detail.get("is_checked", false)):
			_clear_loaded_detail()


func _on_reload_started(duration: float) -> void:
	_start_cursor_operation(duration)


func _on_chambering_started(duration: float) -> void:
	_start_cursor_operation(duration)


func _on_loaded_magazine_check_started(duration: float) -> void:
	_start_cursor_operation(duration)


func _on_loaded_magazine_check_finished(succeeded: bool) -> void:
	_stop_cursor_operation()
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
	var is_checked := bool(magazine.get("is_checked", false))
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
		2
	))
	slot.add_child(icon)

	if is_checked:
		var fill := ColorRect.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.color = Color(0.28, 0.68, 0.78, 0.84)
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
		unknown.modulate = Color(0.78, 0.8, 0.76, 0.78)
		unknown.add_theme_font_size_override("font_size", 42)
		icon.add_child(unknown)

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


func _start_cursor_operation(duration: float) -> void:
	_cursor_operation_duration = maxf(duration, 0.01)
	_cursor_operation_remaining = _cursor_operation_duration
	if _cursor_operation_indicator != null:
		_cursor_operation_indicator.visible = true
		_cursor_operation_indicator.set("progress", 0.0)
		_layout_cursor_operation_indicator()


func _stop_cursor_operation() -> void:
	_cursor_operation_remaining = 0.0
	_cursor_operation_duration = 0.0
	if _cursor_operation_indicator != null:
		_cursor_operation_indicator.visible = false
		_cursor_operation_indicator.set("progress", 0.0)


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

	var detail_height := MAGAZINE_DETAIL_HEIGHT if _is_loaded_detail_visible() else 0.0
	var row_width := _get_magazine_row_width()
	var panel_width := maxf(260.0, row_width + MAGAZINE_PANEL_PADDING.x * 2.0)
	var panel_height := MAGAZINE_PANEL_PADDING.y * 2.0 + MAGAZINE_SLOT_SIZE.y + detail_height
	_magazine_panel.size = Vector2(panel_width, panel_height)

	_loaded_detail_label.visible = _is_loaded_detail_visible()
	_loaded_detail_label.position = MAGAZINE_PANEL_PADDING
	_loaded_detail_label.size = Vector2(panel_width - MAGAZINE_PANEL_PADDING.x * 2.0, MAGAZINE_DETAIL_HEIGHT)

	magazine_row.position = Vector2(
		MAGAZINE_PANEL_PADDING.x,
		panel_height - MAGAZINE_PANEL_PADDING.y - MAGAZINE_SLOT_SIZE.y
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
