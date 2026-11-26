extends Node
## Audio 100% procedural: los efectos se sintetizan al arrancar (sin archivos externos)
## y la música ambiental es generativa (pad de acordes + campanas pentatónicas).

const RATE := 22050

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _pad_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer
var _bell: AudioStreamWAV
var _bell_timer := 2.0
var _rng := RandomNumberGenerator.new()
var _pad_task := -1
var _pad_stream: AudioStreamWAV

const PENTA := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]


func _ready() -> void:
	_setup_buses()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_build_sounds()
	_pad_player = AudioStreamPlayer.new()
	_pad_player.bus = "Music"
	_pad_player.volume_db = -9.0
	add_child(_pad_player)
	_wind_player = AudioStreamPlayer.new()
	_wind_player.bus = "Music"
	_wind_player.volume_db = -20.0
	_wind_player.stream = _make_wind()
	add_child(_wind_player)
	_pad_task = WorkerThreadPool.add_task(_render_pad)
	apply_volumes()


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.6
		rev.wet = 0.18
		AudioServer.add_bus_effect(sfx, rev)


func _exit_tree() -> void:
	if _pad_task != -1:
		WorkerThreadPool.wait_for_task_completion(_pad_task)
		_pad_task = -1


func apply_volumes() -> void:
	var s: Dictionary = SaveManager.settings
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(s.master_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(s.music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(s.sfx_volume, 0.0001)))


func _process(delta: float) -> void:
	if _pad_task != -1 and WorkerThreadPool.is_task_completed(_pad_task):
		WorkerThreadPool.wait_for_task_completion(_pad_task)
		_pad_task = -1
		_pad_player.stream = _pad_stream
		_pad_player.play()
		_wind_player.play()
	if not GameState.running:
		return
	_bell_timer -= delta
	if _bell_timer <= 0.0:
		_bell_timer = _rng.randf_range(2.5, 7.0) / (0.6 + GameState.vitality)
		var p := _get_player()
		p.stream = _bell
		p.pitch_scale = pow(2.0, PENTA[_rng.randi() % PENTA.size()] / 12.0)
		p.volume_db = -22.0 + 8.0 * GameState.vitality
		p.bus = "Music"
		p.play()


