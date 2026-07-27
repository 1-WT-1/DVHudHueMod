extends "res://hud/Hud.gd"

const HudRecolorer = preload("res://DVHudHueMod/scripts/HudRecolorer.gd")
const ColorUtils = preload("res://DVHudHueMod/scripts/ColorUtils.gd")

var _mod_pointers = null
var _subscribed = false
var _mod_options = {
	"color_space": "HSV",
	"r_lightness": 1.0, "r_chroma": 1.0, "r_hue": 0.0,
	"g_lightness": 1.0, "g_chroma": 1.0, "g_hue": 0.0,
	"b_lightness": 1.0, "b_chroma": 1.0, "b_hue": 0.0
}

func _ready():
	pause_mode = PAUSE_MODE_PROCESS
	connect("child_entered_tree", self, "_on_any_child_entered")
	var huds_container = get_node_or_null("Huds")
	if huds_container:
		huds_container.connect("child_entered_tree", self, "_on_any_child_entered")
		
	call_deferred("_init_hud_hue_recolor")

func _notification(what):
	if what == NOTIFICATION_UNPAUSED:
		call_deferred("_fetch_and_apply_recolor")

func _on_any_child_entered(_node):
	call_deferred("_fetch_and_apply_recolor")

func _init_hud_hue_recolor():
	_ensure_pointers()
	_fetch_and_apply_recolor()
	_subscribe_config_changes()

func _ensure_pointers():
	if not _mod_pointers:
		_mod_pointers = get_tree().get_root().get_node_or_null("HevLib~Pointers")
	if not _mod_pointers and CurrentGame:
		_mod_pointers = CurrentGame.get_tree().get_root().get_node_or_null("HevLib~Pointers")

func _fetch_and_apply_recolor():
	_ensure_pointers()
	if not _subscribed:
		_subscribe_config_changes()
		
	var cfg_keys = [
		"color_space",
		"r_lightness", "r_chroma", "r_hue",
		"g_lightness", "g_chroma", "g_hue",
		"b_lightness", "b_chroma", "b_hue"
	]
	
	if _mod_pointers and "ConfigDriver" in _mod_pointers:
		for k in cfg_keys:
			var val = _mod_pointers.ConfigDriver.__get_value("wt.DVHudHueMod", "DVHUDHUE_OPTIONS", k)
			if val == null:
				val = _mod_pointers.ConfigDriver.__get_value("DVHudHueMod", "DVHUDHUE_OPTIONS", k)
			if val != null:
				_mod_options[k] = val

	var basis = ColorUtils.compute_basis_vectors(_mod_options)
	HudRecolorer.apply_recolor(self, basis)

func _subscribe_config_changes():
	_ensure_pointers()
	if _mod_pointers and "ConfigDriver" in _mod_pointers:
		_mod_pointers.ConfigDriver.__subscribe_to_setting_change("_on_setting_updated", self, "wt.DVHudHueMod", "DVHUDHUE_OPTIONS", "")
		_mod_pointers.ConfigDriver.__subscribe_to_setting_change("_on_setting_updated", self, "DVHudHueMod", "DVHUDHUE_OPTIONS", "")
		_subscribed = true

func _on_setting_updated(_val = null, _a1 = null, _a2 = null, _a3 = null):
	_fetch_and_apply_recolor()

func instance():
	.instance()
	call_deferred("_fetch_and_apply_recolor")
