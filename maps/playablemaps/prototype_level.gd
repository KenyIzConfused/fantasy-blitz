class_name PrototypeLevel
extends Node3D

## Prototype: the test level (test.tscn) driven by the Gameplay UI HUD.
## Owns the run state (lives, gold, wave, kills) and reacts to game events:
##   - HUD card picked   -> show that tower's stats in the inspect panel.
##   - enemy reaches end -> lose a life (Game Over at zero).
##   - all waves cleared -> Victory.
## Tower placement itself lives in the HUD (UI/Gameplay_UI.gd).

## Per-card stats shown in the inspect panel when a card is selected.
## Keep in sync with GameplayUI.build_cards.
const CARD_STATS := {
	0: {"name": "Archer Tower", "damage": 25, "range": 6},
	1: {"name": "Wizard Tower", "damage": 40, "range": 5},
	2: {"name": "Knight Tower", "damage": 60, "range": 3},
}

@onready var hud: GameplayUI = $HUDLayer/GameplayUI
@onready var pause_screen: Control = $HUDLayer/PauseScreen
@onready var defeat_screen: Control = $HUDLayer/DefeatScreen
@onready var victory_screen: Control = $HUDLayer/VictoryScreen

## Run state shown in the HUD and on the result screen.
const STARTING_LIVES := 3
const STARTING_GOLD := 250

## Economy: gold per enemy killed, and passive income every PASSIVE_INTERVAL secs.
const KILL_REWARD := 12
const PASSIVE_GOLD := 5
const PASSIVE_INTERVAL := 4.0

## Must match main_level.gd's TOTAL_WAVES; shown as "Wave N / TOTAL_WAVES".
const TOTAL_WAVES := 10

var lives: int = STARTING_LIVES
var kills: int = 0
var wave: int = 1

var _passive_timer: Timer


func _ready() -> void:
	add_to_group("level_bridge")
	hud.build_card_selected.connect(_on_card_selected)
	hud.pause_pressed.connect(_on_pause_pressed)
	hud.set_gold(STARTING_GOLD)
	hud.set_wave(wave, TOTAL_WAVES)
	hud.set_lives(lives)

	# Passive income: a small trickle so the player recovers from a bad wave.
	_passive_timer = Timer.new()
	_passive_timer.wait_time = PASSIVE_INTERVAL
	_passive_timer.autostart = true
	_passive_timer.timeout.connect(_on_passive_gold)
	add_child(_passive_timer)


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
	hud.add_gold(KILL_REWARD)


func _on_passive_gold() -> void:
	hud.add_gold(PASSIVE_GOLD)


## Called by the spawner (main_level.gd) whenever a new wave begins.
func on_wave_started(wave_number: int, _enemy_count: int) -> void:
	wave = wave_number
	hud.set_wave(wave_number, TOTAL_WAVES)


## Called by the spawner after the final wave is cleared: the player won.
func on_level_cleared() -> void:
	if defeat_screen.visible or victory_screen.visible:
		return
	# COC-style stars: a flawless defense (no enemy leaked) is 3 stars, each
	# leak costs one, and winning is always worth at least 1.
	var stars: int = clampi(lives, 1, 3)
	get_tree().paused = true
	victory_screen.show_victory(wave, kills, stars)


func _game_over() -> void:
	get_tree().paused = true
	defeat_screen.show_defeat(wave, kills)


## Show the picked tower's stats in the inspect panel. Placement itself is
## handled by the HUD (UI/Gameplay_UI.gd).
func _on_card_selected(card_index: int) -> void:
	var stats: Dictionary = CARD_STATS.get(card_index, {})
	if stats.is_empty():
		return
	hud.show_tower_info(stats["name"], stats["damage"], stats["range"])


## Tower placement + gold charging now live in the HUD (Gameplay_UI.gd).


func _on_pause_pressed() -> void:
	get_tree().paused = true
	pause_screen.show()
