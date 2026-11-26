extends Node
## Guardado/carga en JSON (user://), autoguardado, ajustes y progreso offline.

signal saved
signal loaded
signal offline_report(seconds: float, gains: Dictionary)

const SAVE_PATH := "user://ecosystem_save.json"
const BACKUP_PATH := "user://ecosystem_save.bak.json"
const SETTINGS_PATH := "user://settings.cfg"
const VERSION := 1

var settings := {
	"mouse_sensitivity": 0.0025,
	"invert_y": false,
	"fov": 75.0,
	"master_volume": 0.8,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"offline_enabled": true,
	"offline_hours": 8,
	"autosave_seconds": 30,
	"grass_density": 1.0,
	"shadows": true,
	"fullscreen": false,
	"show_fps": false,
}

var save_path := SAVE_PATH
var _autosave_timer := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--save="):
			save_path = a.substr(7)
	load_settings()


func _process(delta: float) -> void:
	if not GameState.running:
		return
	_autosave_timer += delta
	if _autosave_timer >= float(settings.autosave_seconds):
		_autosave_timer = 0.0
		save_game(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and GameState.running:
		save_game(true)


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game(silent := false) -> bool:
	var data := {
		"version": VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"state": GameState.serialize(),
	}
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(_backup_path()))
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo guardar: %s" % FileAccess.get_open_error())
		GameState.notify.emit("Error al guardar la partida", "bad")
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	if not silent:
		GameState.notify.emit("Partida guardada", "info")
	saved.emit()
	return true


func _backup_path() -> String:
	return save_path.get_basename() + ".bak.json"


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("state"):
		return {}
	return parsed


## Carga la partida. Devuelve false si no hay guardado válido.
func load_game(apply_offline := true) -> bool:
	var data := _read(save_path)
	if data.is_empty():
		data = _read(_backup_path())
		if data.is_empty():
			return false
		GameState.notify.emit("Guardado dañado: se cargó la copia de seguridad", "warn")
	GameState.deserialize(data.state)
	GameState.world_reset.emit()
	loaded.emit()
	if apply_offline:
		var elapsed := Time.get_unix_time_from_system() - float(data.get("timestamp", 0.0))
		apply_offline_progress(elapsed)
	return true


func delete_save() -> void:
	for p in [save_path, _backup_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Simula el tiempo transcurrido fuera del juego con la eficiencia configurada.
func apply_offline_progress(elapsed: float) -> Dictionary:
	if not settings.offline_enabled or elapsed < 30.0:
		return {}
	var max_s := GameState.offline_max_hours() * 3600.0
	var t := minf(elapsed, max_s)
	var eff := GameState.offline_efficiency()
	var sim_time := t * eff
	var before := GameState.res.duplicate()
	var steps := int(clampf(sim_time / 1.0, 1.0, 3000.0))
	var dt := sim_time / steps
	for i in steps:
		GameState.tick(dt)
	var gains := {}
	for k in before:
		var g: float = GameState.res[k] - before[k]
		if absf(g) > 0.01:
			gains[k] = g
	offline_report.emit(t, gains)
	GameState.world_reset.emit()
	return gains


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in settings:
			settings[k] = cfg.get_value("settings", k, settings[k])
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)
	apply_settings()


func apply_settings() -> void:
	if DisplayServer.get_name() != "headless":
		var fs: bool = settings.fullscreen
		var mode := DisplayServer.window_get_mode()
		if fs and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not fs and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if has_node("/root/Audio"):
		get_node("/root/Audio").apply_volumes()
