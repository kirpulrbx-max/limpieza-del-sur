class_name InputSetup
extends RefCounted
## Registra las acciones de entrada por código (teclas físicas: funciona en QWERTY y AZERTY).

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_E],
	"remove": [KEY_X],
	"build_mode": [KEY_B],
	"rotate": [KEY_R],
	"menu": [KEY_TAB, KEY_I],
	"map": [KEY_M],
	"pause": [KEY_ESCAPE],
	"next_species": [KEY_Q],
	"quicksave": [KEY_F5],
	"quickload": [KEY_F9],
	"toggle_hud": [KEY_F1],
}


static func ensure_actions() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.has_action("primary"):
		InputMap.add_action("primary")
	InputMap.action_add_event("primary", click)
	var rclick := InputEventMouseButton.new()
	rclick.button_index = MOUSE_BUTTON_RIGHT
	if not InputMap.has_action("secondary"):
		InputMap.add_action("secondary")
	InputMap.action_add_event("secondary", rclick)
