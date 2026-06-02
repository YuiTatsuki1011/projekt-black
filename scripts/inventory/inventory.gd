extends Node
class_name Inventory

signal item_quantity_changed(item_id: StringName, quantity: int)
signal grid_changed

const DEFAULT_ITEM_RESOURCE_DIRECTORY := "res://resources/items"

@export var grid_width: int = 10
@export var grid_height: int = 8
@export_dir var item_resource_directory: String = DEFAULT_ITEM_RESOURCE_DIRECTORY
@export var starting_items: Dictionary = {}

static var _definition_cache_by_directory: Dictionary = {}

var _items: Dictionary = {}
var _entries: Dictionary = {}
var _next_entry_id: int = 1


func _ready() -> void:
	for item_id in starting_items:
		var quantity := int(starting_items[item_id])
		if quantity > 0:
			add_item(StringName(str(item_id)), quantity)


func get_quantity(item_id: StringName) -> int:
	return int(_items.get(item_id, 0))


func add_item(item_id: StringName, quantity: int) -> int:
	if quantity <= 0:
		return 0

	var remaining_quantity: int = quantity
	var added_quantity: int = 0
	var definition: Dictionary = get_item_definition(item_id)
	var item_size: Vector2i = definition.get("size", Vector2i.ONE)
	var is_stackable: bool = bool(definition.get("stackable", false))
	var max_stack: int = int(definition.get("max_stack", 1))

	if is_stackable:
		for entry_id in _entries:
			var entry: Dictionary = _entries[entry_id]
			if entry.get("item_id") != item_id:
				continue

			var entry_quantity: int = int(entry.get("quantity", 0))
			var available_space: int = max_stack - entry_quantity
			if available_space <= 0:
				continue

			var amount_to_add: int = mini(available_space, remaining_quantity)
			entry["quantity"] = entry_quantity + amount_to_add
			_entries[entry_id] = entry
			remaining_quantity -= amount_to_add
			added_quantity += amount_to_add
			if remaining_quantity <= 0:
				break

	while remaining_quantity > 0:
		var position: Vector2i = _find_first_free_position(item_size)
		if position.x < 0:
			break

		var stack_quantity: int = mini(max_stack, remaining_quantity) if is_stackable else 1
		_create_entry(item_id, position, item_size, stack_quantity)
		remaining_quantity -= stack_quantity
		added_quantity += stack_quantity

	if added_quantity > 0:
		_set_total_quantity(item_id, get_quantity(item_id) + added_quantity)
		grid_changed.emit()

	return added_quantity


func add_item_at(
	item_id: StringName,
	quantity: int,
	position: Vector2i,
	size_override: Vector2i = Vector2i.ZERO
) -> int:
	if quantity <= 0:
		return 0

	var definition: Dictionary = get_item_definition(item_id)
	var item_size: Vector2i = definition.get("size", Vector2i.ONE)
	if size_override.x > 0 and size_override.y > 0:
		item_size = size_override
	var is_stackable: bool = bool(definition.get("stackable", false))
	var max_stack: int = int(definition.get("max_stack", 1))
	var stack_quantity: int = mini(max_stack, quantity) if is_stackable else 1

	if not _is_area_free(position, item_size):
		return 0

	_create_entry(item_id, position, item_size, stack_quantity)
	_set_total_quantity(item_id, get_quantity(item_id) + stack_quantity)
	grid_changed.emit()
	return stack_quantity


func can_add_item(item_id: StringName, quantity: int = 1) -> bool:
	if quantity <= 0:
		return true

	var remaining_quantity: int = quantity
	var definition: Dictionary = get_item_definition(item_id)
	var item_size: Vector2i = definition.get("size", Vector2i.ONE)
	var is_stackable: bool = bool(definition.get("stackable", false))
	var max_stack: int = int(definition.get("max_stack", 1))
	var occupied_rects: Array[Rect2i] = []

	for entry_id in _entries:
		var entry: Dictionary = _entries[entry_id]
		occupied_rects.append(Rect2i(entry.get("position", Vector2i.ZERO), entry.get("size", Vector2i.ONE)))

		if not is_stackable or entry.get("item_id") != item_id:
			continue

		var entry_quantity: int = int(entry.get("quantity", 0))
		remaining_quantity -= maxi(max_stack - entry_quantity, 0)
		if remaining_quantity <= 0:
			return true

	while remaining_quantity > 0:
		var position: Vector2i = _find_first_free_position_with_rects(item_size, occupied_rects)
		if position.x < 0:
			return false

		occupied_rects.append(Rect2i(position, item_size))
		remaining_quantity -= mini(max_stack, remaining_quantity) if is_stackable else 1

	return true


