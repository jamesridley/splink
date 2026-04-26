# SpellData.gd
class_name SpellData
extends Resource
enum Element { FIRE, ICE, LIGHTNING, EARTH }
@export var name: String = ""
@export var element: Element = Element.FIRE
@export var radius: float = 64.0
@export var damage: float = 10.0
@export var impulse: float = 0.0
@export var duration: float = 1.0
@export var vfx_scene: PackedScene
@export var spawn_scene: PackedScene  # persistent object spawned at cast point
