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
const SLOT_PLACEABLE_COLOR := Color(0.18, 0.82, 0.35, 0.32)
const SLOT_BLOCKED_COLOR := Color(0.95, 0.12, 0.1, 0.34)
const DETAIL_PANEL_SIZE := Vector2(306, 318)
const DETAIL_PANEL_COLOR := Color(0.09, 0.095, 0.108, 0.98)
const DETAIL_PANEL_BORDER_COLOR := Color(0.42, 0.44, 0.48, 1.0)
const DETAIL_TEXT_COLOR := Color(0.9, 0.92, 0.9, 1.0)
const DETAIL_MUTED_COLOR := Color(0.62, 0.65, 0.68, 1.0)
const DETAIL_BETTER_COLOR := Color(0.34, 0.92, 0.48, 1.0)
const DETAIL_WORSE_COLOR := Color(0.95, 0.32, 0.28, 1.0)
const DRAG_SOURCE_NONE := &""
const DRAG_SOURCE_INVENTORY := &"inventory"
const DRAG_SOURCE_EQUIPMENT := &"equipment"

@export var player_path: NodePath = NodePath("../Player")
@export var dropped_item_scene: PackedScene

@onready var root: Control = $Root
@onready var panel: Control = $Root/Panel
@onready var equipment_root: HBoxContainer = $Root/Panel/Margin/Rows/EquipmentRoot
@onready var grid_root: Control = $Root/Panel/Margin/Rows/GridRoot
@onready var cells_root: Control = $Root/Panel/Margin/Rows/GridRoot/CellsRoot
@onready var items_root: Control = $Root/Panel/Margin/Rows/GridRoot/ItemsRoot
@onready var placement_root: Control = $Root/Panel/Margin/Rows/GridRoot/PlacementRoot
@onready var warning_label: Label = $Root/Panel/Margin/Rows/WarningLabel

var _player: Node2D
var _inventory: Node
var _equipment: Node
var _item_nodes: Dictionary = {}
var _equipment_slot_nodes: Dictionary = {}
var _drag_source: StringName = DRAG_SOURCE_NONE
var _drag_entry_id: int = -1
var _drag_equipment_slot: StringName = &""
var _drag_item_id: StringName = &""
var _drag_cell_offset: Vector2i = Vector2i.ZERO
var _drag_mouse_offset: Vector2 = Vector2.ZERO
var _equipment_drag_node: Control
var _placement_markers: Array[ColorRect] = []
var _slot_preview: ColorRect
var _warning_tween: Tween
var _detail_panel: Panel
var _detail_rows: VBoxContainer
var _hover_entry_id: int = -1
var _hover_equipment_slot: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var player := get_node_or_null(player_path)
	if player != null:
		_player = player as Node2D
		_inventory = player.get_node_or_null("Inventory")
		_equipment = player.get_node_or_null("Equipment")

	if _inventory != null:
		if _inventory.has_signal("grid_changed"):
			_inventory.grid_changed.connect(_refresh)
		_build_grid_cells()
		_refresh()

	if _equipment != null and _equipment.has_signal("equipment_changed"):
		_equipment.connect("equipment_changed", Callable(self, "_refresh_equipment"))
	_refresh_equipment()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		set_inventory_open(not visible)
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return

	if _is_dragging():
		if event is InputEventMouseMotion:
			_update_drag_visual()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			var mouse_button := event as InputEventMouseButton
			if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
				_finish_drag()
				get_viewport().set_input_as_handled()


func set_inventory_open(is_open: bool) -> void:
	visible = is_open
	get_tree().paused = is_open

	if is_open:
		_refresh()
	else:
		_cancel_drag()
		_hide_detail_panel()


