extends CanvasLayer
class_name InventoryScreen

const CELL_SIZE: int = 48
const CELL_GAP: int = 2
const CELL_PITCH: int = CELL_SIZE + CELL_GAP
const CELL_COLOR := Color(0.16, 0.17, 0.19, 1.0)
const CELL_BORDER_COLOR := Color(0.36, 0.38, 0.42, 1.0)
const ITEM_BORDER_COLOR := Color(0.9, 0.92, 0.84, 1.0)
const PLACEABLE_COLOR := Color(0.18, 0.82, 0.35, 0.42)
const BLOCKED_COLOR := Color(0.95, 0.12, 0.1, 0.5)
const SLOT_COLOR := Color(0.12, 0.13, 0.15, 1.0)
const SLOT_BORDER_COLOR := Color(0.42, 0.44, 0.48, 1.0)
const SLOT_ACTIVE_BORDER_COLOR := Color(0.44, 0.9, 0.55, 1.0)
const SLOT_PLACEABLE_COLOR := Color(0.18, 0.82, 0.35, 0.32)
const SLOT_BLOCKED_COLOR := Color(0.95, 0.12, 0.1, 0.34)
const DETAIL_PANEL_SIZE := Vector2(306, 318)
const DETAIL_PANEL_GAP := 12.0
const DETAIL_PANEL_COLOR := Color(0.09, 0.095, 0.108, 0.98)
const DETAIL_PANEL_BORDER_COLOR := Color(0.42, 0.44, 0.48, 1.0)
const DETAIL_TEXT_COLOR := Color(0.9, 0.92, 0.9, 1.0)
const DETAIL_MUTED_COLOR := Color(0.62, 0.65, 0.68, 1.0)
const DETAIL_BETTER_COLOR := Color(0.34, 0.92, 0.48, 1.0)
const DETAIL_WORSE_COLOR := Color(0.95, 0.32, 0.28, 1.0)
const DETAIL_EQUIPPED_COLOR := Color(0.42, 0.96, 0.56, 1.0)
const WORKSPACE_PANEL_COLOR := Color(0.055, 0.06, 0.068, 0.78)
const WORKSPACE_PANEL_BORDER_COLOR := Color(0.36, 0.39, 0.43, 0.92)
const WORKSPACE_MUTED_COLOR := Color(0.62, 0.66, 0.7, 1.0)
const CONTEXT_MENU_COLOR := Color(0.075, 0.08, 0.09, 0.98)
const CONTEXT_MENU_HOVER_COLOR := Color(0.18, 0.22, 0.25, 1.0)
const CONTEXT_BUTTON_COLOR := Color(0.105, 0.11, 0.125, 1.0)
const WEAPON_INSPECT_SIZE := Vector2(700, 650)
const WEAPON_INSPECT_GRAPHIC_COLOR := Color(0.12, 0.13, 0.145, 1.0)
const WEAPON_INSPECT_SLOT_COLOR := Color(0.095, 0.105, 0.12, 1.0)
const DRAG_SOURCE_NONE := &""
const DRAG_SOURCE_INVENTORY := &"inventory"
const DRAG_SOURCE_EQUIPMENT := &"equipment"
const DRAG_SOURCE_EXTERNAL := &"external"
const DRAG_SOURCE_SPLIT_INVENTORY := &"split_inventory"
const DRAG_SOURCE_SPLIT_EXTERNAL := &"split_external"
const DRAG_SOURCE_WEAPON_MAGAZINE := &"weapon_magazine"
const DRAG_SOURCE_WEAPON_CHAMBER := &"weapon_chamber"
const WEAPON_PART_MAGAZINE := &"magazine"
const WEAPON_PART_CHAMBER := &"chamber"
const FIREARM_SLOT_IDS := [&"firearm_1", &"firearm_2", &"firearm_3", &"firearm_4"]

@export var player_path: NodePath = NodePath("../Player")
@export var crosshair_path: NodePath = NodePath("../Crosshair")
@export var dropped_item_scene: PackedScene
@export var close_on_damage: bool = true
@export var normal_camera_position: Vector2 = Vector2(0, -22)
@export var normal_camera_zoom: Vector2 = Vector2(2.3, 2.3)
@export var inventory_camera_position: Vector2 = Vector2(92, -25)
@export var inventory_camera_zoom: Vector2 = Vector2(6.2, 6.2)
@export var camera_transition_time: float = 0.18
@export var inventory_panel_scale: Vector2 = Vector2(1.16, 1.16)
@export var screen_margin: float = 28.0
@export var screen_panel_gap: float = 14.0
@export var player_menu_panel_height: float = 166.0
@export var container_panel_height: float = 250.0

@onready var root: Control = $Root
@onready var shade: ColorRect = $Root/Shade
@onready var panel: Control = $Root/Panel
@onready var title_label: Label = $Root/Panel/Margin/Rows/Title
@onready var equipment_root: Container = $Root/Panel/Margin/Rows/EquipmentRoot
@onready var grid_root: Control = $Root/Panel/Margin/Rows/GridRoot
@onready var cells_root: Control = $Root/Panel/Margin/Rows/GridRoot/CellsRoot
@onready var items_root: Control = $Root/Panel/Margin/Rows/GridRoot/ItemsRoot
@onready var placement_root: Control = $Root/Panel/Margin/Rows/GridRoot/PlacementRoot
@onready var warning_label: Label = $Root/Panel/Margin/Rows/WarningLabel

var _player: Node2D
var _crosshair: CanvasItem
var _inventory: Node
var _equipment: Node
var _external_inventory: Node
var _external_container: Node
var _item_nodes: Dictionary = {}
var _external_item_nodes: Dictionary = {}
var _equipment_slot_nodes: Dictionary = {}
var _drag_source: StringName = DRAG_SOURCE_NONE
var _drag_entry_id: int = -1
var _drag_equipment_slot: StringName = &""
var _drag_item_id: StringName = &""
var _drag_item_size: Vector2i = Vector2i.ONE
var _drag_item_quantity: int = 1
var _drag_item_metadata: Dictionary = {}
var _drag_cell_offset: Vector2i = Vector2i.ZERO
var _drag_mouse_offset: Vector2 = Vector2.ZERO
var _drag_weapon_part_slot: StringName = &""
var _equipment_drag_node: Control
var _placement_markers: Array[ColorRect] = []
var _slot_preview: ColorRect
var _warning_tween: Tween
var _detail_panel: Control
var _selected_detail_panel: Panel
var _equipped_detail_panel: Panel
var _selected_detail_rows: VBoxContainer
var _equipped_detail_rows: VBoxContainer
var _detail_rows: VBoxContainer
var _hover_entry_id: int = -1
var _hover_equipment_slot: StringName = &""
var _is_open: bool = false
var _camera: Camera2D
var _camera_tween: Tween
var _damage_edge_flash: ColorRect
var _damage_flash_tween: Tween
var _gear_panel: Panel
var _external_panel: Panel
var _external_title_label: Label
var _external_grid_root: Control
var _external_cells_root: Control
var _external_placement_root: Control
var _external_items_root: Control
var _status_value_labels: Dictionary = {}
var _external_inventory_visible: bool = false
var _external_container_label: String = "CONTAINER"
var _crosshair_was_visible_before_inventory: bool = true
var _context_menu: Control
var _split_dialog: Control
var _split_dialog_inventory: Node
var _split_dialog_entry_id: int = -1
var _split_dialog_max_quantity: int = 1
var _split_dialog_quantity_input: LineEdit
var _weapon_inspect_window: Control
var _weapon_inspect_slot_nodes: Dictionary = {}
var _weapon_inspect_item_id: StringName = &""
var _weapon_inspect_weapon: Resource
var _weapon_inspect_equipment_slot: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	root.visible = false
	shade.color = Color(0.025, 0.025, 0.028, 0.42)
	_setup_background_blur()
	_setup_workspace_layout()
	_crosshair = get_node_or_null(crosshair_path) as CanvasItem

	var player := get_node_or_null(player_path)
	if player != null:
		_player = player as Node2D
		_inventory = player.get_node_or_null("Inventory")
		_equipment = player.get_node_or_null("Equipment")
		_camera = player.get_node_or_null("Camera2D") as Camera2D
		if player.has_signal("damage_feedback"):
			player.connect("damage_feedback", Callable(self, "_on_player_damage_feedback"))
		if player.has_signal("ammo_changed"):
			player.connect("ammo_changed", Callable(self, "_on_player_ammo_changed"))
		if player.has_signal("stamina_changed"):
			player.connect("stamina_changed", Callable(self, "_on_player_stamina_changed"))
		var health_node := player.get_node_or_null("Health")
		if health_node != null and health_node.has_signal("health_changed"):
			health_node.connect("health_changed", Callable(self, "_on_player_health_changed"))

	if _inventory != null:
		if _inventory.has_signal("grid_changed"):
			_inventory.grid_changed.connect(_refresh)
		_build_grid_cells()
		_refresh()

	if _equipment != null and _equipment.has_signal("equipment_changed"):
		_equipment.connect("equipment_changed", Callable(self, "_refresh_equipment"))
	_refresh_equipment()
	_ensure_damage_edge_flash()


func _setup_background_blur() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_radius = 5.0;
uniform vec4 tint_color : source_color = vec4(0.015, 0.016, 0.018, 0.58);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur_radius;
	vec4 color = texture(screen_texture, SCREEN_UV) * 0.22;
	color += texture(screen_texture, SCREEN_UV + vec2(px.x, 0.0)) * 0.12;
	color += texture(screen_texture, SCREEN_UV - vec2(px.x, 0.0)) * 0.12;
	color += texture(screen_texture, SCREEN_UV + vec2(0.0, px.y)) * 0.12;
	color += texture(screen_texture, SCREEN_UV - vec2(0.0, px.y)) * 0.12;
	color += texture(screen_texture, SCREEN_UV + px) * 0.075;
	color += texture(screen_texture, SCREEN_UV - px) * 0.075;
	color += texture(screen_texture, SCREEN_UV + vec2(px.x, -px.y)) * 0.075;
	color += texture(screen_texture, SCREEN_UV + vec2(-px.x, px.y)) * 0.075;
	COLOR = mix(color, tint_color, tint_color.a);
	COLOR.a = 1.0;
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material


func _setup_workspace_layout() -> void:
	title_label.text = "BACKPACK"
	title_label.add_theme_font_size_override("font_size", 18)
	panel.z_index = 8

	_gear_panel = _create_workspace_panel("GearPanel")
	root.add_child(_gear_panel)

	var gear_margin := _create_margin_container(16, 16, 16, 16)
	_gear_panel.add_child(gear_margin)
	var gear_rows := VBoxContainer.new()
	gear_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_rows.add_theme_constant_override("separation", 10)
	gear_margin.add_child(gear_rows)

	_add_section_title(gear_rows, "PLAYER")
	_move_equipment_root_to(gear_rows)
	gear_rows.add_child(_create_status_strip())

	_external_panel = _create_workspace_panel("ExternalInventoryPanel")
	root.add_child(_external_panel)
	var external_margin := _create_margin_container(16, 16, 16, 16)
	_external_panel.add_child(external_margin)
	var external_rows := VBoxContainer.new()
	external_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	external_rows.add_theme_constant_override("separation", 10)
	external_margin.add_child(external_rows)
	_external_title_label = _add_section_title(external_rows, "CONTAINER")
	external_rows.add_child(_create_external_grid_view())


func _create_workspace_panel(panel_name: String) -> Panel:
	var workspace_panel := Panel.new()
	workspace_panel.name = panel_name
	workspace_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	workspace_panel.z_index = 8
	workspace_panel.add_theme_stylebox_override("panel", _make_flat_style(
		WORKSPACE_PANEL_COLOR,
		WORKSPACE_PANEL_BORDER_COLOR,
		2
	))
	return workspace_panel


func _create_margin_container(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _add_section_title(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.modulate = DETAIL_TEXT_COLOR
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label


func _move_equipment_root_to(parent: Node) -> void:
	if equipment_root.get_parent() != null:
		equipment_root.get_parent().remove_child(equipment_root)
	parent.add_child(equipment_root)
	equipment_root.custom_minimum_size = Vector2(0, 56)
	if equipment_root is GridContainer:
		var grid := equipment_root as GridContainer
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)


func _create_status_strip() -> GridContainer:
	var status_grid := GridContainer.new()
	status_grid.name = "StatusGrid"
	status_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_grid.columns = 3
	status_grid.add_theme_constant_override("h_separation", 8)
	status_grid.add_theme_constant_override("v_separation", 8)
	_status_value_labels.clear()
	_add_status_card(status_grid, &"health", "HP", "-- / --")
	_add_status_card(status_grid, &"stamina", "STAMINA", "-- / --")
	_add_status_card(status_grid, &"ammo", "AMMO", "-- / --")
	return status_grid


func _add_status_card(parent: Node, key: StringName, title: String, value: String) -> void:
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(190, 42)
	card.add_theme_stylebox_override("panel", _make_flat_style(
		Color(0.07, 0.075, 0.085, 0.88),
		WORKSPACE_PANEL_BORDER_COLOR,
		1
	))
	parent.add_child(card)

	var margin := _create_margin_container(10, 7, 10, 7)
	card.add_child(margin)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 2)
	margin.add_child(rows)

	var title_label_node := Label.new()
	title_label_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label_node.text = title
	title_label_node.modulate = WORKSPACE_MUTED_COLOR
	title_label_node.add_theme_font_size_override("font_size", 9)
	rows.add_child(title_label_node)

	var value_label := Label.new()
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.text = value
	value_label.modulate = DETAIL_TEXT_COLOR
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.clip_text = true
	rows.add_child(value_label)
	_status_value_labels[key] = value_label


func _create_external_grid_view() -> Control:
	var holder := Control.new()
	holder.name = "ExternalGridRoot"
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.custom_minimum_size = Vector2(0, 174)
	_external_grid_root = holder

	_external_cells_root = Control.new()
	_external_cells_root.name = "ExternalCellsRoot"
	_external_cells_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_external_cells_root)

	_external_placement_root = Control.new()
	_external_placement_root.name = "ExternalPlacementRoot"
	_external_placement_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_external_placement_root)

	_external_items_root = Control.new()
	_external_items_root.name = "ExternalItemsRoot"
	_external_items_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_external_items_root)

	return holder


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		set_inventory_open(not _is_open)
		get_viewport().set_input_as_handled()
		return

	if not _is_open:
		return

	if _is_close_event(event):
		set_inventory_open(false)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			if _is_context_popup_visible() and not _is_mouse_inside_context_popup():
				_hide_context_menu()
				_hide_split_dialog()

	if _is_dragging():
		if event.is_action_pressed("reload"):
			_rotate_dragged_item()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion:
			_update_drag_visual()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var mouse_button := event as InputEventMouseButton
			if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
				_finish_drag()
				get_viewport().set_input_as_handled()


func set_inventory_open(is_open: bool) -> void:
	if _is_open == is_open:
		return

	_is_open = is_open
	root.visible = is_open
	get_tree().paused = false
	_set_crosshair_hidden_for_inventory(is_open)
	if _player != null and _player.has_method("set_inventory_open"):
		_player.call("set_inventory_open", is_open)

	if is_open:
		_layout_realtime_inventory()
		_set_inventory_camera(true)
		_refresh()
		_refresh_status_panel()
	else:
		_cancel_drag()
		_hide_detail_panel()
		_hide_context_menu()
		_hide_split_dialog()
		_hide_weapon_inspect_window()
		_clear_external_container()
		_set_inventory_camera(false)


func is_inventory_open() -> bool:
	return _is_open


func open_external_inventory(container: Node = null) -> void:
	_set_external_container(container)
	_external_inventory_visible = true
	if not _is_open:
		set_inventory_open(true)
	else:
		_layout_realtime_inventory()
		_refresh_external_inventory()


func close_external_inventory() -> void:
	_clear_external_container()
	if _is_open:
		_layout_realtime_inventory()


func set_external_inventory_visible(is_visible: bool) -> void:
	if is_visible:
		open_external_inventory()
	else:
		close_external_inventory()


