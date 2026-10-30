extends HBoxContainer

@onready var knight_card: TextureButton = $knightCard
@onready var archer_card: TextureButton = $archerCard
@onready var wizard_card: TextureButton = $wizardCard

const ARCHER = preload("res://tower/archer.tscn")
const KNIGHT = preload("res://tower/knight.tscn")

var selected_tower_scene: PackedScene = null

func _ready() -> void:
	setup_card_behavior(archer_card, ARCHER)

func setup_card_behavior(card: TextureButton, tower_scene: PackedScene) -> void:
	# Crucial: Set pivot offset to the center so it scales outward from the middle instead of the top-left corner
	card.pivot_offset = card.size / 2.0
	
	# 1. HOVER ENTER: Scale up slightly
	card.mouse_entered.connect(func():
		animate_scale(card, Vector2(1.1, 1.1), 0.1)
	)
	
	# 2. HOVER EXIT: Return to normal (unless it's the currently selected card)
	card.mouse_exited.connect(func():
		if selected_tower_scene != tower_scene:
			animate_scale(card, Vector2(1.0, 1.0), 0.1)
	)
	
	# 3. PRESSED: Select the card and highlight it
	card.pressed.connect(func():
		selected_tower_scene = tower_scene
		print("Selected tower scene: ", tower_scene)
		
		# Reset all cards, then pop/highlight the chosen one
		for c in [knight_card, archer_card, wizard_card]:
			if c == card:
				animate_scale(c, Vector2(1.15, 1.15), 0.15) # Stay popped up when active
			else:
				animate_scale(c, Vector2(1.0, 1.0), 0.15)
	)

func animate_scale(node: Control, target_scale: Vector2, duration: float) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", target_scale, duration)
