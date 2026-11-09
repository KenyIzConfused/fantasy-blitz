class_name GameplayUI
extends Control

## Gameplay HUD for the tower defense game.
## Structure matches the reference mockup:
##   - Top bar: hearts (lives) + skull/wave counter on the left,
##     coin/gold counter + pause button on the right.
##   - Bottom-left: hero build cards (Archer / Wizard / Knight) with gold costs.
##   - Bottom-right: selected tower inspect panel (name, damage, range, upgrade/sell).
##
## Everything gameplay-related is exposed via exported node references or
## %unique names so other systems can be wired up later:
##   call set_gold(), set_wave(), set_lives(), show_tower_info() from gameplay code,
##   or connect to the signals below.

signal pause_pressed
signal build_card_selected(card_index: int)
signal upgrade_pressed
signal sell_pressed

## Buildable hero definitions, index-aligned with the build cards.
## Extend this array if you add more cards.
var build_cards: Array[Dictionary] = [
	{"name": "Archer", "cost": 100, "texture": preload("res://assets/card/1.png")},
	{"name": "Wizard", "cost": 150, "texture": preload("res://assets/card/2.png")},
	{"name": "Knight", "cost": 200, "texture": preload("res://assets/card/3.png")},
]

@onready var _hearts: Array[TextureRect] = [%Heart1, %Heart2, %Heart3]
@onready var _wave_label: Label = %WaveLabel
@onready var _gold_label: Label = %GoldAmount
@onready var _pause_button: TextureButton = %PauseButton
@onready var _build_buttons: Array[TextureButton] = [%BuildCard1, %BuildCard2, %BuildCard3, %BuildCard4]
@onready var _cost_labels: Array[Label] = [%Label1, %Label2, %Label3, %Label4]
@onready var _inspect_panel: PanelContainer = %InspectPanel
@onready var _inspect_title: Label = %InspectTitle
@onready var _damage_label: Label = %DamageLabel
@onready var _range_label: Label = %RangeLabel
@onready var _upgrade_button: Button = %UpgradeButton
@onready var _sell_button: Button = %SellButton

var _gold: int = 150
var _lives: int = 3
var _max_lives: int = 3

## Currently selected build card index, or -1 when none is selected.
## Mirrors the test scene's cards.gd selection behavior: hover scales up,
## clicking selects (stays popped), clicking the same card again deselects.
var selected_card_index: int = -1

const HOVER_SCALE := 1.1
const SELECTED_SCALE := 1.15


func _ready() -> void:
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_upgrade_button.pressed.connect(func() -> void: upgrade_pressed.emit())
	_sell_button.pressed.connect(func() -> void: sell_pressed.emit())
	for i: int in _build_buttons.size():
		var index := i
		if _build_buttons[i] != null:
			_setup_card_behavior(_build_buttons[i], index)
	_refresh_build_cards()
	_refresh_hearts()
	_inspect_panel.visible = false
	set_gold(_gold)


## --- API for gameplay systems to call -------------------------------------

func set_gold(amount: int) -> void:
	_gold = amount
	_gold_label.text = str(amount)
	_refresh_build_cards()


func set_wave(current: int, total: int) -> void:
	_wave_label.text = "Wave %d / %d" % [current, total]


func set_lives(current: int, max_lives: int = -1) -> void:
	if max_lives >= 0:
		_max_lives = max_lives
	_lives = clamp(current, 0, _max_lives)
	_refresh_hearts()


## Show the inspect panel for a selected tower/hero.
func show_tower_info(tower_name: String, damage: int, range_tiles: int, upgrade_cost: int = 100, sell_value: int = 50) -> void:
	_inspect_title.text = tower_name
	_damage_label.text = "Damage: %d" % damage
	_range_label.text = "Range: %d" % range_tiles
	_upgrade_button.text = "Upgrade (%d)" % upgrade_cost
	_sell_button.text = "Sell (%d)" % sell_value
	_inspect_panel.visible = true


func hide_tower_info() -> void:
	_inspect_panel.visible = false


func get_gold() -> int:
	return _gold


func clear_selection() -> void:
	selected_card_index = -1
	_refresh_selection_visuals()


func get_selected_cost() -> int:
	if selected_card_index >= 0 and selected_card_index < build_cards.size():
		return int(build_cards[selected_card_index]["cost"])
	return 0


## --- internals ---------------------------------------------------------------

func _setup_card_behavior(button: TextureButton, index: int) -> void:
	# Same feel as the test scene's cards.gd: pop from the center on hover,
	# stay popped while selected.
	button.pressed.connect(func() -> void: _on_build_card_pressed(index))
	button.pivot_offset = button.size / 2.0
	button.resized.connect(func() -> void: button.pivot_offset = button.size / 2.0)
	button.mouse_entered.connect(func() -> void:
		if selected_card_index != index:
			_animate_scale(button, Vector2(HOVER_SCALE, HOVER_SCALE)))
	button.mouse_exited.connect(func() -> void:
		if selected_card_index != index:
			_animate_scale(button, Vector2.ONE))


func _on_build_card_pressed(index: int) -> void:
	if index >= build_cards.size():
		return
	var card: Dictionary = build_cards[index]
	if selected_card_index == index:
		clear_selection()
		return
	if _gold < int(card["cost"]):
		print("Not enough gold for %s (%d needed, have %d)" % [card["name"], card["cost"], _gold])
		return
	selected_card_index = index
	_refresh_selection_visuals()
	build_card_selected.emit(index)


func _refresh_selection_visuals() -> void:
	for i: int in _build_buttons.size():
		var button: TextureButton = _build_buttons[i]
		if button == null:
			continue
		if i == selected_card_index:
			_animate_scale(button, Vector2(SELECTED_SCALE, SELECTED_SCALE))
		else:
			_animate_scale(button, Vector2.ONE)


func _animate_scale(node: Control, target_scale: Vector2, duration: float = 0.1) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", target_scale, duration)


func _refresh_build_cards() -> void:
	for i: int in _build_buttons.size():
		var button: TextureButton = _build_buttons[i]
		var cost_label: Label = _cost_labels[i]
		if button == null or cost_label == null:
			continue
		if i < build_cards.size():
			var card: Dictionary = build_cards[i]
			button.texture_normal = card["texture"]
			button.modulate = Color.WHITE if _gold >= int(card["cost"]) else Color(1, 1, 1, 0.45)
			cost_label.text = str(card["cost"])
			cost_label.visible = true
		else:
			button.texture_normal = null
			button.modulate = Color(1, 1, 1, 0.35)
			cost_label.visible = false


func _refresh_hearts() -> void:
	for i: int in _hearts.size():
		if _hearts[i] == null:
			continue
		if i < _lives:
			_hearts[i].modulate = Color.WHITE
		else:
			_hearts[i].modulate = Color(0.3, 0.3, 0.3, 0.5)