func _set_external_container(container: Node) -> void:
	_disconnect_external_inventory()
	_external_container = container
	_external_inventory = _resolve_external_inventory(container)
	_external_container_label = _resolve_external_container_label(container)
	if _external_title_label != null:
		_external_title_label.text = _external_container_label

	if _external_inventory != null and _external_inventory.has_signal("grid_changed"):
		var refresh_callable := Callable(self, "_refresh_external_inventory")
		if not _external_inventory.grid_changed.is_connected(refresh_callable):
			_external_inventory.grid_changed.connect(refresh_callable)

	_build_external_grid_cells()
	_refresh_external_inventory()


func _clear_external_container() -> void:
	_disconnect_external_inventory()
	_external_inventory_visible = false
	_external_inventory = null
	_external_container = null
	_external_container_label = "CONTAINER"
	if _external_title_label != null:
		_external_title_label.text = _external_container_label
	_clear_children(_external_items_root)
	_external_item_nodes.clear()
	_clear_children(_external_cells_root)
	_clear_children(_external_placement_root)


func _disconnect_external_inventory() -> void:
	if _external_inventory == null or not _external_inventory.has_signal("grid_changed"):
		return

	var refresh_callable := Callable(self, "_refresh_external_inventory")
	if _external_inventory.grid_changed.is_connected(refresh_callable):
		_external_inventory.grid_changed.disconnect(refresh_callable)


func _resolve_external_inventory(container: Node) -> Node:
	if container == null:
		return null

	if container.has_method("get_inventory"):
		return container.call("get_inventory") as Node

	var inventory_node := container.get_node_or_null("Inventory")
	if inventory_node != null:
		return inventory_node

	if container.has_method("get_entries") and container.has_method("get_grid_size"):
		return container

	return null


func _resolve_external_container_label(container: Node) -> String:
	if container == null:
		return "CONTAINER"

	if container.has_method("get_container_label"):
		return str(container.call("get_container_label"))

	var label_value: Variant = container.get("container_label")
	if label_value != null:
		return str(label_value)

	return "CONTAINER"


func _process(_delta: float) -> void:
	if _is_open:
		_layout_realtime_inventory()
		_refresh_status_panel()


func _is_close_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true

	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE

	return false


func _set_crosshair_hidden_for_inventory(is_inventory_open: bool) -> void:
	if _crosshair == null:
		return

	if is_inventory_open:
		_crosshair_was_visible_before_inventory = _crosshair.visible
		_crosshair.visible = false
	else:
		_crosshair.visible = _crosshair_was_visible_before_inventory


func _layout_realtime_inventory() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var has_external_inventory := _external_inventory_visible

	panel.scale = inventory_panel_scale
	panel.size = panel.get_combined_minimum_size()
	var panel_size := panel.size
	var scaled_panel_size := panel_size * panel.scale
	var menu_width := scaled_panel_size.x
	var top_panel_height := container_panel_height if has_external_inventory else player_menu_panel_height
	var total_height := top_panel_height + screen_panel_gap + scaled_panel_size.y
	var menu_x := (viewport_size.x - menu_width) * 0.5
	var menu_y := (viewport_size.y - total_height) * 0.5
	menu_x = maxf(menu_x, screen_margin)
	menu_y = maxf(menu_y, screen_margin)

	if is_instance_valid(_gear_panel):
		_gear_panel.visible = not has_external_inventory
		_gear_panel.position = Vector2(menu_x, menu_y)
		_gear_panel.size = Vector2(menu_width, player_menu_panel_height)

	if is_instance_valid(_external_panel):
		_external_panel.visible = has_external_inventory
		_external_panel.position = Vector2(menu_x, menu_y)
		_external_panel.size = Vector2(menu_width, container_panel_height)

	panel.position = Vector2(menu_x, menu_y + top_panel_height + screen_panel_gap)


func _refresh_status_panel() -> void:
	if _player == null or _status_value_labels.is_empty():
		return

	var health_node := _player.get_node_or_null("Health")
	if health_node != null:
		_on_player_health_changed(
			int(health_node.get("current_health")),
			int(health_node.get("max_health"))
		)

	_on_player_stamina_changed(
		float(_player.get("current_stamina")),
		float(_player.get("max_stamina")),
		bool(_player.get("is_stamina_overheated")),
		true
	)
	_on_player_ammo_changed(
		int(_player.get("current_ammo")),
		int(_player.get("reserve_ammo"))
	)


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	var label := _status_value_labels.get(&"health") as Label
	if label == null:
		return

	label.text = "%d / %d" % [current_health, max_health]


func _on_player_stamina_changed(
	current_stamina: float,
	maximum_stamina: float,
	overheated: bool,
	_melee_available: bool
) -> void:
	var label := _status_value_labels.get(&"stamina") as Label
	if label == null:
		return

	label.text = "%d / %d" % [roundi(current_stamina), roundi(maximum_stamina)]
	label.modulate = Color(0.58, 0.58, 0.58, 1.0) if overheated else DETAIL_TEXT_COLOR


func _on_player_ammo_changed(current_ammo: int, reserve_ammo: int) -> void:
	var label := _status_value_labels.get(&"ammo") as Label
	if label == null:
		return

	label.text = "%d / %d" % [current_ammo, reserve_ammo]


func _set_inventory_camera(is_open: bool) -> void:
	if _camera == null:
		return

	if _camera_tween != null:
		_camera_tween.kill()

	var target_position := inventory_camera_position if is_open else normal_camera_position
	var target_zoom := inventory_camera_zoom if is_open else normal_camera_zoom
	_camera_tween = create_tween()
	_camera_tween.tween_property(_camera, "position", target_position, camera_transition_time)
	_camera_tween.parallel().tween_property(_camera, "zoom", target_zoom, camera_transition_time)


func _build_grid_cells() -> void:
	_clear_children(cells_root)

	var grid_size: Vector2i = _inventory.get_grid_size()
	grid_root.custom_minimum_size = Vector2(
		grid_size.x * CELL_PITCH - CELL_GAP,
		grid_size.y * CELL_PITCH - CELL_GAP
	)
	grid_root.size = grid_root.custom_minimum_size
	cells_root.size = grid_root.custom_minimum_size
	placement_root.size = grid_root.custom_minimum_size
	items_root.size = grid_root.custom_minimum_size

	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Panel.new()
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.position = Vector2(x * CELL_PITCH, y * CELL_PITCH)
			cell.size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.add_theme_stylebox_override("panel", _make_flat_style(CELL_COLOR, CELL_BORDER_COLOR, 1))
			cells_root.add_child(cell)


func _build_external_grid_cells() -> void:
	if _external_grid_root == null:
		return

	_clear_children(_external_cells_root)

	var grid_size := Vector2i(10, 3)
	if _external_inventory != null and _external_inventory.has_method("get_grid_size"):
		grid_size = _external_inventory.get_grid_size()

	var grid_pixel_size := Vector2(
		grid_size.x * CELL_PITCH - CELL_GAP,
		grid_size.y * CELL_PITCH - CELL_GAP
	)
	_external_grid_root.custom_minimum_size = grid_pixel_size
	_external_grid_root.size = grid_pixel_size
	_external_cells_root.size = grid_pixel_size
	_external_placement_root.size = grid_pixel_size
	_external_items_root.size = grid_pixel_size

	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Panel.new()
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.position = _grid_to_local(Vector2i(x, y))
			cell.size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.add_theme_stylebox_override("panel", _make_flat_style(CELL_COLOR, CELL_BORDER_COLOR, 1))
			_external_cells_root.add_child(cell)


func _refresh() -> void:
	if _inventory == null:
		return

	_refresh_equipment()
	_clear_children(items_root)
	_item_nodes.clear()

	for entry in _inventory.get_entries():
		var entry_id: int = int(entry.get("entry_id", -1))
		if entry_id < 0 or (_drag_source == DRAG_SOURCE_INVENTORY and entry_id == _drag_entry_id):
			continue

		_add_item_node(entry)

	if _drag_source == DRAG_SOURCE_INVENTORY and _drag_entry_id >= 0:
		var dragged_entry: Dictionary = _inventory.get_entry(_drag_entry_id)
		if not dragged_entry.is_empty():
			_add_item_node(dragged_entry, true)
			_update_drag_visual()

	if _external_inventory_visible:
		_refresh_external_inventory()


func _add_item_node(entry: Dictionary, is_dragged: bool = false) -> void:
	var entry_id: int = int(entry.get("entry_id", -1))
	var item_id: StringName = entry.get("item_id", &"")
	var position: Vector2i = entry.get("position", Vector2i.ZERO)
	var size: Vector2i = entry.get("size", Vector2i.ONE)
	var quantity: int = int(entry.get("quantity", 1))
	var metadata: Dictionary = entry.get("metadata", {})
	var definition: Dictionary = _inventory.get_item_definition(item_id)
	var display_size := _drag_item_size if is_dragged else size

	var item_panel := _create_item_panel(definition, quantity, display_size, is_dragged, metadata)
	item_panel.position = _grid_to_local(position)
	item_panel.z_index = 20 if is_dragged else 5
	item_panel.gui_input.connect(_on_item_gui_input.bind(entry_id))
	if not is_dragged:
		item_panel.mouse_entered.connect(_show_entry_details.bind(entry_id))
		item_panel.mouse_exited.connect(_hide_detail_panel)

	items_root.add_child(item_panel)
	_item_nodes[entry_id] = item_panel


func _refresh_external_inventory() -> void:
	if _external_items_root == null:
		return

	_clear_children(_external_items_root)
	_external_item_nodes.clear()
	if _external_inventory == null:
		return

	for entry in _external_inventory.get_entries():
		var entry_id: int = int(entry.get("entry_id", -1))
		if entry_id < 0 or (_drag_source == DRAG_SOURCE_EXTERNAL and entry_id == _drag_entry_id):
			continue

		_add_external_item_node(entry)

	if _drag_source == DRAG_SOURCE_EXTERNAL and _drag_entry_id >= 0:
		var dragged_entry: Dictionary = _external_inventory.get_entry(_drag_entry_id)
		if not dragged_entry.is_empty():
			_add_external_item_node(dragged_entry, true)
			_update_drag_visual()


func _add_external_item_node(entry: Dictionary, is_dragged: bool = false) -> void:
	var entry_id: int = int(entry.get("entry_id", -1))
	var item_id: StringName = entry.get("item_id", &"")
	var position: Vector2i = entry.get("position", Vector2i.ZERO)
	var size: Vector2i = entry.get("size", Vector2i.ONE)
	var quantity: int = int(entry.get("quantity", 1))
	var metadata: Dictionary = entry.get("metadata", {})
	var definition: Dictionary = _get_item_definition_for_inventory(_external_inventory, item_id)
	var display_size := _drag_item_size if is_dragged else size

	var item_panel := _create_item_panel(definition, quantity, display_size, is_dragged, metadata)
	item_panel.position = _grid_to_local(position)
	item_panel.z_index = 20 if is_dragged else 5
	item_panel.gui_input.connect(_on_external_item_gui_input.bind(entry_id))
	if not is_dragged:
		item_panel.mouse_entered.connect(_show_external_entry_details.bind(entry_id))
		item_panel.mouse_exited.connect(_hide_detail_panel)

	_external_items_root.add_child(item_panel)
	_external_item_nodes[entry_id] = item_panel


func _create_item_panel(
	definition: Dictionary,
	quantity: int,
	size: Vector2i,
	is_dragged: bool = false,
	metadata: Dictionary = {}
) -> Panel:
	var item_panel := Panel.new()
	item_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	item_panel.size = _entry_pixel_size(size)
	item_panel.custom_minimum_size = Vector2.ZERO
	item_panel.clip_contents = true
	item_panel.modulate.a = 0.62 if is_dragged else 1.0
	item_panel.add_theme_stylebox_override("panel", _make_flat_style(
		definition.get("color", Color(0.44, 0.44, 0.46, 1.0)),
		ITEM_BORDER_COLOR,
		2
	))

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 2.0
	label.offset_top = 2.0
	label.offset_right = -2.0
	label.offset_bottom = -2.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = _get_item_label(definition, quantity, size, metadata)
	label.add_theme_font_size_override("font_size", 9)
	item_panel.add_child(label)

	return item_panel


func _on_item_gui_input(event: InputEvent, entry_id: int) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			if not mouse_button.ctrl_pressed or not _begin_split_drag(
				_inventory,
				entry_id,
				_item_nodes.get(entry_id) as Control,
				DRAG_SOURCE_SPLIT_INVENTORY
			):
				_begin_drag(entry_id)
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			if mouse_button.ctrl_pressed:
				_try_split_stack_entry(_inventory, entry_id)
			elif mouse_button.shift_pressed:
				_quick_transfer_entry_between_inventories(_inventory, _external_inventory, entry_id)
			else:
				_show_item_context_menu(_inventory, entry_id, DRAG_SOURCE_INVENTORY)
			get_viewport().set_input_as_handled()


func _on_external_item_gui_input(event: InputEvent, entry_id: int) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			if not mouse_button.ctrl_pressed or not _begin_split_drag(
				_external_inventory,
				entry_id,
				_external_item_nodes.get(entry_id) as Control,
				DRAG_SOURCE_SPLIT_EXTERNAL
			):
				_begin_external_drag(entry_id)
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			if mouse_button.ctrl_pressed:
				_try_split_stack_entry(_external_inventory, entry_id)
			elif mouse_button.shift_pressed:
				_quick_transfer_entry_between_inventories(_external_inventory, _inventory, entry_id)
			else:
				_show_item_context_menu(_external_inventory, entry_id, DRAG_SOURCE_EXTERNAL)
			get_viewport().set_input_as_handled()


func _begin_drag(entry_id: int) -> void:
	if _inventory == null or not _item_nodes.has(entry_id):
		return

	_hide_detail_panel()
	_hide_context_menu()
	_hide_split_dialog()
	_drag_source = DRAG_SOURCE_INVENTORY
	_drag_entry_id = entry_id
	_drag_equipment_slot = &""
	var item_node := _item_nodes[entry_id] as Control
	var entry: Dictionary = _inventory.get_entry(entry_id)
	var entry_size: Vector2i = entry.get("size", Vector2i.ONE)
	_drag_item_id = entry.get("item_id", &"")
	_drag_item_size = entry_size
	_drag_item_quantity = int(entry.get("quantity", 1))
	_drag_item_metadata = entry.get("metadata", {})
	var local_mouse_position: Vector2 = item_node.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
	_drag_mouse_offset = get_viewport().get_mouse_position() - item_node.global_position
	_drag_cell_offset = Vector2i(
		clampi(floori(local_mouse_position.x / CELL_PITCH), 0, entry_size.x - 1),
		clampi(floori(local_mouse_position.y / CELL_PITCH), 0, entry_size.y - 1)
	)
	_refresh()


func _begin_external_drag(entry_id: int) -> void:
	if _external_inventory == null or not _external_item_nodes.has(entry_id):
		return

	_hide_detail_panel()
	_hide_context_menu()
	_hide_split_dialog()
	_drag_source = DRAG_SOURCE_EXTERNAL
	_drag_entry_id = entry_id
	_drag_equipment_slot = &""
	var item_node := _external_item_nodes[entry_id] as Control
	var entry: Dictionary = _external_inventory.get_entry(entry_id)
	var entry_size: Vector2i = entry.get("size", Vector2i.ONE)
	_drag_item_id = entry.get("item_id", &"")
	_drag_item_size = entry_size
	_drag_item_quantity = int(entry.get("quantity", 1))
	_drag_item_metadata = entry.get("metadata", {})
	var local_mouse_position: Vector2 = item_node.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
	_drag_mouse_offset = get_viewport().get_mouse_position() - item_node.global_position
	_drag_cell_offset = Vector2i(
		clampi(floori(local_mouse_position.x / CELL_PITCH), 0, entry_size.x - 1),
		clampi(floori(local_mouse_position.y / CELL_PITCH), 0, entry_size.y - 1)
	)
	_refresh_external_inventory()


