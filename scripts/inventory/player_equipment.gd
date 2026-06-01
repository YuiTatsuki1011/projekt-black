extends Node
class_name PlayerEquipment

signal equipment_changed(slot: StringName)

const FIREARM_SLOT_IDS := [&"firearm_1", &"firearm_2", &"firearm_3", &"firearm_4"]

@export var firearm_slot_1: Resource
@export var firearm_slot_2: Resource
@export var firearm_slot_3: Resource
@export var firearm_slot_4: Resource
@export_range(1, 4, 1) var active_firearm_slot: int = 1
@export var melee_weapon: Resource


func get_firearm_slots() -> Array:
	return FIREARM_SLOT_IDS.duplicate()


func get_active_firearm_slot_index() -> int:
	return active_firearm_slot


func get_active_firearm_slot() -> StringName:
	return FIREARM_SLOT_IDS[clampi(active_firearm_slot, 1, FIREARM_SLOT_IDS.size()) - 1]


func get_ranged_weapon() -> Resource:
	return get_weapon(get_active_firearm_slot())


func get_melee_weapon() -> Resource:
	return melee_weapon


func get_weapon(slot: StringName) -> Resource:
	match _normalize_slot(slot):
		&"firearm_1":
			return firearm_slot_1
		&"firearm_2":
			return firearm_slot_2
		&"firearm_3":
			return firearm_slot_3
		&"firearm_4":
			return firearm_slot_4
		&"melee":
			return melee_weapon

	return null


func equip_weapon(slot: StringName, next_weapon: Resource) -> bool:
	var normalized_slot := _normalize_slot(slot)
	match normalized_slot:
		&"firearm_1", &"firearm_2", &"firearm_3", &"firearm_4":
			_equip_firearm_slot(normalized_slot, next_weapon)
			return true
		&"melee":
			equip_melee_weapon(next_weapon)
			return true

	return false


func equip_ranged_weapon(next_weapon: Resource) -> void:
	_equip_firearm_slot(get_active_firearm_slot(), next_weapon)


func equip_melee_weapon(next_weapon: Resource) -> void:
	if melee_weapon == next_weapon:
		return

	melee_weapon = next_weapon
	equipment_changed.emit(&"melee")


func select_firearm_slot(slot_index: int) -> bool:
	var next_slot_index := clampi(slot_index, 1, FIREARM_SLOT_IDS.size())
	if active_firearm_slot == next_slot_index:
		return true

	active_firearm_slot = next_slot_index
	equipment_changed.emit(&"ranged")
	return true


func _normalize_slot(slot: StringName) -> StringName:
	if slot == &"ranged":
		return get_active_firearm_slot()

	return slot


func _equip_firearm_slot(slot: StringName, next_weapon: Resource) -> void:
	match slot:
		&"firearm_1":
			if firearm_slot_1 == next_weapon:
				return
			firearm_slot_1 = next_weapon
		&"firearm_2":
			if firearm_slot_2 == next_weapon:
				return
			firearm_slot_2 = next_weapon
		&"firearm_3":
			if firearm_slot_3 == next_weapon:
				return
			firearm_slot_3 = next_weapon
		&"firearm_4":
			if firearm_slot_4 == next_weapon:
				return
			firearm_slot_4 = next_weapon
		_:
			return

	equipment_changed.emit(slot)
