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
	return add_item_with_size(item_id, quantity)


func add_item_with_size(item_id: StringName, quantity: int, size_override: Vector2i = Vector2i.ZERO) -> int:
	if quantity <= 0:
		return 0

	var remaining_quantity: int = quantity
	var added_quantity: int = 0
	var definition: Dictionary = get_item_definition(item_id)
	var item_size: Vector2i = definition.get("size", Vector2i.ONE)
	if size_override.x > 0 and size_override.y > 0:
		item_size = size_override
	var is_stackable: bool = bool(definition.get("stackable", false))
	var max_stack: int = int(definition.get("max_stack", 1))

	if is_stackable:
		for entry_id in _entries:
			var entry: Dictionary = _entries[entry_id]
			if entry.get("item_id") != item_id:
				continue
			if not _are_metadata_stack_compatible(entry.get("metadata", {}), {}):
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
	size_override: Vector2i = Vector2i.ZERO,
	metadata: Dictionary = {}
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

	_create_entry(item_id, position, item_size, stack_quantity, metadata)
	_set_total_quantity(item_id, get_quantity(item_id) + stack_quantity)
	grid_changed.emit()
	return stack_quantity


func add_item_with_metadata(
	item_id: StringName,
	metadata: Dictionary,
	size_override: Vector2i = Vector2i.ZERO
) -> bool:
	var definition: Dictionary = get_item_definition(item_id)
	var item_size: Vector2i = definition.get("size", Vector2i.ONE)
	if size_override.x > 0 and size_override.y > 0:
		item_size = size_override

	var position := _find_first_free_position(item_size)
	if position.x < 0:
		return false

	return add_item_at(item_id, 1, position, item_size, metadata) == 1


func add_item_with_metadata_quantity(
	item_id: StringName,
	quantity: int,
	metadata: Dictionary,
	size_override: Vector2i = Vector2i.ZERO
) -> int:
	if quantity <= 0:
		return 0
	var normalized_metadata := _normalize_metadata(metadata)
	if normalized_metadata.is_empty():
		return add_item_with_size(item_id, quantity, size_override)

	var remaining_quantity := quantity
	var added_quantity := 0
	var definition: Dictionary = get_item_definition(item_id)
	var item_size: Vector2i = definition.get("size", Vector2i.ONE)
	if size_override.x > 0 and size_override.y > 0:
		item_size = size_override

	var is_stackable: bool = bool(definition.get("stackable", false))
	var max_stack: int = int(definition.get("max_stack", 1))
	while remaining_quantity > 0:
		var position := _find_first_free_position(item_size)
		if position.x < 0:
			break

		var stack_quantity: int = mini(max_stack, remaining_quantity) if is_stackable else 1
		_create_entry(item_id, position, item_size, stack_quantity, normalized_metadata)
		remaining_quantity -= stack_quantity
		added_quantity += stack_quantity

	if added_quantity > 0:
		_set_total_quantity(item_id, get_quantity(item_id) + added_quantity)
		grid_changed.emit()

	return added_quantity


func can_add_item(item_id: StringName, quantity: int = 1) -> bool:
	return can_add_item_with_size(item_id, quantity)


func can_add_item_with_size(item_id: StringName, quantity: int = 1, size_override: Vector2i = Vector2i.ZERO) -> bool:
	if quantity <= 0:
		return true

	var remaining_quantity: int = quantity
	var definition: Dictionary = get_item_definition(item_id)
	var item_size: Vector2i = definition.get("size", Vector2i.ONE)
	if size_override.x > 0 and size_override.y > 0:
		item_size = size_override
	var is_stackable: bool = bool(definition.get("stackable", false))
	var max_stack: int = int(definition.get("max_stack", 1))
	var occupied_rects: Array[Rect2i] = []

	for entry_id in _entries:
		var entry: Dictionary = _entries[entry_id]
		occupied_rects.append(Rect2i(entry.get("position", Vector2i.ZERO), entry.get("size", Vector2i.ONE)))

		if not is_stackable or entry.get("item_id") != item_id:
			continue
		if not _are_metadata_stack_compatible(entry.get("metadata", {}), {}):
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


