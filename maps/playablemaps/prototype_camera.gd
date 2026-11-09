extends Camera3D

## Placement camera for the gameplay-UI prototype.
## Same click-to-place behavior as the test scene's camera_3d.gd: raycast from
## the mouse into the world, snap to the 2.0 tile grid, and if a tower is
## selected in the HUD, place it there. Uses _unhandled_input so clicks on HUD
## buttons (cards, pause) never leak through to the map.

const MARKER: PackedScene = preload("res://resourceScenes/marker.tscn")

@onready var level: PrototypeLevel = $"../.."
@onready var hud: GameplayUI = $"../../HUDLayer/GameplayUI"

var active_marker: Node3D = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("click"):
		_shoot_ray()


func _shoot_ray() -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = project_ray_origin(mouse_pos)
	var to: Vector3 = from + project_ray_normal(mouse_pos) * 1000.0
	var ray_query := PhysicsRayQueryParameters3D.new()
	ray_query.from = from
	ray_query.to = to
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray_query)
	if result.is_empty():
		return

	var hit_position: Vector3 = result["position"]
	var tile_size := 2.0
	var snapped_position := Vector3(
		round(hit_position.x / tile_size) * tile_size,
		hit_position.y,
		round(hit_position.z / tile_size) * tile_size
	)

	if level.current_tower_scene != null:
		_spawn_tower(snapped_position)
	else:
		# No card selected: move the preview marker, like the test scene.
		if is_instance_valid(active_marker):
			active_marker.position = snapped_position
		else:
			active_marker = MARKER.instantiate()
			active_marker.position = snapped_position
			get_parent().add_child(active_marker)


func _spawn_tower(snapped_position: Vector3) -> void:
	var new_tower: Node3D = level.current_tower_scene.instantiate()
	new_tower.position = snapped_position
	get_parent().add_child(new_tower)

	if is_instance_valid(active_marker):
		active_marker.queue_free()
		active_marker = null

	# Charge gold, clear the HUD selection and the inspect panel.
	level.on_tower_placed()