func _build_grid_cells() -> void:
	_clear_children(cells_root)

	var grid_size: Vector2i = _inventory.get_grid_size()
	grid_root.custom_minimum_size = Vector2(
		grid_size.x * CELL_PITCH - CELL_GAP,
		grid_size.y * CELL_PITCH - CELL_GAP
	)

	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Panel.new()
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.position = Vector2(x * CELL_PITCH, y * CELL_PITCH)
			cell.size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.add_theme_stylebox_override("panel", _make_flat_style(CELL_COLOR, CELL_BORDER_COLOR, 1))
			cells_root.add_child(cell)


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


func _add_item_node(entry: Dictionary, is_dragged: bool = false) -> void:
	var entry_id: int = int(entry.get("entry_id", -1))
	var item_id: StringName = entry.get("item_id", &"")
	var position: Vector2i = entry.get("position", Vector2i.ZERO)
	var size: Vector2i = entry.get("size", Vector2i.ONE)
	var quantity: int = int(entry.get("quantity", 1))
	var definition: Dictionary = _inventory.get_item_definition(item_id)

	var item_panel := _create_item_panel(definition, quantity, size, is_dragged)
	item_panel.position = _grid_to_local(position)
	item_panel.z_index = 20 if is_dragged else 5
	item_panel.gui_input.connect(_on_item_gui_input.bind(entry_id))
	if not is_dragged:
		item_panel.mouse_entered.connect(_show_entry_details.bind(entry_id))
		item_panel.mouse_exited.connect(_hide_detail_panel)

	items_root.add_child(item_panel)
	_item_nodes[entry_id] = item_panel


func _create_item_panel(definition: Dictionary, quantity: int, size: Vector2i, is_dragged: bool = false) -> Panel:
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
	label.text = _get_item_label(definition, quantity, size)
	label.add_theme_font_size_override("font_size", 9)
	item_panel.add_child(label)

	return item_panel


func _on_item_gui_input(event: InputEvent, entry_id: int) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_begin_drag(entry_id)
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_try_quick_equip_entry(entry_id)
			get_viewport().set_input_as_handled()


func _begin_drag(entry_id: int) -> void:
	if _inventory == null or not _item_nodes.has(entry_id):
		return

	_hide_detail_panel()
	_drag_source = DRAG_SOURCE_INVENTORY
	_drag_entry_id = entry_id
	_drag_equipment_slot = &""
	var item_node := _item_nodes[entry_id] as Control
	var entry: Dictionary = _inventory.get_entry(entry_id)
	var entry_size: Vector2i = entry.get("size", Vector2i.ONE)
	_drag_item_id = entry.get("item_id", &"")
	var local_mouse_position: Vector2 = item_node.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
	_drag_mouse_offset = get_viewport().get_mouse_position() - item_node.global_position
	_drag_cell_offset = Vector2i(
		clampi(floori(local_mouse_position.x / CELL_PITCH), 0, entry_size.x - 1),
		clampi(floori(local_mouse_position.y / CELL_PITCH), 0, entry_size.y - 1)
	)
	_refresh()


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

	var target_cell := Vector2i.ZERO
	target_cell = _get_drag_target_cell()
	var target_slot: StringName = _get_equipment_slot_under_mouse()

	if _drag_source == DRAG_SOURCE_INVENTORY:
		if target_slot != &"":
			_equip_inventory_entry_to_slot(_drag_entry_id, target_slot)
		elif _is_mouse_inside_grid():
			_inventory.move_entry(_drag_entry_id, target_cell)
		elif not _is_mouse_inside_inventory_frame():
			_drop_dragged_inventory_entry_to_world()
	elif _drag_source == DRAG_SOURCE_EQUIPMENT:
		if _is_mouse_inside_grid():
			_store_equipped_slot_at(_drag_equipment_slot, target_cell)
		elif not _is_mouse_inside_inventory_frame():
			_drop_equipped_slot_to_world(_drag_equipment_slot)
	_cancel_drag()
	_refresh()


