extends Node

## Global audio settings (autoload name: "AudioSettings").
##
## Owns the linear volume of the Music and SFX buses, applies it live, and
## persists it to user://settings.cfg so the player's choice survives restarts.
## The settings panel (UI/SettingsPanel.gd) is the only UI that writes here,
## but any gameplay code can call play_sfx() to route a one-shot through the
## SFX bus (so it obeys the sound slider).

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "audio"

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

## Linear volumes (0.0 .. 1.0) applied on a first run.
const DEFAULT_MUSIC_VOLUME := 0.8
const DEFAULT_SFX_VOLUME := 1.0

## At or below this linear value a bus is muted outright (avoids -inf dB).
const SILENCE_THRESHOLD := 0.001
const SILENCE_DB := -80.0

signal music_volume_changed(volume: float)
signal sfx_volume_changed(volume: float)

var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME

var _save_timer: Timer


func _ready() -> void:
	# Keep SFX audible even while the SceneTree is paused (pause menu clicks).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.3
	_save_timer.timeout.connect(_save)
	add_child(_save_timer)

	_load()
	_apply_all()


## --- public API --------------------------------------------------------------

func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	_apply_bus(MUSIC_BUS, music_volume)
	music_volume_changed.emit(music_volume)
	_schedule_save()


func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	_apply_bus(SFX_BUS, sfx_volume)
	sfx_volume_changed.emit(sfx_volume)
	_schedule_save()


func get_music_volume() -> float:
	return music_volume


func get_sfx_volume() -> float:
	return sfx_volume


## Play a one-shot sound through the SFX bus. The player is freed when done.
func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SFX_BUS
	player.volume_db = volume_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## --- internals ---------------------------------------------------------------

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _apply_all() -> void:
	_apply_bus(MUSIC_BUS, music_volume)
	_apply_bus(SFX_BUS, sfx_volume)


func _apply_bus(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	if volume <= SILENCE_THRESHOLD:
		AudioServer.set_bus_mute(index, true)
		AudioServer.set_bus_volume_db(index, SILENCE_DB)
	else:
		AudioServer.set_bus_mute(index, false)
		AudioServer.set_bus_volume_db(index, linear_to_db(volume))


func _schedule_save() -> void:
	if _save_timer != null:
		_save_timer.start()


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.save(CONFIG_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	music_volume = clampf(float(config.get_value(SECTION, "music_volume", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value(SECTION, "sfx_volume", DEFAULT_SFX_VOLUME)), 0.0, 1.0)