func _begin_split_drag(
	source_inventory: Node,
	entry_id: int,
	item_node: Control,
	split_drag_source: StringName
) -> bool:
	if source_inventory == null or item_node == null:
		return false
	if not _can_split_stack_entry(source_inventory, entry_id):
		return false

	var entry: Dictionary = source_inventory.get_entry(entry_id)
	if entry.is_empty():
		return false

	var item_id: StringName = entry.get("item_id", &"")
	var entry_size: Vector2i = entry.get("size", Vector2i.ONE)
	var quantity: int = int(entry.get("quantity", 1))
	var split_quantity := clampi(floori(float(quantity) * 0.5), 1, quantity - 1)
	var definition: Dictionary = _get_item_definition_for_inventory(source_inventory, item_id)
	var local_mouse_position: Vector2 = item_node.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()

	_hide_detail_panel()
	_hide_context_menu()
	_hide_split_dialog()
	_drag_source = split_drag_source
	_drag_entry_id = entry_id
	_drag_equipment_slot = &""
	_drag_item_id = item_id
	_drag_item_size = entry_size
	_drag_item_quantity = split_quantity
	_drag_item_metadata = {}
	_drag_mouse_offset = get_viewport().get_mouse_position() - item_node.global_position
	_drag_cell_offset = Vector2i(
		clampi(floori(local_mouse_position.x / CELL_PITCH), 0, entry_size.x - 1),
		clampi(floori(local_mouse_position.y / CELL_PITCH), 0, entry_size.y - 1)
	)

	_equipment_drag_node = _create_item_panel(definition, split_quantity, entry_size, true)
	_equipment_drag_node.z_index = 30
	_equipment_drag_node.global_position = item_node.global_position
	root.add_child(_equipment_drag_node)

	var removed_quantity: int = source_inventory.remove_quantity_from_entry(entry_id, split_quantity)
	if removed_quantity != split_quantity:
		_drag_item_quantity = 0
		_cancel_drag()
		return false

	_update_drag_visual()
	return true


func _update_drag_visual() -> void:
	if not _is_dragging():
		return

	var item_node := _get_drag_node()
	if item_node == null:
		return

	var target_cell: Vector2i = _get_drag_target_cell()
	var entry_size: Vector2i = _get_drag_item_size()

	item_node.global_position = get_viewport().get_mouse_position() - _drag_mouse_offset
	_update_placement_markers(target_cell, entry_size)
	_update_slot_preview()


func _finish_drag() -> void:
	if not _is_dragging() or _inventory == null:
		_cancel_drag()
		return

	var target_cell := _get_drag_target_cell()
	var external_target_cell := _get_external_drag_target_cell()
	var target_slot: StringName = _get_equipment_slot_under_mouse()
	var target_weapon_part_slot: StringName = _get_weapon_part_slot_under_mouse()

	if _drag_source == DRAG_SOURCE_INVENTORY:
		if target_weapon_part_slot != &"":
			_drop_inventory_entry_to_weapon_part(_inventory, _drag_entry_id, target_weapon_part_slot)
		elif target_slot != &"":
			_equip_inventory_entry_to_slot(_drag_entry_id, target_slot)
		elif _is_mouse_inside_grid():
			if not _try_stack_entry_at_cell(_inventory, _inventory, _drag_entry_id, target_cell, _drag_item_size):
				_inventory.move_entry(_drag_entry_id, target_cell, _drag_item_size)
		elif _is_mouse_inside_external_grid() and _external_inventory != null:
			_transfer_entry_between_inventories(
				_inventory,
				_external_inventory,
				_drag_entry_id,
				external_target_cell,
				_drag_item_size
			)
		elif not _is_mouse_inside_any_inventory_frame():
			_drop_dragged_inventory_entry_to_world()
	elif _drag_source == DRAG_SOURCE_EXTERNAL:
		if target_weapon_part_slot != &"":
			_drop_inventory_entry_to_weapon_part(_external_inventory, _drag_entry_id, target_weapon_part_slot)
		elif _is_mouse_inside_grid():
			_transfer_entry_between_inventories(
				_external_inventory,
				_inventory,
				_drag_entry_id,
				target_cell,
				_drag_item_size
			)
		elif _is_mouse_inside_external_grid() and _external_inventory != null:
			if not _try_stack_entry_at_cell(_external_inventory, _external_inventory, _drag_entry_id, external_target_cell, _drag_item_size):
				_external_inventory.move_entry(_drag_entry_id, external_target_cell, _drag_item_size)
		elif not _is_mouse_inside_any_inventory_frame():
			_drop_dragged_external_entry_to_world()
	elif _is_split_drag_source():
		_finish_split_drag(target_cell, external_target_cell)
	elif _drag_source == DRAG_SOURCE_EQUIPMENT:
		if target_slot != &"":
			_move_equipped_slot_to_slot(_drag_equipment_slot, target_slot)
		elif _is_mouse_inside_grid():
			_store_equipped_slot_at(_drag_equipment_slot, target_cell, _drag_item_size)
		elif not _is_mouse_inside_any_inventory_frame():
			_drop_equipped_slot_to_world(_drag_equipment_slot)
	elif _is_weapon_part_drag_source():
		_finish_weapon_part_drag(target_cell, external_target_cell)
	_cancel_drag()
	_refresh()
	_refresh_external_inventory()


func _cancel_drag() -> void:
	if _is_split_drag_source() and _drag_item_quantity > 0:
		_return_split_drag_to_source()

	if is_instance_valid(_equipment_drag_node):
		_equipment_drag_node.queue_free()

	_drag_source = DRAG_SOURCE_NONE
	_drag_entry_id = -1
	_drag_equipment_slot = &""
	_drag_item_id = &""
	_drag_item_size = Vector2i.ONE
	_drag_item_quantity = 1
	_drag_item_metadata = {}
	_drag_cell_offset = Vector2i.ZERO
	_drag_mouse_offset = Vector2.ZERO
	_drag_weapon_part_slot = &""
	_equipment_drag_node = null
	_clear_placement_markers()
	_clear_slot_preview()
	_refresh_equipment()


func _is_dragging() -> bool:
	return _drag_source != DRAG_SOURCE_NONE


func _get_drag_node() -> Control:
	if _drag_source == DRAG_SOURCE_INVENTORY and _item_nodes.has(_drag_entry_id):
		return _item_nodes[_drag_entry_id] as Control
	if _drag_source == DRAG_SOURCE_EXTERNAL and _external_item_nodes.has(_drag_entry_id):
		return _external_item_nodes[_drag_entry_id] as Control
	if _is_split_drag_source() and is_instance_valid(_equipment_drag_node):
		return _equipment_drag_node
	if _drag_source == DRAG_SOURCE_EQUIPMENT and is_instance_valid(_equipment_drag_node):
		return _equipment_drag_node
	if _is_weapon_part_drag_source() and is_instance_valid(_equipment_drag_node):
		return _equipment_drag_node

	return null


func _get_drag_item_size() -> Vector2i:
	return _drag_item_size


func _rotate_dragged_item() -> void:
	if not _is_dragging() or _drag_item_size.x == _drag_item_size.y:
		return

	var old_pixel_size := _entry_pixel_size(_drag_item_size)
	var old_mouse_offset := _drag_mouse_offset
	_drag_item_size = Vector2i(_drag_item_size.y, _drag_item_size.x)

	var new_pixel_size := _entry_pixel_size(_drag_item_size)
	_drag_mouse_offset = Vector2(
		_get_scaled_drag_offset(old_mouse_offset.x, old_pixel_size.x, new_pixel_size.x),
		_get_scaled_drag_offset(old_mouse_offset.y, old_pixel_size.y, new_pixel_size.y)
	)
	_drag_cell_offset = Vector2i(
		clampi(floori(_drag_mouse_offset.x / CELL_PITCH), 0, _drag_item_size.x - 1),
		clampi(floori(_drag_mouse_offset.y / CELL_PITCH), 0, _drag_item_size.y - 1)
	)

	_refresh_drag_item_node()
	_update_drag_visual()


func _get_scaled_drag_offset(offset: float, old_size: float, new_size: float) -> float:
	if old_size <= 0.0:
		return 0.0

	return clampf((offset / old_size) * new_size, 0.0, new_size)


func _refresh_drag_item_node() -> void:
	var item_node := _get_drag_node()
	if item_node == null:
		return

	var definition: Dictionary = _get_item_definition_for_inventory(_get_drag_inventory(), _drag_item_id)
	item_node.size = _entry_pixel_size(_drag_item_size)
	for child in item_node.get_children():
		if child is Label:
			var label := child as Label
			label.text = _get_item_label(definition, _drag_item_quantity, _drag_item_size, _drag_item_metadata)
			break


func _grid_to_local(grid_position: Vector2i) -> Vector2:
	return Vector2(grid_position.x * CELL_PITCH, grid_position.y * CELL_PITCH)


func _global_to_grid(global_position: Vector2) -> Vector2i:
	var local_position: Vector2 = grid_root.get_global_transform().affine_inverse() * global_position
	return Vector2i(floori(local_position.x / CELL_PITCH), floori(local_position.y / CELL_PITCH))


func _global_to_external_grid(global_position: Vector2) -> Vector2i:
	if _external_grid_root == null:
		return Vector2i(-1, -1)

	var local_position: Vector2 = _external_grid_root.get_global_transform().affine_inverse() * global_position
	return Vector2i(floori(local_position.x / CELL_PITCH), floori(local_position.y / CELL_PITCH))


func _get_drag_target_cell() -> Vector2i:
	return _global_to_grid(get_viewport().get_mouse_position()) - _drag_cell_offset


func _get_external_drag_target_cell() -> Vector2i:
	return _global_to_external_grid(get_viewport().get_mouse_position()) - _drag_cell_offset


func _is_mouse_inside_grid() -> bool:
	var local_position: Vector2 = grid_root.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
	var grid_size: Vector2 = grid_root.custom_minimum_size
	return Rect2(Vector2.ZERO, grid_size).has_point(local_position)


func _is_mouse_inside_external_grid() -> bool:
	if not _external_inventory_visible or _external_grid_root == null:
		return false

	var local_position: Vector2 = _external_grid_root.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
	var grid_size: Vector2 = _external_grid_root.custom_minimum_size
	return Rect2(Vector2.ZERO, grid_size).has_point(local_position)


func _is_mouse_inside_inventory_frame() -> bool:
	var local_position: Vector2 = panel.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
	return Rect2(Vector2.ZERO, panel.size).has_point(local_position)


func _is_mouse_inside_any_inventory_frame() -> bool:
	if _is_mouse_inside_inventory_frame():
		return true

	if is_instance_valid(_gear_panel) and _gear_panel.is_visible_in_tree():
		var gear_position: Vector2 = _gear_panel.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
		if Rect2(Vector2.ZERO, _gear_panel.size).has_point(gear_position):
			return true

	if is_instance_valid(_external_panel) and _external_panel.is_visible_in_tree():
		var external_position: Vector2 = _external_panel.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
		if Rect2(Vector2.ZERO, _external_panel.size).has_point(external_position):
			return true

	if _is_mouse_inside_weapon_inspect_window():
		return true

	return false


func _get_equipment_slot_under_mouse() -> StringName:
	var mouse_position := get_viewport().get_mouse_position()
	for slot in _equipment_slot_nodes:
		var slot_node := _equipment_slot_nodes[slot] as Control
		if slot_node == null or not slot_node.is_visible_in_tree():
			continue

		var local_position: Vector2 = slot_node.get_global_transform().affine_inverse() * mouse_position
		if Rect2(Vector2.ZERO, slot_node.size).has_point(local_position):
			return slot

	return &""


func _get_weapon_part_slot_under_mouse() -> StringName:
	var mouse_position := get_viewport().get_mouse_position()
	for slot_id in _weapon_inspect_slot_nodes:
		var slot_node := _weapon_inspect_slot_nodes[slot_id] as Control
		if slot_node == null or not slot_node.is_visible_in_tree():
			continue

		var local_position: Vector2 = slot_node.get_global_transform().affine_inverse() * mouse_position
		if Rect2(Vector2.ZERO, slot_node.size).has_point(local_position):
			return StringName(slot_id)

	return &""


func _is_mouse_inside_weapon_inspect_window() -> bool:
	if not is_instance_valid(_weapon_inspect_window) or not _weapon_inspect_window.is_visible_in_tree():
		return false

	var local_position: Vector2 = _weapon_inspect_window.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
	return Rect2(Vector2.ZERO, _weapon_inspect_window.size).has_point(local_position)


func _update_placement_markers(target_cell: Vector2i, entry_size: Vector2i) -> void:
	_clear_placement_markers()

	var target_inventory := _inventory
	var target_root := placement_root
	var ignored_entry_id: int = _drag_entry_id if _drag_source == DRAG_SOURCE_INVENTORY else -1
	if _is_mouse_inside_external_grid():
		target_cell = _get_external_drag_target_cell()
		target_inventory = _external_inventory
		target_root = _external_placement_root
		ignored_entry_id = _drag_entry_id if _drag_source == DRAG_SOURCE_EXTERNAL else -1
	elif not _is_mouse_inside_grid():
		return

	if target_inventory == null or target_root == null:
		return

	var can_stack_at_target := _can_stack_dragged_entry_at_cell(
		target_inventory,
		target_cell,
		entry_size,
		ignored_entry_id
	)
	for y in entry_size.y:
		for x in entry_size.x:
			var cell := target_cell + Vector2i(x, y)
			var marker := ColorRect.new()
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marker.position = _grid_to_local(cell)
			marker.size = Vector2(CELL_SIZE, CELL_SIZE)
			marker.color = PLACEABLE_COLOR if can_stack_at_target or target_inventory.is_cell_free(cell, ignored_entry_id) else BLOCKED_COLOR
			target_root.add_child(marker)
			_placement_markers.append(marker)


func _clear_placement_markers() -> void:
	for marker in _placement_markers:
		if is_instance_valid(marker):
			if marker.get_parent() != null:
				marker.get_parent().remove_child(marker)
			marker.queue_free()
	_placement_markers.clear()


func _update_slot_preview() -> void:
	_clear_slot_preview()

	var slot: StringName = _get_equipment_slot_under_mouse()
	if slot == &"":
		return

	var slot_node := _equipment_slot_nodes.get(slot) as Control
	if slot_node == null:
		return

	var slot_accepts_item := _does_slot_accept_item(slot, _drag_item_id)
	_slot_preview = ColorRect.new()
	_slot_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_preview.color = SLOT_PLACEABLE_COLOR if slot_accepts_item else SLOT_BLOCKED_COLOR
	_slot_preview.global_position = slot_node.global_position
	_slot_preview.size = slot_node.size
	_slot_preview.z_index = 12
	root.add_child(_slot_preview)


func _clear_slot_preview() -> void:
	if is_instance_valid(_slot_preview):
		_slot_preview.queue_free()
	_slot_preview = null


func _drop_dragged_inventory_entry_to_world() -> bool:
	if dropped_item_scene == null or _player == null:
		return false

	var dropped_entry: Dictionary = _inventory.remove_entry(_drag_entry_id)
	if dropped_entry.is_empty():
		return false

	return _drop_item_to_world(
		dropped_entry.get("item_id", &""),
		int(dropped_entry.get("quantity", 1)),
		dropped_entry.get("metadata", {})
	)


func _drop_dragged_external_entry_to_world() -> bool:
	if dropped_item_scene == null or _player == null or _external_inventory == null:
		return false

	var dropped_entry: Dictionary = _external_inventory.remove_entry(_drag_entry_id)
	if dropped_entry.is_empty():
		return false

	return _drop_item_to_world(
		dropped_entry.get("item_id", &""),
		int(dropped_entry.get("quantity", 1)),
		dropped_entry.get("metadata", {})
	)


func _finish_split_drag(target_cell: Vector2i, external_target_cell: Vector2i) -> bool:
	if _drag_item_id == &"" or _drag_item_quantity <= 0:
		return false

	var did_place := false
	if _is_mouse_inside_grid():
		did_place = _place_split_drag_in_inventory(_inventory, target_cell)
	elif _is_mouse_inside_external_grid() and _external_inventory != null:
		did_place = _place_split_drag_in_inventory(_external_inventory, external_target_cell)
	elif not _is_mouse_inside_any_inventory_frame():
		if _drop_item_to_world(_drag_item_id, _drag_item_quantity):
			_drag_item_quantity = 0
			did_place = true

	if not did_place:
		_show_warning("NO SPACE")

	return did_place


