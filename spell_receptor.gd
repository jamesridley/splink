class_name SpellReceptor
extends Node2D

signal spell_received(spell: SpellData)
@export var is_flammable: bool = false
@export var vulnerability: Dictionary = {}

# SpellReceptor.gd
func receive_spell(spell: SpellData, origin: Vector2) -> void:
	print("[SpellReceptor.receive_spell] parent=", get_parent().name, " spell=", spell, " element=", spell.element, " origin=", origin)
	spell_received.emit(spell)
	
	var parent := get_parent()
	
	if spell.impulse > 0.0 and parent is RigidBody2D:
		var body_center: Vector2 = parent.global_position + parent.center_of_mass
		var dir := (body_center - origin).normalized()
		parent.apply_central_impulse(dir * spell.impulse)
		print("[SpellReceptor.receive_spell] impulse applied: ", dir * spell.impulse, " (parent_pos=", parent.global_position, " dir=", dir, ")")
	else:
		print("[SpellReceptor.receive_spell] no impulse (impulse=", spell.impulse, " is_rigid=", parent is RigidBody2D, ")")
	
	if spell.damage > 0.0 and parent.has_method("take_damage"):
		var mult: float = vulnerability.get(spell.element, 1.0)
		print("[SpellReceptor.receive_spell] applying damage ", spell.damage, " * mult ", mult)
		parent.take_damage(spell.damage * mult)
	else:
		print("[SpellReceptor.receive_spell] no damage (damage=", spell.damage, " has_take_damage=", parent.has_method("take_damage"), ")")
	
	if spell.element == SpellData.Element.FIRE and is_flammable:
		_ignite()
	else:
		print("[SpellReceptor.receive_spell] no ignite (element=", spell.element, " flammable=", is_flammable, ")")

func _ignite() -> void:
	print("[SpellReceptor._ignite] ", get_parent().name, " catches fire!")
