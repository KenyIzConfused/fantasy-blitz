extends StaticBody3D

var arrow : PackedScene = preload("res://tower/arrow.tscn")
var arrow_damage : int = 5
var current_targets : Array = []
var curr : CharacterBody3D
var can_shoot : bool = true

func _process(delta):
	if is_instance_valid(curr):
		look_at(curr.global_position)
		if can_shoot: 
			shoot()
			can_shoot = false
			$shootCooldown.start()
	else: 
		for i in get_node("arrowContainer").get_child_count():
			get_node("arrowContainer").get_child(i).queue_free()

func shoot() -> void:
	var temp_arrow:CharacterBody3D = arrow.instantiate()
	temp_arrow.target = curr
	temp_arrow.arrow_damage = arrow_damage
	get_node("arrowContainer").add_child(temp_arrow)
	temp_arrow.global_position = $MeshInstance3D/Aim.global_position

func choose_target(_current_targets : Array) -> void:
	var temp_array : Array = _current_targets
	var current_target : CharacterBody3D = null
	for i in temp_array:
		if current_target == null:
			current_target = i
		else:
			if i.get_parent().get_progress() > current_target.get_parent().get_progress() :
				current_target = i
	curr = current_target

func _on_mob_detector_body_entered(body: Node3D) -> void:
	if body.is_in_group("Enemy"):
		current_targets.append(body)
		choose_target(current_targets)
		print("Target locked")


func _on_mob_detector_body_exited(body: Node3D) -> void:
	if body.is_in_group("Enemy"):
		current_targets.erase(body)
		choose_target(current_targets)
		print("target eliminated")


func _on_shoot_cooldown_timeout() -> void:
	can_shoot = true
