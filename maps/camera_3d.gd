extends Camera3D

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

@onready var card_ui_node: HBoxContainer = $"../hud/CardContainer/Cards"
const ARCHER = preload("res://tower/archer.tscn")


var marker = preload("res://resourceScenes/marker.tscn")
var active_marker = null

func _input(event):
	if event.is_action_pressed("click"):
		shoot_ray()

func shoot_ray():
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_length = 1000
	var from = project_ray_origin(mouse_pos)
	var to = from + project_ray_normal(mouse_pos) * ray_length
	var space = get_world_3d().direct_space_state
	var ray_query = PhysicsRayQueryParameters3D.new()
	ray_query.from = from
	ray_query.to = to
	var raycast_result = space.intersect_ray(ray_query)
	print(raycast_result)
	
	if !raycast_result.is_empty():
		var hit_position = raycast_result["position"]
		
		# --- 1. SNAP TO TILE GRID ---
		# Change '2.0' to whatever size your tile width/length is (e.g., 1.0, 2.0, etc.)
		var tile_size = 2.0 
		var snapped_position = Vector3(
			round(hit_position.x / tile_size) * tile_size,
			hit_position.y, # Keep original height, or hardcode it like 0.0 if flat
			round(hit_position.z / tile_size) * tile_size
		)
		
		# --- 2. ONLY ALLOW 1 MARKER TO EXIST ---
		if card_ui_node and card_ui_node.selected_tower_scene != null:
			# Player has a card selected! Let's place the permanent tower here.
			try_spawn_tower(snapped_position)
		else:
			# No card selected, just move the regular selection/preview marker
			if is_instance_valid(active_marker):
				active_marker.position = snapped_position
			else:
				active_marker = marker.instantiate()
				active_marker.position = snapped_position
				get_parent().add_child(active_marker)

func try_spawn_tower(snapped_position: Vector3) -> void:
	# 1. Instantiate the chosen tower scene (like archer.tscn)
	var new_tower = card_ui_node.selected_tower_scene.instantiate()
	
	# 2. Position it on the snapped tile coordinate
	new_tower.position = snapped_position
	
	# 3. Add it to the 3D world scene permanently
	get_parent().add_child(new_tower)
	
	# 4. Clean up the preview/selection marker if it was visible
	if is_instance_valid(active_marker):
		active_marker.queue_free()
		active_marker = null
		
	# 5. Reset card selection so you don't accidentally place another one on the next click
	card_ui_node.selected_tower_scene = null