func _cancel_drag() -> void:
	if is_instance_valid(_equipment_drag_node):
		_equipment_drag_node.queue_free()

	_drag_source = DRAG_SOURCE_NONE
	_drag_entry_id = -1
	_drag_equipment_slot = &""
	_drag_item_id = &""
	_drag_cell_offset = Vector2i.ZERO
	_drag_mouse_offset = Vector2.ZERO
	_equipment_drag_node = null
	_clear_placement_markers()
	_clear_slot_preview()
	_refresh_equipment()


func _is_dragging() -> bool:
	return _drag_source != DRAG_SOURCE_NONE


func _get_drag_node() -> Control:
	if _drag_source == DRAG_SOURCE_INVENTORY and _item_nodes.has(_drag_entry_id):
		return _item_nodes[_drag_entry_id] as Control
	if _drag_source == DRAG_SOURCE_EQUIPMENT and is_instance_valid(_equipment_drag_node):
		return _equipment_drag_node

	return null


func _get_drag_item_size() -> Vector2i:
	if _drag_source == DRAG_SOURCE_INVENTORY:
		var entry: Dictionary = _inventory.get_entry(_drag_entry_id)
		return entry.get("size", Vector2i.ONE)

	var definition: Dictionary = _inventory.get_item_definition(_drag_item_id)
	return definition.get("size", Vector2i.ONE)


func _grid_to_local(grid_position: Vector2i) -> Vector2:
	return Vector2(grid_position.x * CELL_PITCH, grid_position.y * CELL_PITCH)


func _global_to_grid(global_position: Vector2) -> Vector2i:
	var local_position: Vector2 = grid_root.get_global_transform().affine_inverse() * global_position
	return Vector2i(floori(local_position.x / CELL_PITCH), floori(local_position.y / CELL_PITCH))


func _get_drag_target_cell() -> Vector2i:
	return _global_to_grid(get_viewport().get_mouse_position()) - _drag_cell_offset


func _is_mouse_inside_grid() -> bool:
	var local_position: Vector2 = grid_root.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
	var grid_size: Vector2 = grid_root.custom_minimum_size
	return Rect2(Vector2.ZERO, grid_size).has_point(local_position)


func _is_mouse_inside_inventory_frame() -> bool:
	var local_position: Vector2 = panel.get_global_transform().affine_inverse() * get_viewport().get_mouse_position()
	return Rect2(Vector2.ZERO, panel.size).has_point(local_position)


func _get_equipment_slot_under_mouse() -> StringName:
	var mouse_position := get_viewport().get_mouse_position()
	for slot in _equipment_slot_nodes:
		var slot_node := _equipment_slot_nodes[slot] as Control
		if slot_node == null:
			continue

		var local_position: Vector2 = slot_node.get_global_transform().affine_inverse() * mouse_position
		if Rect2(Vector2.ZERO, slot_node.size).has_point(local_position):
			return slot

	return &""


func _update_placement_markers(target_cell: Vector2i, entry_size: Vector2i) -> void:
	_clear_placement_markers()

	if not _is_mouse_inside_grid():
		return

	for y in entry_size.y:
		for x in entry_size.x:
			var cell := target_cell + Vector2i(x, y)
			var marker := ColorRect.new()
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marker.position = _grid_to_local(cell)
			marker.size = Vector2(CELL_SIZE, CELL_SIZE)
			var ignored_entry_id: int = _drag_entry_id if _drag_source == DRAG_SOURCE_INVENTORY else -1
			marker.color = PLACEABLE_COLOR if _inventory.is_cell_free(cell, ignored_entry_id) else BLOCKED_COLOR
			placement_root.add_child(marker)
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

	return _drop_item_to_world(dropped_entry.get("item_id", &""), int(dropped_entry.get("quantity", 1)))


