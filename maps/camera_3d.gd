extends Camera3D

## Hover marker: follows the mouse across the tile grid every frame and blinks,
## so the player always sees where a tower would land - no click needed.
## Tower placement itself is handled by the HUD (UI/Gameplay_UI.gd).

const MARKER: PackedScene = preload("res://resourceScenes/marker.tscn")
const TILE_SIZE := 2.0
const BLINK_SPEED := 2.5

var _marker: Node3D = null
var _marker_mesh: GeometryInstance3D = null
var _blink_time: float = 0.0


func _ready() -> void:
	_marker = MARKER.instantiate()
	_marker_mesh = _marker.get_node_or_null("marker") as GeometryInstance3D
	_marker.visible = false
	get_parent().add_child.call_deferred(_marker)


func _process(delta: float) -> void:
	var hit := _raycast_from_mouse()
	if hit.is_empty():
		_marker.visible = false
		return

	_marker.visible = true
	var point: Vector3 = hit["position"]
	_marker.position = Vector3(
		roundf(point.x / TILE_SIZE) * TILE_SIZE,
		point.y,
		roundf(point.z / TILE_SIZE) * TILE_SIZE
	)

	# Blink: pulse the scale and fade between solid and semi-transparent.
	_blink_time += delta
	var pulse: float = (sin(_blink_time * TAU * BLINK_SPEED) + 1.0) * 0.5
	_marker.scale = Vector3.ONE * (1.0 + 0.12 * pulse)
	if _marker_mesh != null:
		_marker_mesh.transparency = 0.55 * (1.0 - pulse)


func _raycast_from_mouse() -> Dictionary:
	var mouse_pos := get_viewport().get_mouse_position()
	var from := project_ray_origin(mouse_pos)
	var to := from + project_ray_normal(mouse_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	return get_world_3d().direct_space_state.intersect_ray(query)
