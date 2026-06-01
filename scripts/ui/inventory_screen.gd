extends CanvasLayer
class_name InventoryScreen

const CELL_SIZE: int = 48
const CELL_GAP: int = 2
const CELL_PITCH: int = CELL_SIZE + CELL_GAP
const CELL_COLOR := Color(0.16, 0.17, 0.19, 1.0)
const CELL_BORDER_COLOR := Color(0.36, 0.38, 0.42, 1.0)
const ITEM_BORDER_COLOR := Color(0.9, 0.92, 0.84, 1.0)

@export var player_path: NodePath = NodePath("../Player")

@onready var grid_root: Control = $Root/Panel/Margin/Rows/GridRoot
@onready var cells_root: Control = $Root/Panel/Margin/Rows/GridRoot/CellsRoot
@onready var items_root: Control = $Root/Panel/Margin/Rows/GridRoot/ItemsRoot
@onready var preview: ColorRect = $Root/Panel/Margin/Rows/GridRoot/Preview

var _inventory: Node
var _item_nodes: Dictionary = {}
var _drag_entry_id: int = -1
var _drag_mouse_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	preview.visible = false

	var player := get_node_or_null(player_path)
	if player != null:
		_inventory = player.get_node_or_null("Inventory")

	if _inventory != null:
		if _inventory.has_signal("grid_changed"):
			_inventory.grid_changed.connect(_refresh)
		_build_grid_cells()
		_refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		set_inventory_open(not visible)
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return

	if _drag_entry_id >= 0:
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

	_clear_children(items_root)
	_item_nodes.clear()

	for entry in _inventory.get_entries():
		var entry_id: int = int(entry.get("entry_id", -1))
		if entry_id < 0 or entry_id == _drag_entry_id:
			continue

		_add_item_node(entry)

	if _drag_entry_id >= 0:
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

	var item_panel := Panel.new()
	item_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	item_panel.position = _grid_to_local(position)
	item_panel.size = _entry_pixel_size(size)
	item_panel.custom_minimum_size = Vector2.ZERO
	item_panel.clip_contents = true
	item_panel.z_index = 20 if is_dragged else 5
	item_panel.gui_input.connect(_on_item_gui_input.bind(entry_id))
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
	label.text = _get_item_label(definition, quantity)
	label.add_theme_font_size_override("font_size", 9)
	item_panel.add_child(label)

	items_root.add_child(item_panel)
	_item_nodes[entry_id] = item_panel


func _on_item_gui_input(event: InputEvent, entry_id: int) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_begin_drag(entry_id)
			get_viewport().set_input_as_handled()


func _begin_drag(entry_id: int) -> void:
	if _inventory == null or not _item_nodes.has(entry_id):
		return

	_drag_entry_id = entry_id
	var item_node := _item_nodes[entry_id] as Control
	_drag_mouse_offset = get_viewport().get_mouse_position() - item_node.global_position
	_refresh()


func _update_drag_visual() -> void:
	if _drag_entry_id < 0 or not _item_nodes.has(_drag_entry_id):
		return

	var item_node := _item_nodes[_drag_entry_id] as Control
	item_node.global_position = get_viewport().get_mouse_position() - _drag_mouse_offset

	var target_cell: Vector2i = _global_to_grid(item_node.global_position)
	var entry: Dictionary = _inventory.get_entry(_drag_entry_id)
	var entry_size: Vector2i = entry.get("size", Vector2i.ONE)
	preview.visible = true
	preview.position = _grid_to_local(target_cell)
	preview.size = _entry_pixel_size(entry_size)
	preview.color = Color(0.28, 0.82, 0.34, 0.34) if _inventory.can_place(_drag_entry_id, target_cell) else Color(0.9, 0.12, 0.1, 0.42)


func _finish_drag() -> void:
	if _drag_entry_id < 0 or _inventory == null:
		_cancel_drag()
		return

	var target_cell := Vector2i.ZERO
	if _item_nodes.has(_drag_entry_id):
		var item_node := _item_nodes[_drag_entry_id] as Control
		target_cell = _global_to_grid(item_node.global_position)

	_inventory.move_entry(_drag_entry_id, target_cell)
	_cancel_drag()
	_refresh()


func _cancel_drag() -> void:
	_drag_entry_id = -1
	_drag_mouse_offset = Vector2.ZERO
	preview.visible = false


func _grid_to_local(grid_position: Vector2i) -> Vector2:
	return Vector2(grid_position.x * CELL_PITCH, grid_position.y * CELL_PITCH)


func _global_to_grid(global_position: Vector2) -> Vector2i:
	var local_position: Vector2 = grid_root.get_global_transform().affine_inverse() * global_position
	return Vector2i(floori(local_position.x / CELL_PITCH), floori(local_position.y / CELL_PITCH))


func _entry_pixel_size(entry_size: Vector2i) -> Vector2:
	return Vector2(
		entry_size.x * CELL_PITCH - CELL_GAP,
		entry_size.y * CELL_PITCH - CELL_GAP
	)


func _get_item_label(definition: Dictionary, quantity: int) -> String:
	var item_name: String = str(definition.get("short_name", definition.get("name", "Item")))
	if quantity > 1:
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
