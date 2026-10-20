extends CharacterBody3D

@export var speed : int = 3
@export var health : int = 15

@onready var Path : PathFollow3D = get_parent()

func _physics_process(delta):
	Path.set_progress(Path.get_progress() + speed * delta)
	
	if Path.get_progress_ratio() >= 0.99:
		Path.queue_free()

func take_damage(damage : int) -> void:
	health -= damage
	
	if health <= 0:
		queue_free()