func remove_item(item_id: StringName, quantity: int) -> int:
	if quantity <= 0:
		return 0

	var remaining_quantity: int = quantity
	var removed_quantity: int = 0
	var entry_ids: Array = _entries.keys()
	entry_ids.reverse()

	for entry_id in entry_ids:
		var entry: Dictionary = _entries[entry_id]
		if entry.get("item_id") != item_id:
			continue

		var entry_quantity: int = int(entry.get("quantity", 0))
		var amount_to_remove: int = mini(entry_quantity, remaining_quantity)
		entry_quantity -= amount_to_remove
		remaining_quantity -= amount_to_remove
		removed_quantity += amount_to_remove

		if entry_quantity <= 0:
			_entries.erase(entry_id)
		else:
			entry["quantity"] = entry_quantity
			_entries[entry_id] = entry

		if remaining_quantity <= 0:
			break

	if removed_quantity <= 0:
		return 0

	_set_total_quantity(item_id, get_quantity(item_id) - removed_quantity)
	grid_changed.emit()
	return removed_quantity


func remove_entry(entry_id: int) -> Dictionary:
	if not _entries.has(entry_id):
		return {}

	var entry: Dictionary = _entries[entry_id].duplicate(true)
	_entries.erase(entry_id)

	var item_id: StringName = entry.get("item_id", &"")
	var quantity: int = int(entry.get("quantity", 0))
	_set_total_quantity(item_id, get_quantity(item_id) - quantity)
	grid_changed.emit()

	entry["entry_id"] = entry_id
	return entry


func has_item(item_id: StringName, quantity: int = 1) -> bool:
	return get_quantity(item_id) >= quantity


func get_grid_size() -> Vector2i:
	return Vector2i(grid_width, grid_height)


func get_item_definition(item_id: StringName) -> Dictionary:
	return get_item_definition_from_directory(item_id, item_resource_directory)


static func get_item_definition_from_directory(
	item_id: StringName,
	item_directory: String = DEFAULT_ITEM_RESOURCE_DIRECTORY
) -> Dictionary:
	var definitions := _get_item_definitions(item_directory)
	if definitions.has(item_id):
		return definitions[item_id]

	return _get_fallback_item_definition(item_id)


static func reload_item_definitions(item_directory: String = DEFAULT_ITEM_RESOURCE_DIRECTORY) -> void:
	_definition_cache_by_directory.erase(item_directory)


func get_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry_id in _entries:
		var entry: Dictionary = _entries[entry_id].duplicate(true)
		entry["entry_id"] = int(entry_id)
		entries.append(entry)

	return entries


func get_entry(entry_id: int) -> Dictionary:
	if not _entries.has(entry_id):
		return {}

	var entry: Dictionary = _entries[entry_id].duplicate(true)
	entry["entry_id"] = entry_id
	return entry


func can_place(entry_id: int, position: Vector2i, size_override: Vector2i = Vector2i.ZERO) -> bool:
	if not _entries.has(entry_id):
		return false

	var entry: Dictionary = _entries[entry_id]
	var item_size: Vector2i = entry.get("size", Vector2i.ONE)
	if size_override.x > 0 and size_override.y > 0:
		item_size = size_override

	return _is_area_free(position, item_size, entry_id)


