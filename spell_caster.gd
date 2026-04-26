class_name SpellCaster
extends Node2D

func cast(spell: SpellData, target: Vector2) -> void:
	print("[SpellCaster.cast] called — spell=", spell, " target=", target)
	if spell == null:
		push_error("[SpellCaster.cast] spell is NULL on entry — check inspector assignment")
		return
	print("[SpellCaster.cast] spell.name=", spell.name, " radius=", spell.radius, " element=", spell.element)
	
	var instance := SpellInstance.new()
	print("[SpellCaster.cast] instance created: ", instance)
	
	instance.spell = spell
	print("[SpellCaster.cast] assigned instance.spell=", instance.spell)
	
	instance.global_position = target
	print("[SpellCaster.cast] set global_position=", instance.global_position)
	
	get_tree().current_scene.add_child(instance)
	print("[SpellCaster.cast] added to scene tree, instance.spell after add_child=", instance.spell)
	