func split_entry(entry_id: int, split_quantity: int = -1) -> Dictionary:
	if not _entries.has(entry_id):
		return {}

	var entry: Dictionary = _entries[entry_id]
	var item_id: StringName = entry.get("item_id", &"")
	var definition: Dictionary = get_item_definition(item_id)
	if not bool(definition.get("stackable", false)):
		return {}

	var source_quantity: int = int(entry.get("quantity", 0))
	if source_quantity <= 1:
		return {}

	var max_stack: int = int(definition.get("max_stack", 1))
	var quantity_to_split: int = split_quantity
	if quantity_to_split <= 0:
		quantity_to_split = floori(float(source_quantity) * 0.5)
	quantity_to_split = clampi(quantity_to_split, 1, mini(source_quantity - 1, max_stack))

	var item_size: Vector2i = entry.get("size", Vector2i.ONE)
	var source_position: Vector2i = entry.get("position", Vector2i.ZERO)
	var new_position: Vector2i = _find_nearest_free_position(item_size, source_position)
	if new_position.x < 0:
		return {}

	entry["quantity"] = source_quantity - quantity_to_split
	_entries[entry_id] = entry

	var new_entry_id: int = _create_entry(
		item_id,
		new_position,
		item_size,
		quantity_to_split,
		entry.get("metadata", {})
	)
	grid_changed.emit()
	return get_entry(new_entry_id)


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


func get_entry_metadata(entry_id: int) -> Dictionary:
	if not _entries.has(entry_id):
		return {}

	return Dictionary(_entries[entry_id].get("metadata", {})).duplicate(true)


func get_magazine_entry_info(entry_id: int) -> Dictionary:
	if not _entries.has(entry_id):
		return {}

	var entry: Dictionary = _entries[entry_id]
	var item_id: StringName = entry.get("item_id", &"")
	var definition: Dictionary = get_item_definition(item_id)
	if StringName(definition.get("type", &"")) != &"magazine":
		return {}

	var metadata: Dictionary = entry.get("metadata", {})
	var capacity: int = int(definition.get("magazine_capacity", 0))
	if metadata.has("capacity"):
		capacity = int(metadata.get("capacity", capacity))

	var ammo_item_id := StringName(definition.get("ammo_item_id", &""))
	if metadata.has("ammo_item_id"):
		ammo_item_id = StringName(metadata.get("ammo_item_id", ammo_item_id))

	var ammo_count := capacity
	if metadata.has("ammo_count"):
		ammo_count = int(metadata.get("ammo_count", 0))
	ammo_count = clampi(ammo_count, 0, capacity)

	return {
		"entry_id": entry_id,
		"item_id": item_id,
		"ammo_item_id": ammo_item_id,
		"ammo_count": ammo_count,
		"capacity": capacity,
		"is_checked": bool(metadata.get("is_checked", false)),
		"position": entry.get("position", Vector2i.ZERO),
	}


func get_magazine_entries(magazine_item_id: StringName = &"", ammo_item_id: StringName = &"") -> Array[Dictionary]:
	var entries := get_entries()
	entries.sort_custom(Callable(self, "_compare_entries_by_grid_position"))

	var magazine_entries: Array[Dictionary] = []
	for entry in entries:
		var entry_item_id: StringName = entry.get("item_id", &"")
		if magazine_item_id != &"" and entry_item_id != magazine_item_id:
			continue

		var entry_id := int(entry.get("entry_id", -1))
		var info := get_magazine_entry_info(entry_id)
		if info.is_empty():
			continue
		if ammo_item_id != &"" and StringName(info.get("ammo_item_id", &"")) != ammo_item_id:
			continue

		magazine_entries.append(info)

	return magazine_entries


