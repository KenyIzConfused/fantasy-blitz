class_name PrototypeLevel
extends Node3D

## Prototype: the test level (test.tscn) driven by the Gameplay UI HUD.
## Bridges the HUD cards to real tower placement:
##   HUD build_card_selected(index) -> pick tower scene -> click on the map
##   (prototype_camera.gd) places it and charges gold through the HUD.

const ARCHER_TOWER: PackedScene = preload("res://tower/archer.tscn")
const KNIGHT_TOWER: PackedScene = preload("res://tower/knight.tscn")
const WIZARD_TOWER: PackedScene = preload("res://tower/wizard.tscn")

## Fake per-card stats shown in the inspect panel when a card is selected.
## Extend this array if you add more cards.
const CARD_STATS := {
	0: {"name": "Archer Tower", "damage": 25, "range": 6},
	1: {"name": "Wizard Tower", "damage": 40, "range": 5},
	2: {"name": "Knight Tower", "damage": 15, "range": 3},
}

@onready var hud: GameplayUI = $HUDLayer/GameplayUI
@onready var pause_screen: Control = $HUDLayer/PauseScreen
@onready var defeat_screen: Control = $HUDLayer/DefeatScreen

## Tower scene chosen via the HUD cards; prototype_camera.gd places it.
var current_tower_scene: PackedScene = null

## Run state shown in the HUD and on the defeat screen.
const STARTING_LIVES := 3
var lives: int = STARTING_LIVES
var kills: int = 0
var wave: int = 1


func _ready() -> void:
	add_to_group("level_bridge")
	hud.build_card_selected.connect(_on_card_selected)
	hud.pause_pressed.connect(_on_pause_pressed)
	hud.set_gold(150)
	hud.set_wave(wave, 10)
	hud.set_lives(lives)


## --- called by the enemies (enemy.gd) via the "level_bridge" group ---------

func enemy_reached_end() -> void:
	if defeat_screen.visible:
		return
	lives = max(lives - 1, 0)
	hud.set_lives(lives)
	if lives <= 0:
		_game_over()


func enemy_killed() -> void:
	kills += 1


func _game_over() -> void:
	get_tree().paused = true
	defeat_screen.show_defeat(wave, kills)


func _on_card_selected(card_index: int) -> void:
	match card_index:
		0:
			current_tower_scene = ARCHER_TOWER
		1:
			current_tower_scene = WIZARD_TOWER
		2:
			current_tower_scene = KNIGHT_TOWER
	var stats: Dictionary = CARD_STATS[card_index]
	hud.show_tower_info(stats["name"], stats["damage"], stats["range"])


## Called by prototype_camera.gd after a tower was actually placed.
func on_tower_placed() -> void:
	hud.set_gold(hud.get_gold() - hud.get_selected_cost())
	hud.clear_selection()
	hud.hide_tower_info()
	current_tower_scene = null


func _on_pause_pressed() -> void:
	get_tree().paused = true
	pause_screen.show()