func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _sounds.has(name):
		return
	var p := _get_player()
	p.bus = "SFX"
	p.stream = _sounds[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _get_player() -> AudioStreamPlayer:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	return p


# --------------------------------------------------------------------------------------
# Síntesis
# --------------------------------------------------------------------------------------

func _to_wav(samples: PackedFloat32Array, loop := false, rate := RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _tone(freqs: Array, dur: float, decay: float, vol := 0.5, sweep := 0.0, attack := 0.004) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / attack, 1.0) * exp(-t * decay)
		var v := 0.0
		for f in freqs:
			var ff: float = f * (1.0 + sweep * t)
			v += sin(TAU * ff * t) + 0.25 * sin(TAU * ff * 2.0 * t)
		out[i] = v / freqs.size() * env * vol
	return out


func _concat(parts: Array, gap: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var step := int(gap * RATE)
	var total := step * (parts.size() - 1) + (parts[-1] as PackedFloat32Array).size()
	out.resize(total)
	for pi in parts.size():
		var p: PackedFloat32Array = parts[pi]
		for i in p.size():
			var j := pi * step + i
			if j < total:
				out[j] += p[i]
	return out


func _noise_burst(dur: float, decay: float, vol: float, lp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y += (_rng.randf_range(-1.0, 1.0) - y) * lp
		out[i] = y * exp(-t * decay) * vol
	return out


func _build_sounds() -> void:
	_rng.seed = 42
	var c6 := 1046.5
	_sounds["collect"] = _to_wav(_tone([c6, c6 * 1.26], 0.35, 9.0, 0.35))
	_sounds["light"] = _to_wav(_tone([c6 * 1.5, c6 * 2.0], 0.5, 6.0, 0.28))
	_sounds["seed"] = _to_wav(_concat([_tone([784.0], 0.3, 10.0, 0.3), _tone([1175.0], 0.4, 8.0, 0.3)], 0.07))
	_sounds["pop"] = _to_wav(_tone([600.0], 0.12, 30.0, 0.45, 6.0))
	var splash := _noise_burst(0.35, 9.0, 0.5, 0.25)
	var drip := _tone([900.0], 0.2, 18.0, 0.3, -1.5)
	for i in drip.size():
		splash[i] += drip[i]
	_sounds["water"] = _to_wav(splash)
	_sounds["plant"] = _to_wav(_concat([_noise_burst(0.15, 25.0, 0.5, 0.08), _tone([523.0, 659.0, 784.0], 0.6, 5.0, 0.3)], 0.06))
	_sounds["buy"] = _to_wav(_concat([_tone([659.0], 0.3, 8.0, 0.3), _tone([784.0], 0.3, 8.0, 0.3), _tone([1046.0], 0.5, 6.0, 0.3)], 0.07))
	_sounds["error"] = _to_wav(_concat([_tone([220.0, 233.0], 0.14, 12.0, 0.3), _tone([196.0, 208.0], 0.2, 10.0, 0.3)], 0.12))
	_sounds["click"] = _to_wav(_tone([1800.0], 0.05, 60.0, 0.2))
	_sounds["hover"] = _to_wav(_tone([2400.0], 0.03, 90.0, 0.08))
	_sounds["levelup"] = _to_wav(_concat([_tone([523.0, 784.0], 0.8, 3.0, 0.25), _tone([659.0, 988.0], 0.8, 3.0, 0.25),
		_tone([784.0, 1175.0], 0.8, 3.0, 0.25), _tone([1046.0, 1568.0], 1.2, 2.5, 0.25)], 0.11))
	_sounds["mission"] = _to_wav(_concat([_tone([880.0, 1320.0], 0.5, 5.0, 0.25), _tone([1175.0, 1760.0], 0.7, 4.0, 0.25)], 0.1))
	_sounds["build"] = _to_wav(_concat([_noise_burst(0.2, 15.0, 0.4, 0.15), _tone([392.0, 587.0], 0.5, 5.0, 0.3), _tone([784.0], 0.5, 6.0, 0.25)], 0.08))
	_sounds["step"] = _to_wav(_noise_burst(0.09, 40.0, 0.22, 0.12))
	_sounds["bloom"] = _to_wav(_concat([_tone([1318.0], 0.4, 7.0, 0.25), _tone([1568.0], 0.4, 7.0, 0.25), _tone([2093.0], 0.6, 5.0, 0.22)], 0.05))
	_bell = _to_wav(_tone([523.25, 523.25 * 3.01], 2.5, 1.6, 0.35))


func _make_wind() -> AudioStreamWAV:
	var n := RATE * 6
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var y2 := 0.0
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in n:
		var t := float(i) / n
		y += (r.randf_range(-1.0, 1.0) - y) * 0.02
		y2 += (y - y2) * 0.05
		var swell := 0.6 + 0.4 * sin(TAU * t * 2.0)
		# Fundido en los extremos para que el bucle no haga clic.
		var edge := minf(1.0, minf(t, 1.0 - t) * 20.0)
		out[i] = y2 * 2.5 * swell * edge
	return _to_wav(out, true)


## Pad ambiental de 32 s (Cmaj9 - Am9 - Fmaj7 - G6sus) renderizado en un hilo.
func _render_pad() -> void:
	var chords := [
		[130.81, 196.0, 246.94, 329.63, 293.66],
		[110.0, 164.81, 261.63, 329.63, 246.94],
		[87.31, 174.61, 220.0, 261.63, 329.63],
		[98.0, 146.83, 196.0, 293.66, 329.63],
	]
	var seg := 8.0
	var pr := 16000
	var n := int(seg * chords.size() * pr)
	var out := PackedFloat32Array()
	out.resize(n)
	var seg_n := int(seg * pr)
	for ci in chords.size():
		var notes: Array = chords[ci]
		for i in range(-pr * 2, seg_n + pr * 2):
			var idx := ci * seg_n + i
			var wrapped := posmod(idx, n)
			var t := float(i) / pr
			# Envolvente con solapamiento de 2 s entre acordes (fundido cruzado).
			var env := clampf((t + 2.0) / 3.0, 0.0, 1.0) * clampf((seg + 2.0 - t) / 3.0, 0.0, 1.0)
			if env <= 0.0:
				continue
			var tt := float(idx) / pr
			var v := 0.0
			for f in notes:
				v += sin(TAU * f * tt) + 0.5 * sin(TAU * f * 1.003 * tt + 1.3)
			var lfo := 0.75 + 0.25 * sin(TAU * 0.11 * tt)
			out[wrapped] += v * env * lfo * 0.045
	_pad_stream = _to_wav(out, true, pr)
