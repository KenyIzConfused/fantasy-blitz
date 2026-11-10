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
## "scene" is the tower PackedScene placed when the player clicks the map
## with that card selected. Extend this array if you add more cards.
var build_cards: Array[Dictionary] = [
	{"name": "Archer", "cost": 100, "damage": 25, "range": 6, "texture": preload("res://assets/card/1.png"), "scene": preload("res://tower/archer.tscn")},
	{"name": "Wizard", "cost": 150, "damage": 40, "range": 5, "texture": preload("res://assets/card/2.png"), "scene": preload("res://tower/wizard.tscn")},
	{"name": "Knight", "cost": 200, "damage": 60, "range": 3, "texture": preload("res://assets/card/3.png"), "scene": preload("res://tower/knight.tscn")},
]

## Tower placement: click a card, then click a grass tile.
## The grid and buildability rules live in TileGrid so the HUD and the hover
## marker (maps/camera_3d.gd) always agree on where a tower can go.
const TOWERS_ROOT_NAME := "Towers"
const TOWER_GROUP := "towers"

## Minimum gap between two towers so their bases never overlap.
const MIN_TOWER_SPACING := 1.5

## Fraction of a tower's cost refunded when it is sold.
const SELL_REFUND_RATIO := 0.5

@onready var _hearts: Array[TextureRect] = [%Heart1, %Heart2, %Heart3]
@onready var _wave_label: Label = %WaveLabel
@onready var _gold_label: Label = %GoldAmount
@onready var _pause_button: TextureButton = %PauseButton
@onready var _build_buttons: Array[TextureButton] = [%BuildCard1, %BuildCard2, %BuildCard3]
@onready var _cost_labels: Array[Label] = [%Label1, %Label2, %Label3]
@onready var _inspect_panel: PanelContainer = %InspectPanel
@onready var _inspect_title: Label = %InspectTitle
@onready var _damage_label: Label = %DamageLabel
@onready var _range_label: Label = %RangeLabel
@onready var _upgrade_button: Button = %UpgradeButton
@onready var _sell_button: Button = %SellButton
@onready var _inspect_close_button: Button = %InspectCloseButton

var _gold: int = 100
var _lives: int = 3
var _max_lives: int = 3

## Currently selected build card index, or -1 when none is selected.
## Mirrors the test scene's cards.gd selection behavior: hover scales up,
## clicking selects (stays popped), clicking the same card again deselects.
var selected_card_index: int = -1

## Tower scene tied to the currently selected card, or null when none is selected.
var selected_tower_scene: PackedScene = null

## Tower currently inspected (clicked in the world), or null.
var _selected_tower: Node3D = null

const HOVER_SCALE := 1.1
const SELECTED_SCALE := 1.15

## Size of the click-feedback ring in pixels.
const CLICK_RING_SIZE := 46.0


func _ready() -> void:
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_sell_button.pressed.connect(_on_sell_pressed)
	_inspect_close_button.pressed.connect(hide_tower_info)
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


## Add (or subtract, with a negative amount) gold. The label always reflects _gold.
func add_gold(amount: int) -> void:
	set_gold(_gold + amount)


func set_wave(current: int, total: int = 0) -> void:
	if total > 0:
		_wave_label.text = "Wave %d / %d" % [current, total]
	else:
		_wave_label.text = "Wave %d" % current


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
	_upgrade_button.text = "Upgrade (%d)" % upgrade_cost if upgrade_cost > 0 else "Max Level"
	_upgrade_button.disabled = upgrade_cost <= 0
	_sell_button.text = "Sell (%d)" % sell_value
	_inspect_panel.visible = true


func hide_tower_info() -> void:
	_inspect_panel.visible = false
	_selected_tower = null


func get_gold() -> int:
	return _gold


func clear_selection() -> void:
	selected_card_index = -1
	selected_tower_scene = null
	_refresh_selection_visuals()


func get_selected_cost() -> int:
	if selected_card_index >= 0 and selected_card_index < build_cards.size():
		return int(build_cards[selected_card_index]["cost"])
	return 0


## --- tower placement (like camera_3d.gd) ------------------------------------

## Clicks that reach the world place the selected tower, or inspect/sell a
## tower that was clicked. _unhandled_input means clicking a HUD button never
## leaks through to the map.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("click"):
		return
	if selected_tower_scene != null:
		_try_place_tower()
	else:
		_try_select_tower()


func _try_place_tower() -> void:
	var result := _raycast_world()
	if result.is_empty():
		return

	# 1. Only grass tiles are buildable - never the enemy path (spawner,
	#    straights, corners, end). This is the same rule the hover marker uses.
	if not TileGrid.is_buildable_tile(result.get("collider")):
		print("You can only build on grass tiles.")
		return

	# 2. Snap the hit point onto the tile the cursor is over.
	var hit: Vector3 = result["position"]
	var cell := TileGrid.snap_to_tile(hit)

	# 3. Keep a gap between towers so their bases never overlap.
	if _is_cell_occupied(cell):
		print("Too close to another tower.")
		return

	# 4. Pay for it, spawn it, and clear the selection.
	if _gold < get_selected_cost():
		return
	var tower_root := _get_tower_root()
	if tower_root == null:
		return
	var card: Dictionary = build_cards[selected_card_index]
	add_gold(-get_selected_cost())
	var tower := selected_tower_scene.instantiate() as Node3D
	tower.position = cell
	tower.set_meta("card", card)
	tower.add_to_group(TOWER_GROUP)
	tower_root.add_child(tower)
	_selected_tower = null
	clear_selection()
	hide_tower_info()