func _place_split_drag_in_inventory(target_inventory: Node, target_cell: Vector2i) -> bool:
	if target_inventory == null or _drag_item_quantity <= 0:
		return false

	var target_stack_id: int = -1
	if target_inventory.has_method("get_stack_target_entry_id"):
		target_stack_id = int(target_inventory.call(
			"get_stack_target_entry_id",
			_drag_item_id,
			target_cell,
			_drag_item_size,
			-1
		))

	if target_stack_id >= 0 and target_inventory.has_method("add_quantity_to_entry"):
		var moved_quantity: int = int(target_inventory.call(
			"add_quantity_to_entry",
			target_stack_id,
			_drag_item_quantity
		))
		if moved_quantity > 0:
			_drag_item_quantity -= moved_quantity
			return true

	if not target_inventory.has_method("add_item_at"):
		return false

	var added_quantity: int = int(target_inventory.call(
		"add_item_at",
		_drag_item_id,
		_drag_item_quantity,
		target_cell,
		_drag_item_size
	))
	if added_quantity <= 0:
		return false

	_drag_item_quantity -= added_quantity
	return true


func _return_split_drag_to_source() -> void:
	var source_inventory := _get_split_drag_source_inventory()
	if source_inventory == null or _drag_item_id == &"" or _drag_item_quantity <= 0:
		return

	var remaining_quantity := _drag_item_quantity
	if _drag_entry_id >= 0 and source_inventory.has_method("add_quantity_to_entry"):
		var restored_quantity: int = int(source_inventory.call(
			"add_quantity_to_entry",
			_drag_entry_id,
			remaining_quantity
		))
		remaining_quantity -= restored_quantity

	if remaining_quantity > 0:
		remaining_quantity -= _add_entry_to_inventory(
			source_inventory,
			_drag_item_id,
			remaining_quantity,
			_drag_item_size
		)

	_drag_item_quantity = maxi(remaining_quantity, 0)


func _is_split_drag_source() -> bool:
	return _drag_source == DRAG_SOURCE_SPLIT_INVENTORY or _drag_source == DRAG_SOURCE_SPLIT_EXTERNAL


func _get_split_drag_source_inventory() -> Node:
	if _drag_source == DRAG_SOURCE_SPLIT_INVENTORY:
		return _inventory
	if _drag_source == DRAG_SOURCE_SPLIT_EXTERNAL:
		return _external_inventory

	return null


func _transfer_entry_between_inventories(
	source_inventory: Node,
	target_inventory: Node,
	entry_id: int,
	target_cell: Vector2i,
	item_size: Vector2i
) -> bool:
	if source_inventory == null or target_inventory == null:
		return false

	if source_inventory == target_inventory:
		if _try_stack_entry_at_cell(source_inventory, target_inventory, entry_id, target_cell, item_size):
			return true
		return source_inventory.move_entry(entry_id, target_cell, item_size)

	if _try_stack_entry_at_cell(source_inventory, target_inventory, entry_id, target_cell, item_size):
		return true

	var entry: Dictionary = source_inventory.get_entry(entry_id)
	if entry.is_empty():
		return false

	var item_id: StringName = entry.get("item_id", &"")
	var quantity: int = int(entry.get("quantity", 1))
	var original_cell: Vector2i = entry.get("position", Vector2i.ZERO)
	var original_size: Vector2i = entry.get("size", Vector2i.ONE)

	var removed_entry: Dictionary = source_inventory.remove_entry(entry_id)
	if removed_entry.is_empty():
		return false

	var added_quantity: int = target_inventory.add_item_at(item_id, quantity, target_cell, item_size)
	if added_quantity == quantity:
		return true

	if added_quantity > 0:
		target_inventory.remove_item(item_id, added_quantity)

	source_inventory.add_item_at(item_id, quantity, original_cell, original_size)
	_show_warning("NO SPACE")
	return false


func _quick_transfer_entry_between_inventories(
	source_inventory: Node,
	target_inventory: Node,
	entry_id: int
) -> bool:
	if source_inventory == null:
		return false
	if target_inventory == null:
		_show_warning("NO CONTAINER")
		return false
	if source_inventory == target_inventory:
		return false

	var entry: Dictionary = source_inventory.get_entry(entry_id)
	if entry.is_empty():
		return false

	var item_id: StringName = entry.get("item_id", &"")
	var quantity: int = int(entry.get("quantity", 1))
	var original_cell: Vector2i = entry.get("position", Vector2i.ZERO)
	var item_size: Vector2i = entry.get("size", Vector2i.ONE)

	if not _can_inventory_accept_entry(target_inventory, item_id, quantity, item_size):
		_show_warning("NO SPACE")
		return false

	var removed_entry: Dictionary = source_inventory.remove_entry(entry_id)
	if removed_entry.is_empty():
		return false

	var added_quantity: int = _add_entry_to_inventory(target_inventory, item_id, quantity, item_size)
	if added_quantity == quantity:
		_hide_detail_panel()
		_refresh()
		_refresh_external_inventory()
		return true

	if added_quantity > 0 and target_inventory.has_method("remove_item"):
		target_inventory.remove_item(item_id, added_quantity)
	source_inventory.add_item_at(item_id, quantity, original_cell, item_size)
	_show_warning("NO SPACE")
	_refresh()
	_refresh_external_inventory()
	return false


func _can_inventory_accept_entry(
	target_inventory: Node,
	item_id: StringName,
	quantity: int,
	item_size: Vector2i
) -> bool:
	if target_inventory == null:
		return false
	if target_inventory.has_method("can_add_item_with_size"):
		return bool(target_inventory.call("can_add_item_with_size", item_id, quantity, item_size))
	if target_inventory.has_method("can_add_item"):
		return bool(target_inventory.call("can_add_item", item_id, quantity))

	return false


func _add_entry_to_inventory(
	target_inventory: Node,
	item_id: StringName,
	quantity: int,
	item_size: Vector2i
) -> int:
	if target_inventory == null:
		return 0
	if target_inventory.has_method("add_item_with_size"):
		return int(target_inventory.call("add_item_with_size", item_id, quantity, item_size))
	if target_inventory.has_method("add_item"):
		return int(target_inventory.call("add_item", item_id, quantity))

	return 0


func _try_stack_entry_at_cell(
	source_inventory: Node,
	target_inventory: Node,
	entry_id: int,
	target_cell: Vector2i,
	item_size: Vector2i
) -> bool:
	if source_inventory == null or target_inventory == null:
		return false
	if not target_inventory.has_method("get_stack_target_entry_id"):
		return false

	var entry: Dictionary = source_inventory.get_entry(entry_id)
	if entry.is_empty():
		return false

	var item_id: StringName = entry.get("item_id", &"")
	var ignored_entry_id := entry_id if source_inventory == target_inventory else -1
	var target_entry_id: int = target_inventory.get_stack_target_entry_id(
		item_id,
		target_cell,
		item_size,
		ignored_entry_id
	)
	if target_entry_id < 0:
		return false

	if source_inventory == target_inventory:
		return int(source_inventory.stack_entry_onto_entry(entry_id, target_entry_id)) > 0

	var moved_quantity: int = target_inventory.add_quantity_to_entry(
		target_entry_id,
		int(entry.get("quantity", 1))
	)
	if moved_quantity <= 0:
		return false

	source_inventory.remove_quantity_from_entry(entry_id, moved_quantity)
	return true


func _can_stack_dragged_entry_at_cell(
	target_inventory: Node,
	target_cell: Vector2i,
	item_size: Vector2i,
	ignored_entry_id: int
) -> bool:
	if target_inventory == null or not target_inventory.has_method("get_stack_target_entry_id"):
		return false
	if _drag_item_id == &"":
		return false

	return int(target_inventory.get_stack_target_entry_id(
		_drag_item_id,
		target_cell,
		item_size,
		ignored_entry_id
	)) >= 0


func _show_item_context_menu(target_inventory: Node, entry_id: int, source: StringName) -> void:
	if target_inventory == null:
		return

	var entry: Dictionary = target_inventory.get_entry(entry_id)
	if entry.is_empty():
		return

	_hide_detail_panel()
	_hide_context_menu()
	_hide_split_dialog()

	var actions: Array[Dictionary] = []
	if _can_inspect_entry(target_inventory, entry_id):
		actions.append({"label": "Inspect", "action": &"inspect"})
	if _can_split_stack_entry(target_inventory, entry_id):
		actions.append({"label": "Split", "action": &"split"})
	var opposite_inventory := _get_opposite_inventory_for_source(source)
	if opposite_inventory != null:
		actions.append({"label": "Transfer", "action": &"transfer"})
	if source == DRAG_SOURCE_INVENTORY and _can_quick_equip_entry(entry_id):
		actions.append({"label": "Equip", "action": &"equip"})

	var has_actions := not actions.is_empty()
	if not has_actions:
		actions.append({"label": "No Action", "action": &"none"})

	var menu_width := 156.0
	var row_height := 28.0
	var menu_height := 12.0 + float(actions.size()) * row_height + float(maxi(actions.size() - 1, 0)) * 4.0
	var menu := Panel.new()
	menu.name = "ItemContextMenu"
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.z_index = 60
	menu.size = Vector2(menu_width, menu_height)
	menu.custom_minimum_size = menu.size
	menu.add_theme_stylebox_override("panel", _make_flat_style(
		CONTEXT_MENU_COLOR,
		DETAIL_PANEL_BORDER_COLOR,
		1
	))
	root.add_child(menu)
	_context_menu = menu

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_STOP
	rows.position = Vector2(6, 6)
	rows.size = Vector2(menu_width - 12.0, menu_height - 12.0)
	rows.add_theme_constant_override("separation", 4)
	menu.add_child(rows)

	for action in actions:
		var action_name: StringName = action.get("action", &"none")
		var button := _create_context_menu_button(str(action.get("label", "Action")))
		button.disabled = action_name == &"none"
		if action_name == &"inspect":
			button.pressed.connect(Callable(self, "_on_context_inspect_entry_pressed").bind(target_inventory, entry_id))
		elif action_name == &"split":
			button.pressed.connect(Callable(self, "_on_context_split_pressed").bind(target_inventory, entry_id))
		elif action_name == &"transfer":
			button.pressed.connect(Callable(self, "_on_context_transfer_pressed").bind(target_inventory, opposite_inventory, entry_id))
		elif action_name == &"equip":
			button.pressed.connect(Callable(self, "_on_context_equip_pressed").bind(entry_id))
		rows.add_child(button)

	_position_floating_panel(menu, get_viewport().get_mouse_position())


