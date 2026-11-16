extends Control

## Pause menu. Runs while the SceneTree is paused (process_mode = ALWAYS) so its
## buttons stay responsive. Uses the same chunky cartoon button nodes as the
## title screen for a consistent look.

@onready var _resume_button: TextureButton = %ResumeButton
@onready var _restart_button: TextureButton = %RestartButton
@onready var _settings_button: TextureButton = %SettingsButton
@onready var _main_menu_button: TextureButton = %MainMenuButton
@onready var _settings_panel: SettingsPanel = $SettingsPanel


func _ready() -> void:
	_resume_button.pressed.connect(_on_resume_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_resume_button.grab_focus()
	## Set the custom crystal mouse cursor (grey-crystal style, CC-BY inspired).
	Input.set_custom_mouse_cursor(
		preload("res://assets/generated/cursor_crystal.png"),
		Input.CURSOR_ARROW,
		Vector2(2, 2)
	)


func _unhandled_input(event: InputEvent) -> void:
	# Only react to Esc while the pause menu is actually open, so it never
	# interferes with other overlays (e.g. the defeat screen or the settings
	# panel, which closes itself first).
	if event.is_action_pressed("ui_cancel") and visible:
		if _settings_panel.is_open():
			_settings_panel.close()
		else:
			_on_resume_pressed()
		get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	get_tree().paused = false
	hide()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_settings_pressed() -> void:
	_settings_panel.open()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/Title_Screen.tscn")