func _drop_item_to_world(item_id: StringName, quantity: int = 1) -> bool:
	if dropped_item_scene == null or _player == null:
		return false

	var dropped_item := dropped_item_scene.instantiate()
	dropped_item.set("item_id", item_id)
	dropped_item.set("quantity", quantity)

	var drop_parent: Node = get_tree().current_scene
	if drop_parent == null:
		drop_parent = _player.get_parent()
	drop_parent.add_child(dropped_item)

	if dropped_item is Node2D:
		var dropped_item_2d := dropped_item as Node2D
		dropped_item_2d.global_position = _player.global_position + Vector2(28, -10)

	return true


func _try_quick_equip_entry(entry_id: int) -> bool:
	if _inventory == null or _equipment == null:
		return false

	var entry: Dictionary = _inventory.get_entry(entry_id)
	if entry.is_empty():
		return false

	var item_id: StringName = entry.get("item_id", &"")
	var definition: Dictionary = _inventory.get_item_definition(item_id)
	var item_type: StringName = definition.get("type", &"")
	var target_slot: StringName = _slot_for_item_type(item_type)
	if target_slot == &"":
		return false

	if _get_equipped_item_id_for_slot(target_slot) != &"":
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
	_add_equipment_slot(&"ranged", "SIDEARM")
	_add_equipment_slot(&"melee", "MELEE")


func _add_equipment_slot(slot: StringName, slot_name: String) -> void:
	var slot_panel := Panel.new()
	slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	slot_panel.custom_minimum_size = Vector2(243, 62)
	slot_panel.add_theme_stylebox_override("panel", _make_flat_style(SLOT_COLOR, SLOT_BORDER_COLOR, 1))
	slot_panel.gui_input.connect(_on_equipment_slot_gui_input.bind(slot))
	slot_panel.mouse_entered.connect(_show_equipment_slot_details.bind(slot))
	slot_panel.mouse_exited.connect(_hide_detail_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	slot_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 4)
	margin.add_child(rows)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = slot_name
	title.add_theme_font_size_override("font_size", 9)
	title.modulate = Color(0.68, 0.70, 0.74, 1.0)
	rows.add_child(title)

	var value := Label.new()
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.text = _get_equipped_weapon_name(slot)
	value.add_theme_font_size_override("font_size", 13)
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
			_store_equipped_slot(slot)
			get_viewport().set_input_as_handled()


func _begin_equipment_drag(slot: StringName) -> void:
	if _inventory == null or _equipment == null:
		return

	_hide_detail_panel()
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


func _store_equipped_slot_at(slot: StringName, target_cell: Vector2i) -> bool:
	if _inventory == null or _equipment == null:
		return false

	var item_id: StringName = _get_equipped_item_id_for_slot(slot)
	if item_id == &"":
		return false

	var added_quantity: int = _inventory.add_item_at(item_id, 1, target_cell)
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


func _slot_for_item_type(item_type: StringName) -> StringName:
	if item_type == &"ranged_weapon":
		return &"ranged"
	if item_type == &"melee_weapon":
		return &"melee"

	return &""


func _does_slot_accept_item(slot: StringName, item_id: StringName) -> bool:
	if item_id == &"":
		return false

	return _slot_for_item_type(_get_item_type(item_id)) == slot


func _get_item_type(item_id: StringName) -> StringName:
	if _inventory == null:
		return &""

	var definition: Dictionary = _inventory.get_item_definition(item_id)
	return StringName(definition.get("type", &""))


func _load_weapon_resource_for_item(item_id: StringName) -> Resource:
	if _inventory == null:
		return null

	var definition: Dictionary = _inventory.get_item_definition(item_id)
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
	_show_item_details(entry.get("item_id", &""), int(entry.get("quantity", 1)), true)


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