func _create_context_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 28)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", DETAIL_TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", DETAIL_MUTED_COLOR)
	button.add_theme_stylebox_override("normal", _make_flat_style(CONTEXT_BUTTON_COLOR, Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override("hover", _make_flat_style(CONTEXT_MENU_HOVER_COLOR, Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override("pressed", _make_flat_style(Color(0.22, 0.28, 0.32, 1.0), Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override("disabled", _make_flat_style(Color(0.08, 0.085, 0.095, 1.0), Color.TRANSPARENT, 0))
	return button


func _on_context_inspect_entry_pressed(target_inventory: Node, entry_id: int) -> void:
	_hide_context_menu()
	_hide_split_dialog()
	_show_weapon_inspect_for_entry(target_inventory, entry_id)


func _on_context_split_pressed(target_inventory: Node, entry_id: int) -> void:
	_hide_context_menu()
	_show_split_dialog(target_inventory, entry_id)


func _on_context_equip_pressed(entry_id: int) -> void:
	_hide_context_menu()
	_hide_split_dialog()
	_try_quick_equip_entry(entry_id)


func _on_context_transfer_pressed(source_inventory: Node, target_inventory: Node, entry_id: int) -> void:
	_hide_context_menu()
	_hide_split_dialog()
	_quick_transfer_entry_between_inventories(source_inventory, target_inventory, entry_id)


func _show_split_dialog(target_inventory: Node, entry_id: int) -> void:
	if not _can_split_stack_entry(target_inventory, entry_id):
		return

	var entry: Dictionary = target_inventory.get_entry(entry_id)
	var item_id: StringName = entry.get("item_id", &"")
	var definition: Dictionary = _get_item_definition_for_inventory(target_inventory, item_id)
	var quantity: int = int(entry.get("quantity", 1))

	_split_dialog_inventory = target_inventory
	_split_dialog_entry_id = entry_id
	_split_dialog_max_quantity = maxi(quantity - 1, 1)

	var dialog := Panel.new()
	dialog.name = "SplitStackDialog"
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog.z_index = 65
	dialog.size = Vector2(320, 170)
	dialog.custom_minimum_size = dialog.size
	dialog.add_theme_stylebox_override("panel", _make_flat_style(
		CONTEXT_MENU_COLOR,
		DETAIL_PANEL_BORDER_COLOR,
		1
	))
	root.add_child(dialog)
	_split_dialog = dialog

	var margin := _create_margin_container(14, 12, 14, 12)
	dialog.add_child(margin)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_STOP
	rows.add_theme_constant_override("separation", 8)
	margin.add_child(rows)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = "SPLIT STACK"
	title.modulate = DETAIL_TEXT_COLOR
	title.add_theme_font_size_override("font_size", 15)
	rows.add_child(title)

	var note := Label.new()
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note.text = "%s x%d" % [str(definition.get("name", "Item")), quantity]
	note.modulate = DETAIL_MUTED_COLOR
	note.add_theme_font_size_override("font_size", 11)
	note.clip_text = true
	rows.add_child(note)

	var quantity_row := HBoxContainer.new()
	quantity_row.mouse_filter = Control.MOUSE_FILTER_STOP
	quantity_row.add_theme_constant_override("separation", 6)
	rows.add_child(quantity_row)

	quantity_row.add_child(_create_quantity_step_button("-10", -10))
	quantity_row.add_child(_create_quantity_step_button("-1", -1))

	_split_dialog_quantity_input = LineEdit.new()
	_split_dialog_quantity_input.custom_minimum_size = Vector2(86, 30)
	_split_dialog_quantity_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_split_dialog_quantity_input.max_length = 4
	_split_dialog_quantity_input.text_submitted.connect(_on_split_quantity_submitted)
	quantity_row.add_child(_split_dialog_quantity_input)

	quantity_row.add_child(_create_quantity_step_button("+1", 1))
	quantity_row.add_child(_create_quantity_step_button("+10", 10))

	var action_row := HBoxContainer.new()
	action_row.mouse_filter = Control.MOUSE_FILTER_STOP
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 8)
	rows.add_child(action_row)

	var cancel_button := _create_dialog_action_button("Cancel")
	cancel_button.pressed.connect(_hide_split_dialog)
	action_row.add_child(cancel_button)

	var split_button := _create_dialog_action_button("Split")
	split_button.pressed.connect(_confirm_split_quantity)
	action_row.add_child(split_button)

	var default_quantity := clampi(floori(float(quantity) * 0.5), 1, _split_dialog_max_quantity)
	_set_split_dialog_quantity(default_quantity)
	_position_floating_panel(dialog, get_viewport().get_mouse_position() + Vector2(8, 8))
	_split_dialog_quantity_input.grab_focus()
	_split_dialog_quantity_input.select_all()


func _create_quantity_step_button(text: String, delta: int) -> Button:
	var button := _create_context_menu_button(text)
	button.custom_minimum_size = Vector2(46, 30)
	button.pressed.connect(Callable(self, "_adjust_split_dialog_quantity").bind(delta))
	return button


func _create_dialog_action_button(text: String) -> Button:
	var button := _create_context_menu_button(text)
	button.custom_minimum_size = Vector2(74, 30)
	return button


func _adjust_split_dialog_quantity(delta: int) -> void:
	_set_split_dialog_quantity(_get_split_dialog_quantity() + delta)


func _set_split_dialog_quantity(quantity: int) -> void:
	if _split_dialog_quantity_input == null:
		return

	var clamped_quantity := clampi(quantity, 1, _split_dialog_max_quantity)
	_split_dialog_quantity_input.text = str(clamped_quantity)
	_split_dialog_quantity_input.caret_column = _split_dialog_quantity_input.text.length()


func _get_split_dialog_quantity() -> int:
	if _split_dialog_quantity_input == null:
		return 1

	var text := _split_dialog_quantity_input.text.strip_edges()
	if not text.is_valid_int():
		return 1

	return clampi(int(text), 1, _split_dialog_max_quantity)


func _on_split_quantity_submitted(_text: String) -> void:
	_confirm_split_quantity()


func _confirm_split_quantity() -> void:
	var split_quantity := _get_split_dialog_quantity()
	var target_inventory := _split_dialog_inventory
	var entry_id := _split_dialog_entry_id
	_hide_split_dialog()
	_try_split_stack_entry(target_inventory, entry_id, split_quantity)


func _position_floating_panel(floating_panel: Control, target_position: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var margin := 8.0
	var panel_size: Vector2 = floating_panel.size
	floating_panel.global_position = Vector2(
		clampf(target_position.x, margin, viewport_size.x - panel_size.x - margin),
		clampf(target_position.y, margin, viewport_size.y - panel_size.y - margin)
	)


func _hide_context_menu() -> void:
	if is_instance_valid(_context_menu):
		_context_menu.queue_free()
	_context_menu = null


func _hide_split_dialog() -> void:
	if is_instance_valid(_split_dialog):
		_split_dialog.queue_free()
	_split_dialog = null
	_split_dialog_inventory = null
	_split_dialog_entry_id = -1
	_split_dialog_max_quantity = 1
	_split_dialog_quantity_input = null


func _is_context_popup_visible() -> bool:
	return is_instance_valid(_context_menu) or is_instance_valid(_split_dialog)


func _is_mouse_inside_context_popup() -> bool:
	var mouse_position := get_viewport().get_mouse_position()
	if is_instance_valid(_context_menu):
		var menu_position: Vector2 = _context_menu.get_global_transform().affine_inverse() * mouse_position
		if Rect2(Vector2.ZERO, _context_menu.size).has_point(menu_position):
			return true

	if is_instance_valid(_split_dialog):
		var dialog_position: Vector2 = _split_dialog.get_global_transform().affine_inverse() * mouse_position
		if Rect2(Vector2.ZERO, _split_dialog.size).has_point(dialog_position):
			return true

	return false


func _get_opposite_inventory_for_source(source: StringName) -> Node:
	if source == DRAG_SOURCE_EXTERNAL:
		return _inventory
	if source == DRAG_SOURCE_INVENTORY and _external_inventory != null:
		return _external_inventory

	return null


func _can_split_stack_entry(target_inventory: Node, entry_id: int) -> bool:
	if target_inventory == null or not target_inventory.has_method("split_entry"):
		return false

	var entry: Dictionary = target_inventory.get_entry(entry_id)
	if entry.is_empty():
		return false

	var item_id: StringName = entry.get("item_id", &"")
	var definition: Dictionary = _get_item_definition_for_inventory(target_inventory, item_id)
	return bool(definition.get("stackable", false)) and int(entry.get("quantity", 1)) > 1


func _can_inspect_entry(target_inventory: Node, entry_id: int) -> bool:
	if target_inventory == null or not target_inventory.has_method("get_entry"):
		return false

	var entry: Dictionary = target_inventory.get_entry(entry_id)
	if entry.is_empty():
		return false

	var item_id: StringName = entry.get("item_id", &"")
	return _load_weapon_resource_for_item(item_id) != null


func _show_weapon_inspect_for_entry(target_inventory: Node, entry_id: int) -> void:
	if target_inventory == null or not target_inventory.has_method("get_entry"):
		return

	var entry: Dictionary = target_inventory.get_entry(entry_id)
	if entry.is_empty():
		return

	var item_id: StringName = entry.get("item_id", &"")
	var weapon := _load_weapon_resource_for_item(item_id)
	if weapon == null:
		return

	_show_weapon_inspect_window(item_id, weapon, &"")


func _show_weapon_inspect_for_equipment_slot(slot: StringName) -> void:
	var item_id: StringName = _get_equipped_item_id_for_slot(slot)
	if item_id == &"":
		return

	var weapon := _get_equipped_weapon_for_slot(slot)
	if weapon == null:
		return

	_show_weapon_inspect_window(item_id, weapon, slot)


func _show_weapon_inspect_window(item_id: StringName, weapon: Resource, equipment_slot: StringName = &"") -> void:
	if weapon == null:
		return

	_hide_weapon_inspect_window()
	_hide_detail_panel()
	_weapon_inspect_item_id = item_id
	_weapon_inspect_weapon = weapon
	_weapon_inspect_equipment_slot = equipment_slot
	_weapon_inspect_slot_nodes.clear()

	var window := Panel.new()
	window.name = "WeaponInspectWindow"
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	window.z_index = 70
	window.size = WEAPON_INSPECT_SIZE
	window.custom_minimum_size = WEAPON_INSPECT_SIZE
	window.add_theme_stylebox_override("panel", _make_flat_style(
		DETAIL_PANEL_COLOR,
		DETAIL_PANEL_BORDER_COLOR,
		2
	))
	root.add_child(window)
	_weapon_inspect_window = window

	var margin := _create_margin_container(14, 12, 14, 14)
	window.add_child(margin)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_STOP
	rows.add_theme_constant_override("separation", 10)
	margin.add_child(rows)

	rows.add_child(_create_weapon_inspect_header(item_id, weapon, equipment_slot))
	rows.add_child(_create_weapon_graphic_panel(item_id, weapon))
	rows.add_child(_create_weapon_stats_panel(weapon))
	rows.add_child(_create_weapon_slots_panel(item_id, weapon, equipment_slot))

	_position_weapon_inspect_window(window)


func _create_weapon_inspect_header(item_id: StringName, weapon: Resource, equipment_slot: StringName) -> Control:
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.custom_minimum_size = Vector2(0, 30)
	header.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = str(weapon.get("display_name"))
	title.modulate = DETAIL_TEXT_COLOR
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	header.add_child(title)

	var source_label := Label.new()
	source_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source_label.text = _get_weapon_inspect_source_label(item_id, equipment_slot)
	source_label.modulate = DETAIL_MUTED_COLOR
	source_label.add_theme_font_size_override("font_size", 11)
	source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	source_label.custom_minimum_size = Vector2(160, 0)
	source_label.clip_text = true
	header.add_child(source_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(30, 28)
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.add_theme_stylebox_override("normal", _make_flat_style(CONTEXT_BUTTON_COLOR, DETAIL_PANEL_BORDER_COLOR, 1))
	close_button.add_theme_stylebox_override("hover", _make_flat_style(CONTEXT_MENU_HOVER_COLOR, DETAIL_PANEL_BORDER_COLOR, 1))
	close_button.add_theme_stylebox_override("pressed", _make_flat_style(Color(0.22, 0.28, 0.32, 1.0), DETAIL_PANEL_BORDER_COLOR, 1))
	close_button.pressed.connect(Callable(self, "_hide_weapon_inspect_window"))
	header.add_child(close_button)

	return header


func _get_weapon_inspect_source_label(item_id: StringName, equipment_slot: StringName) -> String:
	if equipment_slot != &"":
		return _get_slot_display_name(equipment_slot)

	var definition: Dictionary = _inventory.get_item_definition(item_id) if _inventory != null else {}
	return str(definition.get("name", item_id))


func _create_weapon_graphic_panel(item_id: StringName, weapon: Resource) -> Control:
	var graphic := Panel.new()
	graphic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graphic.custom_minimum_size = Vector2(0, 168)
	graphic.add_theme_stylebox_override("panel", _make_flat_style(
		WEAPON_INSPECT_GRAPHIC_COLOR,
		Color(0.22, 0.24, 0.27, 1.0),
		1
	))

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.position = Vector2(14, 10)
	name_label.size = Vector2(360, 20)
	name_label.text = "%s  /  %s" % [str(weapon.get("display_name")), str(item_id)]
	name_label.modulate = DETAIL_MUTED_COLOR
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.clip_text = true
	graphic.add_child(name_label)

	_add_weapon_graphic_rect(graphic, Rect2(Vector2(136, 72), Vector2(300, 28)), Color(0.33, 0.35, 0.37, 1.0))
	_add_weapon_graphic_rect(graphic, Rect2(Vector2(420, 80), Vector2(118, 10)), Color(0.43, 0.44, 0.45, 1.0))
	_add_weapon_graphic_rect(graphic, Rect2(Vector2(184, 50), Vector2(118, 14)), Color(0.26, 0.28, 0.3, 1.0))
	_add_weapon_graphic_rect(graphic, Rect2(Vector2(310, 100), Vector2(36, 72)), Color(0.22, 0.24, 0.25, 1.0))
	_add_weapon_graphic_rect(graphic, Rect2(Vector2(356, 102), Vector2(52, 70)), Color(0.18, 0.19, 0.205, 1.0))
	_add_weapon_graphic_rect(graphic, Rect2(Vector2(92, 84), Vector2(84, 22)), Color(0.18, 0.19, 0.205, 1.0))

	var chamber_marker := ColorRect.new()
	chamber_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chamber_marker.position = Vector2(290, 65)
	chamber_marker.size = Vector2(30, 6)
	chamber_marker.color = SLOT_ACTIVE_BORDER_COLOR
	graphic.add_child(chamber_marker)

	return graphic


func _add_weapon_graphic_rect(parent: Control, rect: Rect2, color: Color) -> void:
	var part := ColorRect.new()
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	part.position = rect.position
	part.size = rect.size
	part.color = color
	parent.add_child(part)


func _create_weapon_stats_panel(weapon: Resource) -> Control:
	var stats_panel := Panel.new()
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_panel.custom_minimum_size = Vector2(0, 180)
	stats_panel.add_theme_stylebox_override("panel", _make_flat_style(
		Color(0.075, 0.08, 0.09, 0.92),
		Color(0.24, 0.26, 0.3, 1.0),
		1
	))

	var margin := _create_margin_container(12, 10, 12, 10)
	stats_panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 5)
	margin.add_child(rows)

	rows.add_child(_create_weapon_inspect_section_label("STATS"))
	rows.add_child(_create_inspect_stat_bar("Damage", str(_get_resource_int(weapon, &"damage")), float(_get_resource_int(weapon, &"damage")) / 40.0))
	rows.add_child(_create_inspect_stat_bar("Capacity", str(_get_weapon_total_capacity(weapon)), float(_get_weapon_total_capacity(weapon)) / 16.0))
	rows.add_child(_create_inspect_stat_bar("Fire Interval", _format_seconds(_get_resource_float(weapon, &"fire_cooldown")), 1.0 - clampf(_get_resource_float(weapon, &"fire_cooldown") / 1.0, 0.0, 1.0)))
	rows.add_child(_create_inspect_stat_bar("Reload", _format_seconds(_get_resource_float(weapon, &"reload_time")), 1.0 - clampf(_get_resource_float(weapon, &"reload_time") / 3.0, 0.0, 1.0)))
	rows.add_child(_create_inspect_stat_bar("Recoil", "%.2f" % _get_resource_float(weapon, &"recoil_amount"), 1.0 - clampf(_get_resource_float(weapon, &"recoil_amount") / 0.6, 0.0, 1.0)))

	return stats_panel


func _create_weapon_inspect_section_label(text: String) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.modulate = DETAIL_TEXT_COLOR
	label.add_theme_font_size_override("font_size", 12)
	label.clip_text = true
	return label


func _create_inspect_stat_bar(stat_name: String, stat_value: String, ratio: float) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, 22)
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = stat_name
	name_label.modulate = DETAIL_MUTED_COLOR
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.custom_minimum_size = Vector2(112, 0)
	name_label.clip_text = true
	row.add_child(name_label)

	var bar_back := Panel.new()
	bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_back.custom_minimum_size = Vector2(410, 12)
	bar_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_back.add_theme_stylebox_override("panel", _make_flat_style(Color(0.035, 0.04, 0.045, 1.0), Color(0.22, 0.24, 0.27, 1.0), 1))
	row.add_child(bar_back)

	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(1, 1)
	fill.size = Vector2(maxf(0.0, 408.0 * clampf(ratio, 0.0, 1.0)), 10)
	fill.color = Color(0.2, 0.56, 0.66, 1.0)
	bar_back.add_child(fill)

	var value_label := Label.new()
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.text = stat_value
	value_label.modulate = DETAIL_TEXT_COLOR
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(82, 0)
	value_label.clip_text = true
	row.add_child(value_label)

	return row


func _create_weapon_slots_panel(item_id: StringName, weapon: Resource, equipment_slot: StringName) -> Control:
	var slots_panel := Panel.new()
	slots_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots_panel.custom_minimum_size = Vector2(0, 198)
	slots_panel.add_theme_stylebox_override("panel", _make_flat_style(
		Color(0.07, 0.075, 0.085, 0.94),
		Color(0.24, 0.26, 0.3, 1.0),
		1
	))

	var margin := _create_margin_container(12, 10, 12, 10)
	slots_panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 8)
	margin.add_child(rows)
	rows.add_child(_create_weapon_inspect_section_label("PART SLOTS"))

	var grid := GridContainer.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	rows.add_child(grid)

	var item_type: StringName = _get_item_type(item_id)
	if item_type == &"ranged_weapon":
		for slot_data in _get_ranged_weapon_part_slots(weapon, equipment_slot):
			var slot_card := _create_weapon_part_slot_card(slot_data)
			var slot_id: StringName = slot_data.get("slot_id", &"")
			if slot_id != &"":
				_weapon_inspect_slot_nodes[slot_id] = slot_card
				slot_card.gui_input.connect(_on_weapon_part_slot_gui_input.bind(slot_id))
			grid.add_child(slot_card)
	else:
		for slot_data in _get_melee_weapon_part_slots():
			grid.add_child(_create_weapon_part_slot_card(slot_data))

	return slots_panel


func _get_ranged_weapon_part_slots(weapon: Resource, equipment_slot: StringName) -> Array[Dictionary]:
	var magazine_id := StringName(weapon.get("magazine_item_id"))
	var magazine_definition: Dictionary = _inventory.get_item_definition(magazine_id) if _inventory != null and magazine_id != &"" else {}
	var magazine_name := str(magazine_definition.get("short_name", magazine_definition.get("name", magazine_id)))
	var magazine_line := magazine_name
	if _is_active_firearm_slot(equipment_slot) and _player != null:
		if bool(_player.call("has_active_magazine_inserted")):
			magazine_line = "%s\n%d/%d" % [
				magazine_name,
				int(_player.get("magazine_ammo")),
				int(_player.get("magazine_size")),
			]
		else:
			magazine_line = "Empty"

	var chamber_line := "Round"
	if _is_active_firearm_slot(equipment_slot) and _player != null:
		var chamber_count := int(_player.get("chamber_ammo"))
		if chamber_count > 0:
			chamber_line = "%d/%d" % [
				chamber_count,
				int(_player.get("chamber_size")),
			]
		else:
			chamber_line = "Empty"

	return [
		{"slot_id": WEAPON_PART_MAGAZINE, "name": "MAGAZINE", "value": magazine_line, "locked": false},
		{"slot_id": WEAPON_PART_CHAMBER, "name": "CHAMBER", "value": chamber_line, "locked": true},
		{"slot_id": &"optic", "name": "OPTIC", "value": "Empty", "locked": false},
		{"slot_id": &"muzzle", "name": "MUZZLE", "value": "Empty", "locked": false},
		{"slot_id": &"grip", "name": "GRIP", "value": "Empty", "locked": false},
		{"slot_id": &"under", "name": "UNDER", "value": "Empty", "locked": false},
		{"slot_id": &"accessory", "name": "ACCESSORY", "value": "Empty", "locked": false},
		{"slot_id": &"stock", "name": "STOCK", "value": "Empty", "locked": false},
		{"slot_id": &"barrel", "name": "BARREL", "value": "Fixed", "locked": true},
		{"slot_id": &"receiver", "name": "RECEIVER", "value": "Fixed", "locked": true},
	]


func _get_melee_weapon_part_slots() -> Array[Dictionary]:
	return [
		{"name": "BLADE", "value": "Fixed", "locked": true},
		{"name": "HANDLE", "value": "Fixed", "locked": true},
		{"name": "ACCESSORY", "value": "Empty", "locked": false},
	]


func _create_weapon_part_slot_card(slot_data: Dictionary) -> Control:
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size = Vector2(124, 58)
	card.add_theme_stylebox_override("panel", _make_flat_style(
		WEAPON_INSPECT_SLOT_COLOR,
		DETAIL_PANEL_BORDER_COLOR if not bool(slot_data.get("locked", false)) else Color(0.24, 0.25, 0.28, 1.0),
		1
	))

	var margin := _create_margin_container(8, 6, 8, 6)
	card.add_child(margin)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 3)
	margin.add_child(rows)

	var name := Label.new()
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.text = str(slot_data.get("name", "SLOT"))
	name.modulate = DETAIL_MUTED_COLOR
	name.add_theme_font_size_override("font_size", 9)
	name.clip_text = true
	rows.add_child(name)

	var value := Label.new()
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.text = str(slot_data.get("value", "Empty"))
	value.modulate = DETAIL_TEXT_COLOR if not bool(slot_data.get("locked", false)) else DETAIL_MUTED_COLOR
	value.add_theme_font_size_override("font_size", 10)
	value.clip_text = true
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(value)

	return card


func _on_weapon_part_slot_gui_input(event: InputEvent, slot_id: StringName) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
			return

		if not _is_weapon_inspect_active_firearm():
			_show_warning("EQUIP ONLY")
			get_viewport().set_input_as_handled()
			return

		if slot_id == WEAPON_PART_MAGAZINE:
			_begin_weapon_magazine_drag()
		elif slot_id == WEAPON_PART_CHAMBER:
			_begin_weapon_chamber_drag()

		get_viewport().set_input_as_handled()


func _is_weapon_inspect_active_firearm() -> bool:
	return _weapon_inspect_equipment_slot != &"" and _is_active_firearm_slot(_weapon_inspect_equipment_slot)


func _begin_weapon_magazine_drag() -> void:
	if _player == null or _inventory == null:
		return
	if not bool(_player.call("has_active_magazine_inserted")):
		_show_warning("EMPTY")
		return

	var item_id := StringName(_player.call("get_active_magazine_item_id"))
	var metadata: Dictionary = _player.call("get_active_magazine_metadata")
	if item_id == &"":
		return

	var definition: Dictionary = _inventory.get_item_definition(item_id)
	_begin_weapon_part_drag(
		DRAG_SOURCE_WEAPON_MAGAZINE,
		WEAPON_PART_MAGAZINE,
		item_id,
		1,
		definition.get("size", Vector2i.ONE),
		metadata
	)


func _begin_weapon_chamber_drag() -> void:
	if _player == null or _inventory == null:
		return
	if int(_player.get("chamber_ammo")) <= 0:
		_show_warning("EMPTY")
		return

	var item_id := StringName(_player.get("ammo_item_id"))
	if item_id == &"":
		return

	var definition: Dictionary = _inventory.get_item_definition(item_id)
	_begin_weapon_part_drag(
		DRAG_SOURCE_WEAPON_CHAMBER,
		WEAPON_PART_CHAMBER,
		item_id,
		1,
		definition.get("size", Vector2i.ONE),
		{}
	)


func _begin_weapon_part_drag(
	drag_source: StringName,
	part_slot: StringName,
	item_id: StringName,
	quantity: int,
	item_size: Vector2i,
	metadata: Dictionary
) -> void:
	var definition: Dictionary = _inventory.get_item_definition(item_id)
	var drag_size := _entry_pixel_size(item_size)

	_hide_detail_panel()
	_hide_context_menu()
	_hide_split_dialog()
	_drag_source = drag_source
	_drag_entry_id = -1
	_drag_equipment_slot = &""
	_drag_weapon_part_slot = part_slot
	_drag_item_id = item_id
	_drag_item_size = item_size
	_drag_item_quantity = quantity
	_drag_item_metadata = metadata
	_drag_cell_offset = Vector2i.ZERO
	_drag_mouse_offset = drag_size * 0.5

	_equipment_drag_node = _create_item_panel(definition, quantity, item_size, true, metadata)
	_equipment_drag_node.z_index = 30
	root.add_child(_equipment_drag_node)
	_update_drag_visual()


func _is_weapon_part_drag_source() -> bool:
	return _drag_source == DRAG_SOURCE_WEAPON_MAGAZINE or _drag_source == DRAG_SOURCE_WEAPON_CHAMBER


func _drop_inventory_entry_to_weapon_part(source_inventory: Node, entry_id: int, slot_id: StringName) -> bool:
	if source_inventory == null:
		return false
	if not _is_weapon_inspect_active_firearm():
		_show_warning("EQUIP ONLY")
		return false

	if slot_id == WEAPON_PART_MAGAZINE:
		return _drop_magazine_entry_to_active_weapon(source_inventory, entry_id)
	if slot_id == WEAPON_PART_CHAMBER:
		return _drop_ammo_entry_to_chamber(source_inventory, entry_id)

	_show_warning("WRONG SLOT")
	return false


func _drop_magazine_entry_to_active_weapon(source_inventory: Node, entry_id: int) -> bool:
	if _player == null or source_inventory == null:
		return false

	var entry: Dictionary = source_inventory.get_entry(entry_id)
	if entry.is_empty():
		return false

	var item_id: StringName = entry.get("item_id", &"")
	var metadata: Dictionary = entry.get("metadata", {})
	if not bool(_player.call("can_insert_active_magazine", item_id, metadata)):
		_show_warning("WRONG MAG")
		return false

	var has_previous_magazine := bool(_player.call("has_active_magazine_inserted"))
	if has_previous_magazine and source_inventory != _inventory and not _inventory.can_add_item(StringName(_player.call("get_active_magazine_item_id")), 1):
		_show_warning("NO SPACE")
		return false

	var removed_entry: Dictionary = source_inventory.remove_entry(entry_id)
	if removed_entry.is_empty():
		return false

	var previous_magazine: Dictionary = {}
	if has_previous_magazine:
		previous_magazine = _player.call("eject_active_magazine")
		if previous_magazine.is_empty() or not _add_metadata_item_to_inventory(
			_inventory,
			previous_magazine.get("item_id", &""),
			previous_magazine.get("metadata", {})
		):
			_restore_removed_entry(source_inventory, removed_entry)
			if not previous_magazine.is_empty():
				_player.call("insert_active_magazine", previous_magazine.get("item_id", &""), previous_magazine.get("metadata", {}))
			_show_warning("NO SPACE")
			return false

	if not bool(_player.call("insert_active_magazine", item_id, metadata)):
		_restore_removed_entry(source_inventory, removed_entry)
		if not previous_magazine.is_empty():
			_player.call("insert_active_magazine", previous_magazine.get("item_id", &""), previous_magazine.get("metadata", {}))
		_show_warning("WRONG MAG")
		return false

	_refresh_weapon_inspect_window()
	return true


func _drop_ammo_entry_to_chamber(source_inventory: Node, entry_id: int) -> bool:
	if _player == null or source_inventory == null:
		return false

	var entry: Dictionary = source_inventory.get_entry(entry_id)
	if entry.is_empty():
		return false

	var item_id: StringName = entry.get("item_id", &"")
	if not bool(_player.call("can_insert_chamber_round", item_id)):
		_show_warning("WRONG ROUND")
		return false

	var removed_quantity: int = source_inventory.remove_quantity_from_entry(entry_id, 1)
	if removed_quantity != 1:
		return false

	if not bool(_player.call("insert_chamber_round", item_id)):
		_add_entry_to_inventory(source_inventory, item_id, 1, entry.get("size", Vector2i.ONE))
		_show_warning("CHAMBER FULL")
		return false

	_refresh_weapon_inspect_window()
	return true


func _finish_weapon_part_drag(target_cell: Vector2i, external_target_cell: Vector2i) -> bool:
	if _drag_item_id == &"" or _drag_item_quantity <= 0:
		return false

	var did_place := false
	if _is_mouse_inside_grid():
		did_place = _place_weapon_part_drag_in_inventory(_inventory, target_cell)
	elif _is_mouse_inside_external_grid() and _external_inventory != null:
		did_place = _place_weapon_part_drag_in_inventory(_external_inventory, external_target_cell)
	elif not _is_mouse_inside_any_inventory_frame():
		did_place = _drop_item_to_world(_drag_item_id, _drag_item_quantity, _drag_item_metadata)

	if did_place:
		if _drag_source == DRAG_SOURCE_WEAPON_MAGAZINE:
			_player.call("eject_active_magazine")
		elif _drag_source == DRAG_SOURCE_WEAPON_CHAMBER:
			_player.call("eject_chamber_round")
		_refresh_weapon_inspect_window()
	else:
		_show_warning("NO SPACE")

	return did_place


func _place_weapon_part_drag_in_inventory(target_inventory: Node, target_cell: Vector2i) -> bool:
	if target_inventory == null:
		return false
	if _drag_item_metadata.is_empty() and target_inventory.has_method("get_stack_target_entry_id"):
		var target_stack_id: int = int(target_inventory.call(
			"get_stack_target_entry_id",
			_drag_item_id,
			target_cell,
			_drag_item_size,
			-1
		))
		if target_stack_id >= 0 and target_inventory.has_method("add_quantity_to_entry"):
			return int(target_inventory.call("add_quantity_to_entry", target_stack_id, _drag_item_quantity)) == _drag_item_quantity

	if not target_inventory.has_method("add_item_at"):
		return false

	return int(target_inventory.call(
		"add_item_at",
		_drag_item_id,
		_drag_item_quantity,
		target_cell,
		_drag_item_size,
		_drag_item_metadata
	)) == _drag_item_quantity


func _add_metadata_item_to_inventory(target_inventory: Node, item_id: StringName, metadata: Dictionary) -> bool:
	if target_inventory == null or item_id == &"":
		return false
	if target_inventory.has_method("add_item_with_metadata"):
		return bool(target_inventory.call("add_item_with_metadata", item_id, metadata))
	if target_inventory.has_method("add_item"):
		return int(target_inventory.call("add_item", item_id, 1)) == 1

	return false


func _restore_removed_entry(target_inventory: Node, entry: Dictionary) -> bool:
	if target_inventory == null or entry.is_empty():
		return false
	if not target_inventory.has_method("add_item_at"):
		return false

	return int(target_inventory.call(
		"add_item_at",
		entry.get("item_id", &""),
		int(entry.get("quantity", 1)),
		entry.get("position", Vector2i.ZERO),
		entry.get("size", Vector2i.ONE),
		entry.get("metadata", {})
	)) == int(entry.get("quantity", 1))


func _refresh_weapon_inspect_window() -> void:
	if not is_instance_valid(_weapon_inspect_window) or _weapon_inspect_weapon == null or _weapon_inspect_item_id == &"":
		return

	_show_weapon_inspect_window(_weapon_inspect_item_id, _weapon_inspect_weapon, _weapon_inspect_equipment_slot)


func _get_weapon_total_capacity(weapon: Resource) -> int:
	return _get_resource_int(weapon, &"magazine_size") + _get_resource_int(weapon, &"chamber_size")


func _hide_weapon_inspect_window() -> void:
	if is_instance_valid(_weapon_inspect_window):
		_weapon_inspect_window.queue_free()
	_weapon_inspect_window = null
	_weapon_inspect_slot_nodes.clear()
	_weapon_inspect_item_id = &""
	_weapon_inspect_weapon = null
	_weapon_inspect_equipment_slot = &""


func _position_weapon_inspect_window(window: Control) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var margin := 24.0
	window.global_position = Vector2(
		clampf((viewport_size.x - window.size.x) * 0.5, margin, viewport_size.x - window.size.x - margin),
		clampf((viewport_size.y - window.size.y) * 0.5, margin, viewport_size.y - window.size.y - margin)
	)


func _try_split_stack_entry(target_inventory: Node, entry_id: int, split_quantity: int = -1) -> bool:
	if target_inventory == null or not target_inventory.has_method("split_entry"):
		return false

	var entry: Dictionary = target_inventory.get_entry(entry_id)
	if entry.is_empty():
		return false

	if not _can_split_stack_entry(target_inventory, entry_id):
		return false

	var split_entry: Dictionary = target_inventory.split_entry(entry_id, split_quantity)
	if split_entry.is_empty():
		_show_warning("NO SPACE")
		return true

	_refresh()
	_refresh_external_inventory()
	return true


func _drop_item_to_world(item_id: StringName, quantity: int = 1, metadata: Dictionary = {}) -> bool:
	if dropped_item_scene == null or _player == null:
		return false

	var dropped_item := dropped_item_scene.instantiate()
	dropped_item.set("item_id", item_id)
	dropped_item.set("quantity", quantity)
	dropped_item.set("metadata", metadata)

	var drop_parent: Node = get_tree().current_scene
	if drop_parent == null:
		drop_parent = _player.get_parent()
	drop_parent.add_child(dropped_item)

	if dropped_item is Node2D:
		var dropped_item_2d := dropped_item as Node2D
		dropped_item_2d.global_position = _player.global_position + Vector2(28, -10)

	return true


func _can_quick_equip_entry(entry_id: int) -> bool:
	if _inventory == null or _equipment == null:
		return false

	var entry: Dictionary = _inventory.get_entry(entry_id)
	if entry.is_empty():
		return false

	var item_id: StringName = entry.get("item_id", &"")
	var definition: Dictionary = _inventory.get_item_definition(item_id)
	var item_type: StringName = definition.get("type", &"")
	return _get_quick_equip_slot_for_item_type(item_type) != &""


func _try_quick_equip_entry(entry_id: int) -> bool:
	if _inventory == null or _equipment == null:
		return false

	var entry: Dictionary = _inventory.get_entry(entry_id)
	if entry.is_empty():
		return false

	var item_id: StringName = entry.get("item_id", &"")
	var definition: Dictionary = _inventory.get_item_definition(item_id)
	var item_type: StringName = definition.get("type", &"")
	var target_slot: StringName = _get_quick_equip_slot_for_item_type(item_type)
	if target_slot == &"":
		return false

	return _equip_inventory_entry_to_slot(entry_id, target_slot)


func _equip_inventory_entry_to_slot(entry_id: int, slot: StringName) -> bool:
	if _inventory == null or _equipment == null:
		return false

	var entry: Dictionary = _inventory.get_entry(entry_id)
	if entry.is_empty():
		return false

	var item_id: StringName = entry.get("item_id", &"")
	if not _does_slot_accept_item(slot, item_id):
		_show_warning("WRONG SLOT")
		return false

	var next_weapon: Resource = _load_weapon_resource_for_item(item_id)
	if next_weapon == null:
		return false

	var previous_item_id: StringName = _get_equipped_item_id_for_slot(slot)
	if previous_item_id == item_id:
		return false

	var removed_entry: Dictionary = _inventory.remove_entry(entry_id)
	if removed_entry.is_empty():
		return false

	if previous_item_id != &"":
		var added_previous: int = _inventory.add_item(previous_item_id, 1)
		if added_previous <= 0:
			_inventory.add_item(item_id, int(removed_entry.get("quantity", 1)))
			_show_warning("NO SPACE")
			return false

	if not _equip_weapon_resource(slot, next_weapon):
		_inventory.add_item(item_id, int(removed_entry.get("quantity", 1)))
		return false

	_refresh()
	return true


func _get_equipped_item_id_for_slot(slot: StringName) -> StringName:
	if _equipment == null:
		return &""

	var equipped_weapon: Resource = _get_equipped_weapon_for_slot(slot)
	if equipped_weapon == null:
		return &""

	return StringName(equipped_weapon.get("weapon_id"))


func _get_equipped_weapon_for_slot(slot: StringName) -> Resource:
	if _equipment == null:
		return null
	if _equipment.has_method("get_weapon"):
		return _equipment.call("get_weapon", slot) as Resource
	if slot == &"ranged" and _equipment.has_method("get_ranged_weapon"):
		return _equipment.call("get_ranged_weapon") as Resource
	if slot == &"melee" and _equipment.has_method("get_melee_weapon"):
		return _equipment.call("get_melee_weapon") as Resource

	return null


func _equip_weapon_resource(slot: StringName, weapon: Resource) -> bool:
	if _equipment == null:
		return false
	if _equipment.has_method("equip_weapon"):
		return bool(_equipment.call("equip_weapon", slot, weapon))
	if slot == &"ranged" and _equipment.has_method("equip_ranged_weapon"):
		_equipment.call("equip_ranged_weapon", weapon)
		return true
	if slot == &"melee" and _equipment.has_method("equip_melee_weapon"):
		_equipment.call("equip_melee_weapon", weapon)
		return true

	return false


func _refresh_equipment(_slot: StringName = &"") -> void:
	if equipment_root == null:
		return

	_clear_children(equipment_root)
	_equipment_slot_nodes.clear()
	for slot_index in FIREARM_SLOT_IDS.size():
		_add_equipment_slot(FIREARM_SLOT_IDS[slot_index], "FIREARM %d" % [slot_index + 1])
	_add_equipment_slot(&"melee", "SUB")


func _add_equipment_slot(slot: StringName, slot_name: String) -> void:
	var slot_panel := Panel.new()
	slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	slot_panel.custom_minimum_size = Vector2(108, 52)
	var border_color := SLOT_ACTIVE_BORDER_COLOR if _is_active_firearm_slot(slot) else SLOT_BORDER_COLOR
	slot_panel.add_theme_stylebox_override("panel", _make_flat_style(SLOT_COLOR, border_color, 1))
	slot_panel.gui_input.connect(_on_equipment_slot_gui_input.bind(slot))
	slot_panel.mouse_entered.connect(_show_equipment_slot_details.bind(slot))
	slot_panel.mouse_exited.connect(_hide_detail_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	slot_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 4)
	margin.add_child(rows)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = slot_name
	title.add_theme_font_size_override("font_size", 8)
	title.modulate = SLOT_ACTIVE_BORDER_COLOR if _is_active_firearm_slot(slot) else Color(0.68, 0.70, 0.74, 1.0)
	rows.add_child(title)

	var value := Label.new()
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.text = _get_equipped_weapon_name(slot)
	value.add_theme_font_size_override("font_size", 10)
	value.clip_text = true
	rows.add_child(value)

	equipment_root.add_child(slot_panel)
	_equipment_slot_nodes[slot] = slot_panel


func _get_equipped_weapon_name(slot: StringName) -> String:
	var weapon: Resource = _get_equipped_weapon_for_slot(slot)
	if weapon == null:
		return "Empty"
	if _drag_source == DRAG_SOURCE_EQUIPMENT and _drag_equipment_slot == slot:
		return "Empty"

	return str(weapon.get("display_name"))


func _on_equipment_slot_gui_input(event: InputEvent, slot: StringName) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_begin_equipment_drag(slot)
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_show_equipment_context_menu(slot)
			get_viewport().set_input_as_handled()


func _show_equipment_context_menu(slot: StringName) -> void:
	if _equipment == null:
		return

	_hide_detail_panel()
	_hide_context_menu()
	_hide_split_dialog()

	var item_id: StringName = _get_equipped_item_id_for_slot(slot)
	var actions: Array[Dictionary] = []
	if item_id != &"" and _load_weapon_resource_for_item(item_id) != null:
		actions.append({"label": "Inspect", "action": &"inspect"})
	if item_id != &"":
		actions.append({"label": "Store", "action": &"store"})
	if actions.is_empty():
		actions.append({"label": "No Action", "action": &"none"})

	var menu_width := 156.0
	var row_height := 28.0
	var menu_height := 12.0 + float(actions.size()) * row_height + float(maxi(actions.size() - 1, 0)) * 4.0
	var menu := Panel.new()
	menu.name = "EquipmentContextMenu"
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.z_index = 60
	menu.size = Vector2(menu_width, menu_height)
	menu.custom_minimum_size = menu.size
	menu.add_theme_stylebox_override("panel", _make_flat_style(
		CONTEXT_MENU_COLOR,
		DETAIL_PANEL_BORDER_COLOR,
		1
	))
	root.add_child(menu)
	_context_menu = menu

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_STOP
	rows.position = Vector2(6, 6)
	rows.size = Vector2(menu_width - 12.0, menu_height - 12.0)
	rows.add_theme_constant_override("separation", 4)
	menu.add_child(rows)

	for action in actions:
		var action_name: StringName = action.get("action", &"none")
		var button := _create_context_menu_button(str(action.get("label", "Action")))
		button.disabled = action_name == &"none"
		if action_name == &"inspect":
			button.pressed.connect(Callable(self, "_on_equipment_inspect_pressed").bind(slot))
		elif action_name == &"store":
			button.pressed.connect(Callable(self, "_on_equipment_store_pressed").bind(slot))
		rows.add_child(button)

	_position_floating_panel(menu, get_viewport().get_mouse_position())


func _on_equipment_inspect_pressed(slot: StringName) -> void:
	_hide_context_menu()
	_hide_split_dialog()
	_show_weapon_inspect_for_equipment_slot(slot)


func _on_equipment_store_pressed(slot: StringName) -> void:
	_hide_context_menu()
	_hide_split_dialog()
	_store_equipped_slot(slot)


func _begin_equipment_drag(slot: StringName) -> void:
	if _inventory == null or _equipment == null:
		return

	_hide_detail_panel()
	_hide_context_menu()
	_hide_split_dialog()
	var item_id: StringName = _get_equipped_item_id_for_slot(slot)
	if item_id == &"":
		return

	var slot_node := _equipment_slot_nodes.get(slot) as Control
	if slot_node == null:
		return

	var definition: Dictionary = _inventory.get_item_definition(item_id)
	var item_size: Vector2i = definition.get("size", Vector2i.ONE)
	var local_mouse_position: Vector2 = slot_node.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
	var drag_size: Vector2 = _entry_pixel_size(item_size)

	_drag_source = DRAG_SOURCE_EQUIPMENT
	_drag_entry_id = -1
	_drag_equipment_slot = slot
	_drag_item_id = item_id
	_drag_item_size = item_size
	_drag_item_quantity = 1
	_drag_cell_offset = Vector2i.ZERO
	_drag_mouse_offset = Vector2(
		clampf(local_mouse_position.x, 0.0, drag_size.x),
		clampf(local_mouse_position.y, 0.0, drag_size.y)
	)

	_equipment_drag_node = _create_item_panel(definition, 1, item_size, true)
	_equipment_drag_node.z_index = 30
	root.add_child(_equipment_drag_node)

	_refresh_equipment()
	_update_drag_visual()


func _store_equipped_slot(slot: StringName) -> bool:
	if _inventory == null or _equipment == null:
		return false

	var item_id: StringName = _get_equipped_item_id_for_slot(slot)
	if item_id == &"":
		return false

	if not _inventory.can_add_item(item_id, 1):
		_show_warning("NO SPACE")
		return false

	var added_quantity: int = _inventory.add_item(item_id, 1)
	if added_quantity <= 0:
		_show_warning("NO SPACE")
		return false

	_equip_weapon_resource(slot, null)
	_refresh()
	return true


func _store_equipped_slot_at(slot: StringName, target_cell: Vector2i, item_size: Vector2i) -> bool:
	if _inventory == null or _equipment == null:
		return false

	var item_id: StringName = _get_equipped_item_id_for_slot(slot)
	if item_id == &"":
		return false

	var added_quantity: int = _inventory.add_item_at(item_id, 1, target_cell, item_size)
	if added_quantity <= 0:
		_show_warning("NO SPACE")
		return false

	_equip_weapon_resource(slot, null)
	_refresh()
	return true


func _drop_equipped_slot_to_world(slot: StringName) -> bool:
	if _equipment == null:
		return false

	var item_id: StringName = _get_equipped_item_id_for_slot(slot)
	if item_id == &"":
		return false

	if not _drop_item_to_world(item_id, 1):
		return false

	_equip_weapon_resource(slot, null)
	_refresh()
	return true


func _move_equipped_slot_to_slot(source_slot: StringName, target_slot: StringName) -> bool:
	if _equipment == null or source_slot == target_slot:
		return false

	var source_weapon := _get_equipped_weapon_for_slot(source_slot)
	if source_weapon == null:
		return false

	var source_item_id := StringName(source_weapon.get("weapon_id"))
	if not _does_slot_accept_item(target_slot, source_item_id):
		_show_warning("WRONG SLOT")
		return false

	var target_weapon := _get_equipped_weapon_for_slot(target_slot)
	if target_weapon != null:
		var target_item_id := StringName(target_weapon.get("weapon_id"))
		if not _does_slot_accept_item(source_slot, target_item_id):
			_show_warning("WRONG SLOT")
			return false

	_equip_weapon_resource(source_slot, target_weapon)
	_equip_weapon_resource(target_slot, source_weapon)
	_refresh()
	return true


func _is_firearm_slot(slot: StringName) -> bool:
	return slot in FIREARM_SLOT_IDS or slot == &"ranged"


func _get_active_firearm_slot() -> StringName:
	if _equipment != null and _equipment.has_method("get_active_firearm_slot"):
		return StringName(_equipment.call("get_active_firearm_slot"))

	return &"firearm_1"


func _is_active_firearm_slot(slot: StringName) -> bool:
	return _is_firearm_slot(slot) and slot == _get_active_firearm_slot()


func _get_quick_equip_slot_for_item_type(item_type: StringName) -> StringName:
	if item_type == &"ranged_weapon":
		var active_slot := _get_active_firearm_slot()
		if active_slot != &"" and _get_equipped_item_id_for_slot(active_slot) == &"":
			return active_slot

		for slot in FIREARM_SLOT_IDS:
			if _get_equipped_item_id_for_slot(slot) == &"":
				return slot
		return &""

	if item_type == &"melee_weapon":
		return &"melee" if _get_equipped_item_id_for_slot(&"melee") == &"" else &""

	return &""


func _get_comparison_slot_for_item_type(item_type: StringName) -> StringName:
	if item_type == &"ranged_weapon":
		return _get_active_firearm_slot()
	if item_type == &"melee_weapon":
		return &"melee"

	return &""


func _slot_for_item_type(item_type: StringName) -> StringName:
	if item_type == &"ranged_weapon":
		return _get_active_firearm_slot()
	if item_type == &"melee_weapon":
		return &"melee"

	return &""


func _does_slot_accept_item(slot: StringName, item_id: StringName) -> bool:
	if item_id == &"":
		return false

	var item_type := _get_item_type(item_id)
	if item_type == &"ranged_weapon":
		return _is_firearm_slot(slot)
	if item_type == &"melee_weapon":
		return slot == &"melee"

	return false


func _get_item_type(item_id: StringName) -> StringName:
	if _inventory == null:
		return &""

	var definition: Dictionary = _inventory.get_item_definition(item_id)
	return StringName(definition.get("type", &""))


func _get_drag_inventory() -> Node:
	if _drag_source == DRAG_SOURCE_EXTERNAL:
		return _external_inventory
	if _drag_source == DRAG_SOURCE_INVENTORY:
		return _inventory
	if _is_split_drag_source():
		return _get_split_drag_source_inventory()

	return _inventory


func _get_item_definition_for_inventory(source_inventory: Node, item_id: StringName) -> Dictionary:
	if source_inventory != null and source_inventory.has_method("get_item_definition"):
		return source_inventory.get_item_definition(item_id)
	if _inventory != null and _inventory.has_method("get_item_definition"):
		return _inventory.get_item_definition(item_id)

	return Inventory.get_item_definition_from_directory(item_id)


func _load_weapon_resource_for_item(item_id: StringName) -> Resource:
	if _inventory == null:
		return null

	var definition: Dictionary = _inventory.get_item_definition(item_id)
	var weapon_resource := definition.get("weapon_resource", null) as Resource
	if weapon_resource != null:
		return weapon_resource

	var resource_path: String = str(definition.get("weapon_resource_path", ""))
	if resource_path.is_empty():
		return null

	return ResourceLoader.load(resource_path) as Resource


func _show_warning(message: String) -> void:
	if warning_label == null:
		return

	if _warning_tween != null:
		_warning_tween.kill()

	warning_label.text = message
	warning_label.modulate = Color(1.0, 0.42, 0.32, 1.0)
	_warning_tween = create_tween()
	_warning_tween.tween_interval(1.35)
	_warning_tween.tween_property(warning_label, "modulate:a", 0.0, 0.35)
	_warning_tween.tween_callback(Callable(self, "_clear_warning"))


func _clear_warning() -> void:
	if warning_label == null:
		return

	warning_label.text = ""
	warning_label.modulate.a = 1.0


func _show_entry_details(entry_id: int) -> void:
	if _is_dragging() or _inventory == null:
		return

	var entry: Dictionary = _inventory.get_entry(entry_id)
	if entry.is_empty():
		return

	_hover_entry_id = entry_id
	_hover_equipment_slot = &""
	_show_item_details(
		entry.get("item_id", &""),
		int(entry.get("quantity", 1)),
		true,
		entry.get("size", Vector2i.ONE),
		entry.get("metadata", {})
	)


func _show_external_entry_details(entry_id: int) -> void:
	if _is_dragging() or _external_inventory == null:
		return

	var entry: Dictionary = _external_inventory.get_entry(entry_id)
	if entry.is_empty():
		return

	_hover_entry_id = -1
	_hover_equipment_slot = &""
	_show_item_details(
		entry.get("item_id", &""),
		int(entry.get("quantity", 1)),
		true,
		entry.get("size", Vector2i.ONE),
		entry.get("metadata", {})
	)


func _show_equipment_slot_details(slot: StringName) -> void:
	if _is_dragging() or _equipment == null:
		return

	_hover_entry_id = -1
	_hover_equipment_slot = slot
	var item_id: StringName = _get_equipped_item_id_for_slot(slot)
	if item_id == &"":
		_show_empty_slot_details(slot)
		return

	_show_item_details(item_id, 1, false)


func _show_item_details(
	item_id: StringName,
	quantity: int,
	compare_to_equipped: bool,
	display_size: Vector2i = Vector2i.ZERO,
	metadata: Dictionary = {}
) -> void:
	if item_id == &"" or _inventory == null:
		_hide_detail_panel()
		return

	var definition: Dictionary = _inventory.get_item_definition(item_id)
	var item_type: StringName = _get_item_type(item_id)
	var weapon: Resource = _load_weapon_resource_for_item(item_id)
	var compare_weapon: Resource = null
	var compare_slot: StringName = _get_comparison_slot_for_item_type(item_type)
	if compare_to_equipped:
		if compare_slot != &"":
			compare_weapon = _get_equipped_weapon_for_slot(compare_slot)

	_ensure_detail_panel()
	_populate_item_detail_card(
		_selected_detail_rows,
		"Selected",
		item_id,
		quantity,
		weapon,
		compare_weapon,
		display_size,
		metadata
	)

	var should_show_equipped := compare_to_equipped and weapon != null and compare_slot != &""
	_set_equipped_detail_visible(should_show_equipped)
	if should_show_equipped:
		if compare_weapon != null:
			var equipped_item_id := StringName(compare_weapon.get("weapon_id"))
			_populate_item_detail_card(_equipped_detail_rows, "Equipped", equipped_item_id, 1, compare_weapon, weapon)
		else:
			_populate_empty_detail_card(_equipped_detail_rows, "Equipped", compare_slot)

	_detail_panel.visible = true
	_position_detail_panel()


func _show_empty_slot_details(slot: StringName) -> void:
	_ensure_detail_panel()
	_set_equipped_detail_visible(false)
	_populate_empty_detail_card(_selected_detail_rows, "Equipped", slot)

	_detail_panel.visible = true
	_position_detail_panel()


func _hide_detail_panel() -> void:
	_hover_entry_id = -1
	_hover_equipment_slot = &""
	if is_instance_valid(_detail_panel):
		_detail_panel.visible = false


func _ensure_detail_panel() -> void:
	if is_instance_valid(_detail_panel):
		return

	_detail_panel = Control.new()
	_detail_panel.name = "ItemDetailRoot"
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.size = DETAIL_PANEL_SIZE
	_detail_panel.custom_minimum_size = DETAIL_PANEL_SIZE
	_detail_panel.z_index = 45
	_detail_panel.visible = false
	root.add_child(_detail_panel)

	_selected_detail_rows = _create_detail_card("SelectedDetailPanel", Vector2.ZERO)
	_equipped_detail_rows = _create_detail_card(
		"EquippedDetailPanel",
		Vector2(DETAIL_PANEL_SIZE.x + DETAIL_PANEL_GAP, 0.0)
	)
	_detail_rows = _selected_detail_rows
	_set_equipped_detail_visible(false)


func _create_detail_card(card_name: String, card_position: Vector2) -> VBoxContainer:
	var card := Panel.new()
	card.name = card_name
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.position = card_position
	card.size = DETAIL_PANEL_SIZE
	card.custom_minimum_size = DETAIL_PANEL_SIZE
	card.add_theme_stylebox_override("panel", _make_flat_style(
		DETAIL_PANEL_COLOR,
		DETAIL_PANEL_BORDER_COLOR,
		2
	))
	_detail_panel.add_child(card)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 6)
	margin.add_child(rows)
	if card_name == "SelectedDetailPanel":
		_selected_detail_panel = card
	elif card_name == "EquippedDetailPanel":
		_equipped_detail_panel = card

	return rows


func _set_equipped_detail_visible(is_visible: bool) -> void:
	if is_instance_valid(_equipped_detail_panel):
		_equipped_detail_panel.visible = is_visible

	var width := DETAIL_PANEL_SIZE.x
	if is_visible:
		width = DETAIL_PANEL_SIZE.x * 2.0 + DETAIL_PANEL_GAP
	_detail_panel.size = Vector2(width, DETAIL_PANEL_SIZE.y)
	_detail_panel.custom_minimum_size = _detail_panel.size


func _position_detail_panel() -> void:
	if not is_instance_valid(_detail_panel):
		return

	var margin := 16.0
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var detail_size: Vector2 = _detail_panel.size
	var panel_visual_size := panel.size * panel.scale
	var target_x: float = panel.global_position.x + panel_visual_size.x + margin
	if target_x + detail_size.x > viewport_size.x - margin:
		target_x = panel.global_position.x - detail_size.x - margin

	var target_y: float = panel.global_position.y
	_detail_panel.global_position = Vector2(
		clampf(target_x, margin, viewport_size.x - detail_size.x - margin),
		clampf(target_y, margin, viewport_size.y - detail_size.y - margin)
	)


func _on_player_damage_feedback(direction: Vector2) -> void:
	_show_damage_edge_flash(direction)
	if close_on_damage and _is_open:
		set_inventory_open(false)


func _ensure_damage_edge_flash() -> void:
	if is_instance_valid(_damage_edge_flash):
		return

	_damage_edge_flash = ColorRect.new()
	_damage_edge_flash.name = "DamageEdgeFlash"
	_damage_edge_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_edge_flash.color = Color(0.85, 0.04, 0.02, 0.0)
	_damage_edge_flash.z_index = 80
	add_child(_damage_edge_flash)


func _show_damage_edge_flash(direction: Vector2) -> void:
	_ensure_damage_edge_flash()

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var edge_width := minf(260.0, viewport_size.x * 0.22)
	var flash_from_left := direction.x >= 0.0
	_damage_edge_flash.position = Vector2(0.0 if flash_from_left else viewport_size.x - edge_width, 0.0)
	_damage_edge_flash.size = Vector2(edge_width, viewport_size.y)
	_damage_edge_flash.color = Color(0.85, 0.04, 0.02, 0.55)

	if _damage_flash_tween != null:
		_damage_flash_tween.kill()
	_damage_flash_tween = create_tween()
	_damage_flash_tween.tween_property(_damage_edge_flash, "color:a", 0.0, 0.28)


func _populate_item_detail_card(
	target_rows: VBoxContainer,
	card_label: String,
	item_id: StringName,
	quantity: int,
	weapon: Resource,
	compare_weapon: Resource,
	display_size: Vector2i = Vector2i.ZERO,
	metadata: Dictionary = {}
) -> void:
	var previous_rows := _detail_rows
	_detail_rows = target_rows
	_clear_children(_detail_rows)

	var definition: Dictionary = _inventory.get_item_definition(item_id)
	var item_type: StringName = _get_item_type(item_id)
	_add_detail_title(_get_detail_display_name(definition, weapon))
	if card_label == "Equipped" and weapon != null:
		_add_equipped_badge()
	_add_detail_note("%s  |  %s" % [card_label, _get_detail_type_line(definition, item_type, display_size)])
	_add_detail_separator()

	if quantity > 1:
		_add_detail_stat_row("Quantity", str(quantity))

	if weapon != null and item_type == &"ranged_weapon":
		_populate_ranged_weapon_details(weapon, compare_weapon)
	elif weapon != null and item_type == &"melee_weapon":
		_populate_melee_weapon_details(weapon, compare_weapon)
	else:
		_populate_generic_item_details(definition, quantity, display_size, metadata)

	_detail_rows = previous_rows


func _populate_empty_detail_card(target_rows: VBoxContainer, card_label: String, slot: StringName) -> void:
	var previous_rows := _detail_rows
	_detail_rows = target_rows
	_clear_children(_detail_rows)

	_add_detail_title("Empty " + _get_slot_display_name(slot))
	_add_detail_note("%s  |  Equipment Slot" % card_label)
	_add_detail_separator()
	_add_detail_stat_row("Slot", _get_slot_display_name(slot))

	_detail_rows = previous_rows


func _populate_ranged_weapon_details(weapon: Resource, compare_weapon: Resource) -> void:
	_add_detail_stat_row(
		"Damage",
		str(_get_resource_int(weapon, &"damage")),
		_get_resource_int(weapon, &"damage"),
		_get_compare_int(compare_weapon, &"damage"),
		true
	)
	_add_detail_stat_row(
		"Magazine",
		str(_get_resource_int(weapon, &"magazine_size")),
		_get_resource_int(weapon, &"magazine_size"),
		_get_compare_int(compare_weapon, &"magazine_size"),
		true
	)
	_add_detail_stat_row(
		"Chamber",
		str(_get_resource_int(weapon, &"chamber_size")),
		_get_resource_int(weapon, &"chamber_size"),
		_get_compare_int(compare_weapon, &"chamber_size"),
		true
	)
	_add_detail_stat_row(
		"Fire Interval",
		_format_seconds(_get_resource_float(weapon, &"fire_cooldown")),
		_get_resource_float(weapon, &"fire_cooldown"),
		_get_compare_float(compare_weapon, &"fire_cooldown"),
		false
	)
	_add_detail_stat_row(
		"Reload",
		_format_seconds(_get_resource_float(weapon, &"reload_time")),
		_get_resource_float(weapon, &"reload_time"),
		_get_compare_float(compare_weapon, &"reload_time"),
		false
	)
	_add_detail_stat_row(
		"Recoil",
		"%.2f" % _get_resource_float(weapon, &"recoil_amount"),
		_get_resource_float(weapon, &"recoil_amount"),
		_get_compare_float(compare_weapon, &"recoil_amount"),
		false
	)

	var ammo_id := StringName(weapon.get("ammo_item_id"))
	var ammo_definition: Dictionary = _inventory.get_item_definition(ammo_id)
	_add_detail_stat_row("Ammo", str(ammo_definition.get("name", ammo_id)))
	var magazine_id := StringName(weapon.get("magazine_item_id"))
	if magazine_id != &"":
		var magazine_definition: Dictionary = _inventory.get_item_definition(magazine_id)
		_add_detail_stat_row("Magazine Item", str(magazine_definition.get("name", magazine_id)))


func _populate_melee_weapon_details(weapon: Resource, compare_weapon: Resource) -> void:
	var combo_damages: Variant = weapon.get("combo_damages")
	var compare_combo_damages: Variant = null if compare_weapon == null else compare_weapon.get("combo_damages")
	_add_detail_stat_row(
		"Combo Damage",
		_format_combo_damages(combo_damages),
		_sum_combo_damages(combo_damages),
		_sum_combo_damages(compare_combo_damages),
		true
	)
	_add_detail_stat_row(
		"Stamina Cost",
		str(_get_resource_int(weapon, &"stamina_cost")),
		_get_resource_float(weapon, &"stamina_cost"),
		_get_compare_float(compare_weapon, &"stamina_cost"),
		false
	)
	_add_detail_stat_row(
		"Min Stamina",
		str(_get_resource_int(weapon, &"min_stamina_to_use")),
		_get_resource_float(weapon, &"min_stamina_to_use"),
		_get_compare_float(compare_weapon, &"min_stamina_to_use"),
		false
	)
	_add_detail_stat_row(
		"Lunge Speed",
		str(_get_resource_int(weapon, &"lunge_speed")),
		_get_resource_float(weapon, &"lunge_speed"),
		_get_compare_float(compare_weapon, &"lunge_speed"),
		true
	)
	_add_detail_stat_row(
		"Recovery",
		_format_seconds(_get_resource_float(weapon, &"recovery_time")),
		_get_resource_float(weapon, &"recovery_time"),
		_get_compare_float(compare_weapon, &"recovery_time"),
		false
	)


func _populate_generic_item_details(
	definition: Dictionary,
	quantity: int,
	display_size: Vector2i = Vector2i.ZERO,
	metadata: Dictionary = {}
) -> void:
	var item_size: Vector2i = _resolve_display_size(definition, display_size)
	_add_detail_stat_row("Grid Size", "%dx%d" % [item_size.x, item_size.y])
	if StringName(definition.get("type", &"")) == &"magazine":
		var capacity := int(definition.get("magazine_capacity", metadata.get("capacity", 0)))
		var ammo_count := int(metadata.get("ammo_count", 0))
		_add_detail_stat_row("Rounds", "%d / %d" % [ammo_count, capacity])
		var ammo_id := StringName(definition.get("ammo_item_id", metadata.get("ammo_item_id", &"")))
		if ammo_id != &"":
			var ammo_definition: Dictionary = _inventory.get_item_definition(ammo_id)
			_add_detail_stat_row("Ammo", str(ammo_definition.get("name", ammo_id)))
	_add_detail_stat_row("Stackable", "Yes" if bool(definition.get("stackable", false)) else "No")
	if bool(definition.get("stackable", false)):
		_add_detail_stat_row("Max Stack", str(int(definition.get("max_stack", quantity))))


func _add_detail_title(text: String) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.modulate = DETAIL_TEXT_COLOR
	label.add_theme_font_size_override("font_size", 17)
	label.clip_text = true
	_detail_rows.add_child(label)


func _add_detail_note(text: String) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.modulate = DETAIL_MUTED_COLOR
	label.add_theme_font_size_override("font_size", 11)
	label.clip_text = true
	_detail_rows.add_child(label)


func _add_equipped_badge() -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "【装備中】"
	label.modulate = DETAIL_EQUIPPED_COLOR
	label.add_theme_font_size_override("font_size", 12)
	label.clip_text = true
	_detail_rows.add_child(label)


func _add_detail_separator() -> void:
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_rows.add_child(separator)


func _add_detail_stat_row(
	stat_name: String,
	stat_value: String,
	value: Variant = null,
	compare_value: Variant = null,
	higher_is_better: bool = true
) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, 20)
	row.add_theme_constant_override("separation", 8)
	_detail_rows.add_child(row)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = stat_name
	name_label.modulate = DETAIL_MUTED_COLOR
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.text = stat_value
	value_label.modulate = _get_comparison_color(value, compare_value, higher_is_better)
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(128, 0)
	value_label.clip_text = true
	row.add_child(value_label)


func _get_comparison_color(value: Variant, compare_value: Variant, higher_is_better: bool) -> Color:
	if value == null or compare_value == null:
		return DETAIL_TEXT_COLOR
	if not _is_numeric(value) or not _is_numeric(compare_value):
		return DETAIL_TEXT_COLOR

	var delta := float(value) - float(compare_value)
	if absf(delta) <= 0.001:
		return DETAIL_TEXT_COLOR

	var is_better := delta > 0.0 if higher_is_better else delta < 0.0
	return DETAIL_BETTER_COLOR if is_better else DETAIL_WORSE_COLOR


func _is_numeric(value: Variant) -> bool:
	return value is int or value is float


func _get_detail_display_name(definition: Dictionary, weapon: Resource) -> String:
	if weapon != null:
		return str(weapon.get("display_name"))

	return str(definition.get("name", "Item"))


func _get_detail_type_line(
	definition: Dictionary,
	item_type: StringName,
	display_size: Vector2i = Vector2i.ZERO
) -> String:
	var item_size: Vector2i = _resolve_display_size(definition, display_size)
	var type_name := "Item"
	if item_type == &"ranged_weapon":
		type_name = "Firearm"
	elif item_type == &"melee_weapon":
		type_name = "Melee"
	elif bool(definition.get("stackable", false)):
		type_name = "Stack"

	return "%s  |  %dx%d" % [type_name, item_size.x, item_size.y]


func _resolve_display_size(definition: Dictionary, display_size: Vector2i) -> Vector2i:
	if display_size.x > 0 and display_size.y > 0:
		return display_size

	return definition.get("size", Vector2i.ONE)


func _get_slot_display_name(slot: StringName) -> String:
	if slot == &"ranged":
		return "Firearm"
	for slot_index in FIREARM_SLOT_IDS.size():
		if slot == FIREARM_SLOT_IDS[slot_index]:
			return "Firearm %d" % [slot_index + 1]
	if slot == &"melee":
		return "Sub"

	return "Slot"


func _get_resource_int(resource: Resource, property_name: StringName) -> int:
	return int(_get_resource_float(resource, property_name))


func _get_resource_float(resource: Resource, property_name: StringName) -> float:
	if resource == null:
		return 0.0

	var value: Variant = resource.get(property_name)
	if value == null:
		return 0.0

	return float(value)


func _get_compare_int(resource: Resource, property_name: StringName) -> Variant:
	if resource == null:
		return null

	return _get_resource_int(resource, property_name)


func _get_compare_float(resource: Resource, property_name: StringName) -> Variant:
	if resource == null:
		return null

	return _get_resource_float(resource, property_name)


func _format_seconds(value: float) -> String:
	return "%.2fs" % value


func _format_combo_damages(value: Variant) -> String:
	if value == null:
		return "-"

	var parts: Array[String] = []
	for damage in value:
		parts.append(str(int(damage)))

	return " / ".join(parts)


func _sum_combo_damages(value: Variant) -> Variant:
	if value == null:
		return null

	var total := 0
	for damage in value:
		total += int(damage)

	return total


func _entry_pixel_size(entry_size: Vector2i) -> Vector2:
	return Vector2(
		entry_size.x * CELL_PITCH - CELL_GAP,
		entry_size.y * CELL_PITCH - CELL_GAP
	)


func _get_item_label(
	definition: Dictionary,
	quantity: int,
	entry_size: Vector2i,
	metadata: Dictionary = {}
) -> String:
	var item_name: String = str(definition.get("short_name", definition.get("name", "Item")))
	if StringName(definition.get("type", &"")) == &"magazine" and metadata.has("ammo_count"):
		var capacity := int(definition.get("magazine_capacity", metadata.get("capacity", 0)))
		if capacity > 0:
			return "%s\n%d/%d" % [item_name, int(metadata.get("ammo_count", 0)), capacity]
		return "%s\n%d" % [item_name, int(metadata.get("ammo_count", 0))]
	if quantity > 1:
		if entry_size.x >= 2:
			return "%s x%d" % [item_name, quantity]
		return "%s\nx%d" % [item_name, quantity]
	return item_name


func _make_flat_style(background_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
