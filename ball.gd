extends RigidBody2D

@export var anim: AnimatedSprite2D

const FLYING_THRESHOLD := 50.0  # below this speed, considered idle

func _ready() -> void:
	anim.play("idle")

func _physics_process(_delta: float) -> void:
	if linear_velocity.length() > FLYING_THRESHOLD:
		if anim.animation != "flying":
			anim.play("flying")
		anim.rotation = linear_velocity.angle() + 0.5*PI
	else:
		if anim.animation != "idle":
			anim.play("idle")
		anim.rotation = 0.0
