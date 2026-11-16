class_name SettingsPanel
extends Control

## Reusable settings overlay with two views:
##   - Audio:  Music and Sound (SFX) volume sliders, written straight through to
##             the AudioSettings autoload (applied live and persisted).
##   - Manual: a short "How to Play" user manual (installing, navigation, play).
##
## Instance this scene under any menu that has a Settings button, then call
## open() / close(). It runs while the SceneTree is paused (process_mode ALWAYS)
## so it also works from the in-game pause menu.

signal closed

## Panel frame sizes. The manual view expands the panel so the text reads better.
const AUDIO_FRAME_SIZE := Vector2(720, 660)
const MANUAL_FRAME_SIZE := Vector2(1160, 704)

const MANUAL_TEXT := """[color=#ffce54][font_size=30][b]Installing[/b][/font_size][/color]
FantasyBlitz is a standalone game - there is nothing to install. Unzip the download and double-click [b]FantasyBlitz.exe[/b] (Windows) to play. To run it from source instead, open the project's project.godot in Godot 4.7 and press [b]F5[/b].

Your volume settings are saved automatically, so they carry over between sessions.

[color=#ffce54][font_size=30][b]Menus & Navigation[/b][/font_size][/color]
Use the [b]mouse[/b] for everything; press [b]Esc[/b] to back out of an open panel.

[ul]
[li][b]Title screen[/b] - Start Game, Settings, Exit.[/li]
[li][b]Settings[/b] - adjust Music and Sound, and read this manual.[/li]
[li][b]Pause menu[/b] (pause button, top-right) - Resume, Restart, Settings, Main Menu.[/li]
[li][b]End screen[/b] - shows the wave you reached and your kills, then Retry or Main Menu.[/li]
[/ul]

[color=#ffce54][font_size=30][b]How to Play[/b][/font_size][/color]
Enemies march along the road toward your base. Stop them before they reach the end - each one that gets through costs a [b]heart[/b]. You start with [b]3 hearts[/b] and must survive [b]10 waves[/b].

[b]Gold[/b] pays for towers. You start with 250. Every enemy you kill gives +12, and you earn +5 more every 4 seconds automatically.

[color=#ffd98a][b]Building a tower[/b][/color]
[ol]
[li]Click a hero card at the bottom-left: Archer, Wizard or Knight.[/li]
[li]Click a green grass tile to place it. Only grass tiles can be built on, and towers cannot overlap.[/li]
[/ol]

[color=#ffd98a][b]Heroes[/b][/color]
[ul]
[li][b]Archer[/b] - 100 gold, 25 damage, range 6. Cheap, with long reach.[/li]
[li][b]Wizard[/b] - 150 gold, 40 damage, range 5. Balanced.[/li]
[li][b]Knight[/b] - 200 gold, 60 damage, range 3. Heavy hitter, short range.[/li]
[/ul]

[color=#ffd98a][b]Managing towers[/b][/color]
Click a placed tower to open its info panel, then [b]Upgrade[/b] it for more damage and range, or [b]Sell[/b] it to get back half its cost.

[color=#ffce54][font_size=30][b]Tips[/b][/font_size][/color]
[ul]
[li]Build a couple of Archers early, where the path bends.[/li]
[li]Mix short-range Knights at corners with long-range Archers behind them.[/li]
[li]Upgrade a few key towers instead of flooding the map with cheap ones.[/li]
[li]Keep some gold in reserve for the later waves.[/li]
[/ul]"""

@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_value: Label = %SfxValue
@onready var _audio_view: Control = %AudioView
@onready var _manual_view: Control = %ManualView
@onready var _manual_text: RichTextLabel = %ManualText
@onready var _how_to_play_button: TextureButton = %HowToPlayButton
@onready var _back_button: TextureButton = %BackButton
@onready var _manual_back_button: TextureButton = %ManualBackButton
@onready var _frame: PanelContainer = %Frame

var _music: float = 1.0
var _sfx: float = 1.0
var _frame_tween: Tween


func _ready() -> void:
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_how_to_play_button.pressed.connect(_show_manual)
	_back_button.pressed.connect(close)
	_manual_back_button.pressed.connect(_show_audio)
	_manual_text.text = MANUAL_TEXT
	_sync_from_settings()
	_show_audio(false)


func _unhandled_input(event: InputEvent) -> void:
	# Esc closes the panel. Only while visible, so it never eats input meant
	# for the menu behind it.
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Show the panel, refreshed from the current saved volumes.
func open() -> void:
	_sync_from_settings()
	_show_audio(false)
	show()
	_back_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func is_open() -> bool:
	return visible


## --- view switching ----------------------------------------------------------

func _show_audio(animate: bool = true) -> void:
	_audio_view.visible = true
	_manual_view.visible = false
	_set_frame_size(AUDIO_FRAME_SIZE, animate)


func _show_manual() -> void:
	_audio_view.visible = false
	_manual_view.visible = true
	_set_frame_size(MANUAL_FRAME_SIZE, true)
	if visible:
		_manual_back_button.grab_focus()


## Grow / shrink the panel between the two views. The frame is centred
## (anchors 0.5, 0.5), so symmetric offsets resize it in place.
func _set_frame_size(target_size: Vector2, animate: bool) -> void:
	var half := target_size * 0.5
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()
	if not animate:
		_frame.offset_left = -half.x
		_frame.offset_top = -half.y
		_frame.offset_right = half.x
		_frame.offset_bottom = half.y
		return
	_frame_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_frame_tween.tween_property(_frame, "offset_left", -half.x, 0.3)
	_frame_tween.tween_property(_frame, "offset_top", -half.y, 0.3)
	_frame_tween.tween_property(_frame, "offset_right", half.x, 0.3)
	_frame_tween.tween_property(_frame, "offset_bottom", half.y, 0.3)


## --- internals ---------------------------------------------------------------

func _sync_from_settings() -> void:
	_music = AudioSettings.get_music_volume()
	_sfx = AudioSettings.get_sfx_volume()
	# set_value_no_signal so pulling the stored value in doesn't echo back out.
	_music_slider.set_value_no_signal(_music)
	_sfx_slider.set_value_no_signal(_sfx)
	_update_labels()


func _on_music_changed(value: float) -> void:
	_music = value
	AudioSettings.set_music_volume(value)
	_update_labels()


func _on_sfx_changed(value: float) -> void:
	_sfx = value
	AudioSettings.set_sfx_volume(value)
	_update_labels()


func _update_labels() -> void:
	_music_value.text = "%d%%" % roundi(_music * 100.0)
	_sfx_value.text = "%d%%" % roundi(_sfx * 100.0)