func get_first_loadable_magazine_entry_id(magazine_item_id: StringName, ammo_item_id: StringName) -> int:
	for info in get_magazine_entries(magazine_item_id, ammo_item_id):
		if int(info.get("ammo_count", 0)) < int(info.get("capacity", 0)):
			return int(info.get("entry_id", -1))

	return -1


func get_first_ammo_entry_id(ammo_item_id: StringName) -> int:
	var entries := get_entries()
	entries.sort_custom(Callable(self, "_compare_entries_by_grid_position"))
	for entry in entries:
		if entry.get("item_id", &"") == ammo_item_id and int(entry.get("quantity", 0)) > 0:
			return int(entry.get("entry_id", -1))

	return -1


func get_loadable_round_count(magazine_entry_id: int, ammo_inventory: Node, ammo_entry_id: int) -> int:
	if ammo_inventory == null or not ammo_inventory.has_method("get_entry"):
		return 0

	var magazine_info := get_magazine_entry_info(magazine_entry_id)
	if magazine_info.is_empty():
		return 0

	var ammo_entry: Dictionary = ammo_inventory.call("get_entry", ammo_entry_id)
	if ammo_entry.is_empty():
		return 0
	if ammo_entry.get("item_id", &"") != magazine_info.get("ammo_item_id", &""):
		return 0

	var magazine_space := int(magazine_info.get("capacity", 0)) - int(magazine_info.get("ammo_count", 0))
	return mini(maxi(magazine_space, 0), int(ammo_entry.get("quantity", 0)))


func can_load_round_into_magazine(magazine_entry_id: int, ammo_inventory: Node, ammo_entry_id: int) -> bool:
	return get_loadable_round_count(magazine_entry_id, ammo_inventory, ammo_entry_id) > 0


func load_round_into_magazine(magazine_entry_id: int, ammo_inventory: Node, ammo_entry_id: int) -> bool:
	if not can_load_round_into_magazine(magazine_entry_id, ammo_inventory, ammo_entry_id):
		return false
	if ammo_inventory == null or not ammo_inventory.has_method("remove_quantity_from_entry"):
		return false

	var removed_quantity: int = int(ammo_inventory.call("remove_quantity_from_entry", ammo_entry_id, 1))
	if removed_quantity != 1:
		return false

	var magazine_info := get_magazine_entry_info(magazine_entry_id)
	if magazine_info.is_empty():
		return false

	var metadata := get_entry_metadata(magazine_entry_id)
	metadata["ammo_count"] = int(magazine_info.get("ammo_count", 0)) + 1
	metadata["capacity"] = int(magazine_info.get("capacity", 0))
	metadata["ammo_item_id"] = StringName(magazine_info.get("ammo_item_id", &""))
	metadata["is_checked"] = true
	return set_entry_metadata(magazine_entry_id, metadata)


func set_magazine_entry_checked(entry_id: int, is_checked: bool = true) -> bool:
	var magazine_info := get_magazine_entry_info(entry_id)
	if magazine_info.is_empty():
		return false

	var metadata := get_entry_metadata(entry_id)
	metadata["ammo_count"] = int(magazine_info.get("ammo_count", 0))
	metadata["capacity"] = int(magazine_info.get("capacity", 0))
	metadata["ammo_item_id"] = StringName(magazine_info.get("ammo_item_id", &""))
	metadata["is_checked"] = is_checked
	return set_entry_metadata(entry_id, metadata)


func is_magazine_entry_checked(entry_id: int) -> bool:
	var magazine_info := get_magazine_entry_info(entry_id)
	return bool(magazine_info.get("is_checked", false)) if not magazine_info.is_empty() else false


func is_entry_identified(entry_id: int) -> bool:
	if not _entries.has(entry_id):
		return true

	var metadata: Dictionary = _entries[entry_id].get("metadata", {})
	return bool(metadata.get("identified", true))


func set_entry_identified(entry_id: int, is_identified: bool = true) -> bool:
	if not _entries.has(entry_id):
		return false

	var metadata := get_entry_metadata(entry_id)
	if is_identified:
		metadata.erase("identified")
	else:
		metadata["identified"] = false
	return set_entry_metadata(entry_id, metadata)


