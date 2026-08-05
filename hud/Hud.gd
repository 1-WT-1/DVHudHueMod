extends "res://hud/Hud.gd"

const HudRecolorer = preload("res://DVHudHueMod/scripts/HudRecolorer.gd")
const ColorUtils = preload("res://DVHudHueMod/scripts/ColorUtils.gd")

var _mod_pointers: Node = null
var _subscribed: bool = false
var _recolor_queued: bool = false
var _cached_shift_data: Dictionary = {}
var _last_options_hash: int = 0

var _mod_options: Dictionary = {
	"color_space": "HSV",
	"hdr_extraction_mode": "Unclamped",
	"overlap": 0.0,
	"lightness_mode": "HDR Multiplier",
	"master_lightness": 1.0, "master_chroma": 1.0, "master_hue": 0.0,
	"r_lightness": 1.0, "r_chroma": 1.0, "r_hue": 0.0,
	"y_lightness": 1.0, "y_chroma": 1.0, "y_hue": 0.0,
	"g_lightness": 1.0, "g_chroma": 1.0, "g_hue": 0.0,
	"c_lightness": 1.0, "c_chroma": 1.0, "c_hue": 0.0,
	"b_lightness": 1.0, "b_chroma": 1.0, "b_hue": 0.0,
	"m_lightness": 1.0, "m_chroma": 1.0, "m_hue": 0.0
}

func _ready() -> void:
	get_tree().connect("node_added", self, "_on_scene_tree_node_added")
	_queue_recolor()

func _on_scene_tree_node_added(node: Node) -> void:
	if is_a_parent_of(node):
		_queue_recolor()

func _queue_recolor() -> void:
	if ship and not ship.isPlayerControlled():
		return

	if not _recolor_queued:
		_recolor_queued = true
		call_deferred("_fetch_and_apply_recolor")

func _fetch_and_apply_recolor() -> void:
	_recolor_queued = false

	if not _mod_pointers and CurrentGame and CurrentGame.get_tree():
		_mod_pointers = CurrentGame.get_tree().get_root().get_node_or_null("HevLib~Pointers")

	if _mod_pointers and "ConfigDriver" in _mod_pointers:
		var cfg_keys: Array = [
			"color_space", "hdr_extraction_mode", "overlap", "lightness_mode",
			"master_lightness", "master_chroma", "master_hue",
			"r_lightness", "r_chroma", "r_hue",
			"y_lightness", "y_chroma", "y_hue",
			"g_lightness", "g_chroma", "g_hue",
			"c_lightness", "c_chroma", "c_hue",
			"b_lightness", "b_chroma", "b_hue",
			"m_lightness", "m_chroma", "m_hue"
		]

		for k in cfg_keys:
			if not _subscribed:
				_mod_pointers.ConfigDriver.__subscribe_to_setting_change("_on_setting_updated", self, "DVHudHueMod", "DVHUDHUE_OPTIONS", k)
			
			var val = _mod_pointers.ConfigDriver.__get_value("DVHudHueMod", "DVHUDHUE_OPTIONS", k)
			if val != null:
				_mod_options[k] = val
		
		_subscribed = true

	var current_hash: int = _mod_options.hash()
	var shift_changed: bool = false

	if current_hash != _last_options_hash or _cached_shift_data.empty():
		_cached_shift_data = ColorUtils.get_shift_data(_mod_options)
		_last_options_hash = current_hash
		shift_changed = true

	if shift_changed or not _cached_shift_data.get("is_identity", false):
		HudRecolorer.apply_recolor(self, _cached_shift_data)

func _on_setting_updated(_val = null, _a1 = null, _a2 = null, _a3 = null) -> void:
	_queue_recolor()

func instance() -> void:
	.instance()
	_queue_recolor()
