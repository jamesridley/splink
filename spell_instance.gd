class_name SpellInstance
extends Node2D

var spell: SpellData

func _init() -> void:
	print("[SpellInstance._init] spell=", spell)

func _ready() -> void:
	print("[SpellInstance._ready] ENTER — spell=", spell)
	if spell == null:
		push_error("[SpellInstance._ready] spell is NULL — _ready ran before assignment")
		return
	print("[SpellInstance._ready] spell.radius=", spell.radius, " duration=", spell.duration)
	
	var area := Area2D.new()
	add_child(area)
	print("[SpellInstance._ready] Area2D added")
	
	var shape := CircleShape2D.new()
	shape.radius = spell.radius
	var col := CollisionShape2D.new()
	col.shape = shape
	area.add_child(col)
	print("[SpellInstance._ready] CollisionShape2D added with radius=", shape.radius)
	
	if spell.vfx_scene:
		add_child(spell.vfx_scene.instantiate())
		print("[SpellInstance._ready] vfx_scene instantiated")
	else:
		print("[SpellInstance._ready] no vfx_scene")
	
	if spell.spawn_scene:
		var spawned := spell.spawn_scene.instantiate()
		
		spawned.global_position = global_position
		
		get_parent().add_child(spawned)
		
	
	#await get_tree().physics_frame
	print("[SpellInstance._ready] after physics_frame, overlapping bodies=", area.get_overlapping_bodies().size())
	
	for body in area.get_overlapping_bodies():
		print("[SpellInstance._ready] sweep hit: ", body.name)
		_on_body_entered(body)
	
	area.body_entered.connect(_on_body_entered)
	print("[SpellInstance._ready] body_entered connected")
	
	get_tree().create_timer(spell.duration).timeout.connect(queue_free)
	print("[SpellInstance._ready] free timer set for ", spell.duration, "s")

func _on_body_entered(body: Node2D) -> void:
	print("[SpellInstance._on_body_entered] body=", body.name, " spell=", spell)
	var receptor := body.get_node_or_null("SpellReceptor") as SpellReceptor
	if receptor:
		print("[SpellInstance._on_body_entered] receptor found, dispatching")
		receptor.receive_spell(spell, global_position)
	else:
		print("[SpellInstance._on_body_entered] no SpellReceptor child on ", body.name)