func set_all_entries_identified(is_identified: bool = true) -> void:
	var changed := false
	for entry_id in _entries:
		var entry: Dictionary = _entries[entry_id]
		var metadata: Dictionary = Dictionary(entry.get("metadata", {})).duplicate(true)
		if bool(metadata.get("identified", true)) == is_identified:
			continue

		if is_identified:
			metadata.erase("identified")
		else:
			metadata["identified"] = false
		if metadata.is_empty():
			entry.erase("metadata")
		else:
			entry["metadata"] = metadata
		_entries[entry_id] = entry
		changed = true

	if changed:
		grid_changed.emit()


func get_first_unidentified_entry_id() -> int:
	var entries := get_entries()
	entries.sort_custom(Callable(self, "_compare_entries_by_grid_position"))
	for entry in entries:
		var metadata: Dictionary = entry.get("metadata", {})
		if not bool(metadata.get("identified", true)):
			return int(entry.get("entry_id", -1))

	return -1


func set_entry_metadata(entry_id: int, metadata: Dictionary) -> bool:
	if not _entries.has(entry_id):
		return false

	var entry: Dictionary = _entries[entry_id]
	var normalized_metadata := _normalize_metadata(metadata)
	if normalized_metadata.is_empty():
		entry.erase("metadata")
	else:
		entry["metadata"] = normalized_metadata
	_entries[entry_id] = entry
	grid_changed.emit()
	return true


func _compare_entries_by_grid_position(a: Dictionary, b: Dictionary) -> bool:
	var a_position: Vector2i = a.get("position", Vector2i.ZERO)
	var b_position: Vector2i = b.get("position", Vector2i.ZERO)
	if a_position.y == b_position.y:
		return a_position.x < b_position.x

	return a_position.y < b_position.y


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


func get_entry_id_at_cell(cell: Vector2i, ignored_entry_id: int = -1) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_width or cell.y >= grid_height:
		return -1

	var checked_rect := Rect2i(cell, Vector2i.ONE)
	for entry_id in _entries:
		if int(entry_id) == ignored_entry_id:
			continue

		var entry: Dictionary = _entries[entry_id]
		var entry_rect := Rect2i(entry.get("position", Vector2i.ZERO), entry.get("size", Vector2i.ONE))
		if checked_rect.intersects(entry_rect):
			return int(entry_id)

	return -1


func get_stack_target_entry_id(
	item_id: StringName,
	position: Vector2i,
	size: Vector2i,
	ignored_entry_id: int = -1,
	metadata: Dictionary = {}
) -> int:
	var definition: Dictionary = get_item_definition(item_id)
	if not bool(definition.get("stackable", false)):
		return -1

	var max_stack: int = int(definition.get("max_stack", 1))
	for y in size.y:
		for x in size.x:
			var entry_id := get_entry_id_at_cell(position + Vector2i(x, y), ignored_entry_id)
			if entry_id < 0:
				continue

			var entry: Dictionary = _entries.get(entry_id, {})
			if entry.get("item_id", &"") != item_id:
				continue
			if not _are_metadata_stack_compatible(entry.get("metadata", {}), metadata):
				continue
			if int(entry.get("quantity", 0)) >= max_stack:
				continue

			return entry_id

	return -1