func is_cell_free(cell: Vector2i, ignored_entry_id: int = -1) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_width or cell.y >= grid_height:
		return false

	var checked_rect := Rect2i(cell, Vector2i.ONE)
	for entry_id in _entries:
		if int(entry_id) == ignored_entry_id:
			continue

		var entry: Dictionary = _entries[entry_id]
		var entry_rect := Rect2i(entry.get("position", Vector2i.ZERO), entry.get("size", Vector2i.ONE))
		if checked_rect.intersects(entry_rect):
			return false

	return true


func move_entry(entry_id: int, position: Vector2i, size_override: Vector2i = Vector2i.ZERO) -> bool:
	if not can_place(entry_id, position, size_override):
		return false

	var entry: Dictionary = _entries[entry_id]
	entry["position"] = position
	if size_override.x > 0 and size_override.y > 0:
		entry["size"] = size_override
	_entries[entry_id] = entry
	grid_changed.emit()
	return true


static func _get_item_definitions(item_directory: String) -> Dictionary:
	if _definition_cache_by_directory.has(item_directory):
		return _definition_cache_by_directory[item_directory]

	var definitions: Dictionary = {}
	var directory := DirAccess.open(item_directory)
	if directory == null:
		_definition_cache_by_directory[item_directory] = definitions
		return definitions

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension() == "tres":
			var resource_path := item_directory.path_join(file_name)
			var resource := ResourceLoader.load(resource_path)
			if resource != null and resource.has_method("to_definition"):
				var item_id := StringName(resource.get("item_id"))
				if item_id != &"":
					definitions[item_id] = resource.call("to_definition")
		file_name = directory.get_next()

	directory.list_dir_end()
	_definition_cache_by_directory[item_directory] = definitions
	return definitions


static func _get_fallback_item_definition(item_id: StringName) -> Dictionary:
	return {
		"name": str(item_id),
		"short_name": str(item_id),
		"size": Vector2i.ONE,
		"stackable": false,
		"max_stack": 1,
		"color": Color(0.44, 0.44, 0.46, 1.0),
	}


func _create_entry(item_id: StringName, position: Vector2i, size: Vector2i, quantity: int) -> void:
	var entry_id: int = _next_entry_id
	_next_entry_id += 1
	_entries[entry_id] = {
		"item_id": item_id,
		"position": position,
		"size": size,
		"quantity": quantity,
	}


func _set_total_quantity(item_id: StringName, quantity: int) -> void:
	if quantity <= 0:
		_items.erase(item_id)
	else:
		_items[item_id] = quantity

	item_quantity_changed.emit(item_id, maxi(quantity, 0))


func _find_first_free_position(size: Vector2i) -> Vector2i:
	for y in grid_height:
		for x in grid_width:
			var position := Vector2i(x, y)
			if _is_area_free(position, size):
				return position

	return Vector2i(-1, -1)


func _find_first_free_position_with_rects(size: Vector2i, occupied_rects: Array[Rect2i]) -> Vector2i:
	for y in grid_height:
		for x in grid_width:
			var position := Vector2i(x, y)
			if _is_area_free_in_rects(position, size, occupied_rects):
				return position

	return Vector2i(-1, -1)


func _is_area_free(position: Vector2i, size: Vector2i, ignored_entry_id: int = -1) -> bool:
	if position.x < 0 or position.y < 0:
		return false
	if position.x + size.x > grid_width or position.y + size.y > grid_height:
		return false

	var checked_rect := Rect2i(position, size)
	for entry_id in _entries:
		if int(entry_id) == ignored_entry_id:
			continue

		var entry: Dictionary = _entries[entry_id]
		var entry_rect := Rect2i(entry.get("position", Vector2i.ZERO), entry.get("size", Vector2i.ONE))
		if checked_rect.intersects(entry_rect):
			return false

	return true


func _is_area_free_in_rects(position: Vector2i, size: Vector2i, occupied_rects: Array[Rect2i]) -> bool:
	if position.x < 0 or position.y < 0:
		return false
	if position.x + size.x > grid_width or position.y + size.y > grid_height:
		return false

	var checked_rect := Rect2i(position, size)
	for occupied_rect in occupied_rects:
		if checked_rect.intersects(occupied_rect):
			return false

	return true
