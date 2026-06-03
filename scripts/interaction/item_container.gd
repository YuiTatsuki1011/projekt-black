extends Area2D
class_name ItemContainer

const INTERACTABLE_GROUP := "interactables"

@export var container_label: String = "LOOT BOX"
@export var inventory_screen_path: NodePath = NodePath("../InventoryScreen")
@export var requires_search: bool = true
@export var layout_search_time: float = -1.0
@export var layout_search_base_time: float = 0.30
@export var layout_search_time_per_cell: float = 0.035
@export var layout_search_time_multiplier: float = 1.0
@export var layout_search_min_time: float = 0.20
@export var layout_search_max_time: float = 3.0
@export var item_identify_time: float = 1.0

@onready var label: Label = $Label
@onready var inventory: Node = $Inventory

var _layout_searched: bool = false
var _unknown_entries_initialized: bool = false


func _ready() -> void:
	add_to_group(INTERACTABLE_GROUP)
	label.text = container_label


func interact(_interactor: Node) -> void:
	prepare_for_search()
	var inventory_screen := get_node_or_null(inventory_screen_path)
	if inventory_screen == null:
		var current_scene := get_tree().current_scene
		if current_scene != null:
			inventory_screen = current_scene.get_node_or_null("InventoryScreen")

	if inventory_screen == null or not inventory_screen.has_method("open_external_inventory"):
		return

	inventory_screen.open_external_inventory(self)


func get_inventory() -> Node:
	return inventory


func get_container_label() -> String:
	return container_label


func prepare_for_search() -> void:
	if not requires_search or _unknown_entries_initialized:
		return
	if inventory != null and inventory.has_method("set_all_entries_identified"):
		inventory.call("set_all_entries_identified", false)
	_unknown_entries_initialized = true


func is_layout_searched() -> bool:
	return not requires_search or _layout_searched


func mark_layout_searched() -> void:
	_layout_searched = true


func get_layout_search_time() -> float:
	if layout_search_time > 0.0:
		return maxf(layout_search_time, 0.01)

	var cell_count := _get_inventory_cell_count()
	var resolved_time := (layout_search_base_time + float(cell_count) * layout_search_time_per_cell) * layout_search_time_multiplier
	var min_time := maxf(layout_search_min_time, 0.01)
	var max_time := maxf(layout_search_max_time, min_time)
	return clampf(resolved_time, min_time, max_time)


func get_item_identify_time() -> float:
	return maxf(item_identify_time, 0.01)


func _get_inventory_cell_count() -> int:
	if inventory == null:
		return 1
	if inventory.has_method("get_grid_size"):
		var grid_size: Vector2i = inventory.call("get_grid_size")
		return maxi(grid_size.x * grid_size.y, 1)

	var grid_width := maxi(int(inventory.get("grid_width")), 1)
	var grid_height := maxi(int(inventory.get("grid_height")), 1)
	return grid_width * grid_height
