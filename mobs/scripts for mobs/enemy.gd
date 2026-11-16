extends CharacterBody3D

## A mob that walks a Path3D by advancing its parent PathFollow3D each physics
## frame. Health and speed are set per-wave by the spawner (main_level.gd).

@export var speed: float = 2.0
@export var health: int = 100

@onready var Path : PathFollow3D = get_parent()

func _physics_process(delta: float) -> void:
	Path.set_progress(Path.get_progress() + speed * delta)
	
	if Path.get_progress_ratio() >= 0.99:
		# An enemy reached the end goal: notify the level bridge (if present)
		# so it can take a life, then despawn.
		get_tree().call_group("level_bridge", "enemy_reached_end")
		Path.queue_free()

func take_damage(damage: int) -> void:
	health -= damage
	
	if health <= 0:
		# Enemy defeated: notify the level bridge (if present) for kill stats.
		get_tree().call_group("level_bridge", "enemy_killed")
		queue_free()