## Click a placed tower to inspect it and offer the sell button.
## Hits the tower body directly, or the nearest tower within one tile of the
## ground point clicked (the body collision is small, so this is forgiving).
func _try_select_tower() -> void:
	var result := _raycast_world()
	if result.is_empty():
		return
	var tower := _tower_from_collider(result.get("collider"))
	if tower == null:
		tower = _nearest_tower(result["position"], TileGrid.CELL_SIZE)
	if tower == null:
		hide_tower_info()
		return
	_select_tower(tower)


func _nearest_tower(point: Vector3, max_distance: float) -> Node3D:
	var best: Node3D = null
	var best_distance := max_distance
	for node: Node in get_tree().get_nodes_in_group(TOWER_GROUP):
		if node is Node3D:
			var distance: float = (node as Node3D).global_position.distance_to(point)
			if distance <= best_distance:
				best_distance = distance
				best = node as Node3D
	return best


func _select_tower(tower: Node3D) -> void:
	_selected_tower = tower
	var card: Dictionary = tower.get_meta("card", {})
	var tower_name: String = str(card.get("name", "Tower"))
	var damage: int = int(card.get("damage", 0))
	var range_tiles: int = int(card.get("range", 0))
	var cost: int = int(card.get("cost", 0))

	# Prefer the tower's live values - they grow with its upgrade level.
	var level: int = 1
	if tower.has_method("get_level"):
		level = int(tower.call("get_level"))
	if tower.has_method("get_damage"):
		damage = int(tower.call("get_damage"))
	if tower.has_method("get_range"):
		range_tiles = int(round(float(tower.call("get_range"))))
	var upgrade_cost: int = cost
	if tower.has_method("upgrade_cost"):
		upgrade_cost = int(tower.call("upgrade_cost"))

	var title: String = tower_name if level <= 1 else "%s  Lv%d" % [tower_name, level]
	show_tower_info(title, damage, range_tiles, upgrade_cost, int(round(cost * SELL_REFUND_RATIO)))


## Walk up from a ray collider to the tower node it belongs to, if any.
func _tower_from_collider(collider: Object) -> Node3D:
	var node := collider as Node
	while node != null:
		if node.is_in_group(TOWER_GROUP) and node is Node3D:
			return node as Node3D
		node = node.get_parent()
	return null


## Buy the next level for the inspected tower, if it can be afforded.
func _on_upgrade_pressed() -> void:
	var tower := _selected_tower
	if not is_instance_valid(tower) or not tower.has_method("upgrade"):
		upgrade_pressed.emit()
		return
	var cost: int = int(tower.call("upgrade_cost"))
	if cost <= 0:
		upgrade_pressed.emit()
		return
	if _gold < cost:
		print("Not enough gold to upgrade (%d needed, have %d)" % [cost, _gold])
		upgrade_pressed.emit()
		return
	add_gold(-cost)
	tower.call("upgrade")
	_select_tower(tower)   # refresh the panel with the new stats
	upgrade_pressed.emit()


func _on_sell_pressed() -> void:
	var tower := _selected_tower
	if is_instance_valid(tower):
		var card: Dictionary = tower.get_meta("card", {})
		var cost: int = int(card.get("cost", 0))
		add_gold(int(round(cost * SELL_REFUND_RATIO)))
		tower.queue_free()
	hide_tower_info()
	sell_pressed.emit()


## Raycast from the mouse into the 3D world. Empty Dictionary on a miss.
func _raycast_world() -> Dictionary:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	var world := viewport.find_world_3d()
	if camera == null or world == null:
		return {}
	var mouse_pos := viewport.get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 1000.0
	var query := PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	return world.direct_space_state.intersect_ray(query)


func _is_cell_occupied(cell: Vector3) -> bool:
	for node: Node in get_tree().get_nodes_in_group(TOWER_GROUP):
		if node is Node3D and (node as Node3D).global_position.distance_to(cell) < MIN_TOWER_SPACING:
			return true
	return false


## Towers live under a single container in the 3D scene, created on demand.
func _get_tower_root() -> Node3D:
	var scene := get_tree().current_scene
	if scene == null or not scene is Node3D:
		return null
	var root := scene.get_node_or_null(TOWERS_ROOT_NAME)
	if root == null:
		root = Node3D.new()
		root.name = TOWERS_ROOT_NAME
		scene.add_child(root)
	return root as Node3D


## --- click feedback ----------------------------------------------------------

## Pop a short ring where the mouse clicked, for tactile feedback.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_spawn_click_ring((event as InputEventMouseButton).position)


func _spawn_click_ring(pos: Vector2) -> void:
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2(CLICK_RING_SIZE, CLICK_RING_SIZE)
	ring.position = pos - ring.size * 0.5
	ring.pivot_offset = ring.size * 0.5
	ring.scale = Vector2(0.35, 0.35)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.92, 0.6, 0.25)
	style.border_color = Color(1.0, 0.95, 0.7, 0.9)
	style.set_border_width_all(3)
	style.set_corner_radius_all(int(CLICK_RING_SIZE * 0.5))
	ring.add_theme_stylebox_override("panel", style)

	add_child(ring)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.7, 1.7), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.finished.connect(ring.queue_free)


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
	_selected_tower = null
	selected_card_index = index
	selected_tower_scene = card.get("scene") as PackedScene
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