func _show_item_details(item_id: StringName, quantity: int, compare_to_equipped: bool) -> void:
	if item_id == &"" or _inventory == null:
		_hide_detail_panel()
		return

	var definition: Dictionary = _inventory.get_item_definition(item_id)
	var item_type: StringName = _get_item_type(item_id)
	var weapon: Resource = _load_weapon_resource_for_item(item_id)
	var compare_weapon: Resource = null
	if compare_to_equipped:
		var compare_slot: StringName = _slot_for_item_type(item_type)
		if compare_slot != &"":
			compare_weapon = _get_equipped_weapon_for_slot(compare_slot)

	_ensure_detail_panel()
	_clear_children(_detail_rows)

	_add_detail_title(_get_detail_display_name(definition, weapon))
	_add_detail_note(_get_detail_type_line(definition, item_type))
	if compare_weapon != null:
		_add_detail_note("VS " + str(compare_weapon.get("display_name")))
	_add_detail_separator()

	if quantity > 1:
		_add_detail_stat_row("Quantity", str(quantity))

	if weapon != null and item_type == &"ranged_weapon":
		_populate_ranged_weapon_details(weapon, compare_weapon)
	elif weapon != null and item_type == &"melee_weapon":
		_populate_melee_weapon_details(weapon, compare_weapon)
	else:
		_populate_generic_item_details(definition, quantity)

	_detail_panel.visible = true
	_position_detail_panel()


func _show_empty_slot_details(slot: StringName) -> void:
	_ensure_detail_panel()
	_clear_children(_detail_rows)

	_add_detail_title("Empty " + _get_slot_display_name(slot))
	_add_detail_note("Equipment Slot")
	_add_detail_separator()
	_add_detail_stat_row("Slot", _get_slot_display_name(slot))

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

	_detail_panel = Panel.new()
	_detail_panel.name = "ItemDetailPanel"
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_panel.size = DETAIL_PANEL_SIZE
	_detail_panel.custom_minimum_size = DETAIL_PANEL_SIZE
	_detail_panel.z_index = 45
	_detail_panel.visible = false
	_detail_panel.add_theme_stylebox_override("panel", _make_flat_style(
		DETAIL_PANEL_COLOR,
		DETAIL_PANEL_BORDER_COLOR,
		2
	))
	root.add_child(_detail_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_detail_panel.add_child(margin)

	_detail_rows = VBoxContainer.new()
	_detail_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_rows.add_theme_constant_override("separation", 6)
	margin.add_child(_detail_rows)


func _position_detail_panel() -> void:
	if not is_instance_valid(_detail_panel):
		return

	var margin := 16.0
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var target_x: float = panel.global_position.x + panel.size.x + margin
	if target_x + DETAIL_PANEL_SIZE.x > viewport_size.x - margin:
		target_x = panel.global_position.x - DETAIL_PANEL_SIZE.x - margin

	var target_y: float = panel.global_position.y
	_detail_panel.global_position = Vector2(
		clampf(target_x, margin, viewport_size.x - DETAIL_PANEL_SIZE.x - margin),
		clampf(target_y, margin, viewport_size.y - DETAIL_PANEL_SIZE.y - margin)
	)


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


func _populate_generic_item_details(definition: Dictionary, quantity: int) -> void:
	var item_size: Vector2i = definition.get("size", Vector2i.ONE)
	_add_detail_stat_row("Grid Size", "%dx%d" % [item_size.x, item_size.y])
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


func _get_detail_type_line(definition: Dictionary, item_type: StringName) -> String:
	var item_size: Vector2i = definition.get("size", Vector2i.ONE)
	var type_name := "Item"
	if item_type == &"ranged_weapon":
		type_name = "Sidearm"
	elif item_type == &"melee_weapon":
		type_name = "Melee"
	elif bool(definition.get("stackable", false)):
		type_name = "Stack"

	return "%s  |  %dx%d" % [type_name, item_size.x, item_size.y]


func _get_slot_display_name(slot: StringName) -> String:
	if slot == &"ranged":
		return "Sidearm"
	if slot == &"melee":
		return "Melee"

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


func _get_item_label(definition: Dictionary, quantity: int, entry_size: Vector2i) -> String:
	var item_name: String = str(definition.get("short_name", definition.get("name", "Item")))
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