func stack_entry_onto_entry(source_entry_id: int, target_entry_id: int) -> int:
	if source_entry_id == target_entry_id:
		return 0
	if not _entries.has(source_entry_id) or not _entries.has(target_entry_id):
		return 0

	var source_entry: Dictionary = _entries[source_entry_id]
	var target_entry: Dictionary = _entries[target_entry_id]
	var item_id: StringName = source_entry.get("item_id", &"")
	if item_id == &"" or target_entry.get("item_id", &"") != item_id:
		return 0
	if not _are_metadata_stack_compatible(
		source_entry.get("metadata", {}),
		target_entry.get("metadata", {})
	):
		return 0

	var definition: Dictionary = get_item_definition(item_id)
	if not bool(definition.get("stackable", false)):
		return 0

	var source_quantity: int = int(source_entry.get("quantity", 0))
	var target_quantity: int = int(target_entry.get("quantity", 0))
	var max_stack: int = int(definition.get("max_stack", 1))
	var moved_quantity: int = mini(source_quantity, maxi(max_stack - target_quantity, 0))
	if moved_quantity <= 0:
		return 0

	target_entry["quantity"] = target_quantity + moved_quantity
	_entries[target_entry_id] = target_entry

	source_quantity -= moved_quantity
	if source_quantity <= 0:
		_entries.erase(source_entry_id)
	else:
		source_entry["quantity"] = source_quantity
		_entries[source_entry_id] = source_entry

	grid_changed.emit()
	return moved_quantity


func add_quantity_to_entry(entry_id: int, quantity: int) -> int:
	if quantity <= 0 or not _entries.has(entry_id):
		return 0

	var entry: Dictionary = _entries[entry_id]
	var item_id: StringName = entry.get("item_id", &"")
	var definition: Dictionary = get_item_definition(item_id)
	if not bool(definition.get("stackable", false)):
		return 0

	var entry_quantity: int = int(entry.get("quantity", 0))
	var max_stack: int = int(definition.get("max_stack", 1))
	var added_quantity: int = mini(quantity, maxi(max_stack - entry_quantity, 0))
	if added_quantity <= 0:
		return 0

	entry["quantity"] = entry_quantity + added_quantity
	_entries[entry_id] = entry
	_set_total_quantity(item_id, get_quantity(item_id) + added_quantity)
	grid_changed.emit()
	return added_quantity


func remove_quantity_from_entry(entry_id: int, quantity: int) -> int:
	if quantity <= 0 or not _entries.has(entry_id):
		return 0

	var entry: Dictionary = _entries[entry_id]
	var item_id: StringName = entry.get("item_id", &"")
	var entry_quantity: int = int(entry.get("quantity", 0))
	var removed_quantity: int = mini(quantity, entry_quantity)
	if removed_quantity <= 0:
		return 0

	entry_quantity -= removed_quantity
	if entry_quantity <= 0:
		_entries.erase(entry_id)
	else:
		entry["quantity"] = entry_quantity
		_entries[entry_id] = entry

	_set_total_quantity(item_id, get_quantity(item_id) - removed_quantity)
	grid_changed.emit()
	return removed_quantity


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


func _create_entry(
	item_id: StringName,
	position: Vector2i,
	size: Vector2i,
	quantity: int,
	metadata: Dictionary = {}
) -> int:
	var entry_id: int = _next_entry_id
	_next_entry_id += 1
	_entries[entry_id] = {
		"item_id": item_id,
		"position": position,
		"size": size,
		"quantity": quantity,
	}
	var normalized_metadata := _normalize_metadata(metadata)
	if not normalized_metadata.is_empty():
		_entries[entry_id]["metadata"] = normalized_metadata
	return entry_id


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


func _find_nearest_free_position(size: Vector2i, origin: Vector2i) -> Vector2i:
	var best_position := Vector2i(-1, -1)
	var best_distance: int = 2147483647

	for y in grid_height:
		for x in grid_width:
			var position := Vector2i(x, y)
			if not _is_area_free(position, size):
				continue

			var distance: int = absi(position.x - origin.x) + absi(position.y - origin.y)
			if distance < best_distance:
				best_distance = distance
				best_position = position

	return best_position


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


func _are_metadata_stack_compatible(left: Dictionary, right: Dictionary) -> bool:
	return _normalize_metadata(left) == _normalize_metadata(right)


func _normalize_metadata(metadata: Dictionary) -> Dictionary:
	var normalized := metadata.duplicate(true)
	if bool(normalized.get("identified", true)):
		normalized.erase("identified")
	return normalized
