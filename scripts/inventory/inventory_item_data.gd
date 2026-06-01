extends Resource
class_name InventoryItemData

const TYPE_ITEM := &"item"
const TYPE_RANGED_WEAPON := &"ranged_weapon"
const TYPE_MELEE_WEAPON := &"melee_weapon"

@export var item_id: StringName = &"item"
@export var display_name: String = "Item"
@export var short_name: String = "Item"
@export var size: Vector2i = Vector2i.ONE
@export var stackable: bool = false
@export_range(1, 999, 1) var max_stack: int = 1
@export var color: Color = Color(0.44, 0.44, 0.46, 1.0)
@export_enum("item", "ranged_weapon", "melee_weapon") var item_type: String = "item"
@export var weapon_resource: Resource


func to_definition() -> Dictionary:
	var definition := {
		"name": display_name,
		"short_name": short_name,
		"size": size,
		"stackable": stackable,
		"max_stack": max_stack,
		"color": color,
	}

	var type_id := StringName(item_type)
	if type_id != TYPE_ITEM:
		definition["type"] = type_id

	if weapon_resource != null:
		definition["weapon_resource"] = weapon_resource
		if not weapon_resource.resource_path.is_empty():
			definition["weapon_resource_path"] = weapon_resource.resource_path

	return definition
