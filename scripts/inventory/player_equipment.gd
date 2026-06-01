extends Node
class_name PlayerEquipment

signal equipment_changed(slot: StringName)

@export var ranged_weapon: Resource
@export var melee_weapon: Resource


func get_ranged_weapon() -> Resource:
	return ranged_weapon


func get_melee_weapon() -> Resource:
	return melee_weapon


func get_weapon(slot: StringName) -> Resource:
	if slot == &"ranged":
		return ranged_weapon
	if slot == &"melee":
		return melee_weapon

	return null


func equip_weapon(slot: StringName, next_weapon: Resource) -> bool:
	if slot == &"ranged":
		equip_ranged_weapon(next_weapon)
		return true
	if slot == &"melee":
		equip_melee_weapon(next_weapon)
		return true

	return false


func equip_ranged_weapon(next_weapon: Resource) -> void:
	if ranged_weapon == next_weapon:
		return

	ranged_weapon = next_weapon
	equipment_changed.emit(&"ranged")


func equip_melee_weapon(next_weapon: Resource) -> void:
	if melee_weapon == next_weapon:
		return

	melee_weapon = next_weapon
	equipment_changed.emit(&"melee")
