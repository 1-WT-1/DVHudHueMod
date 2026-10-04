extends Reference

const ColorUtils = preload("res://DVHudHueMod/scripts/ColorUtils.gd")

const EXCLUDED_NODE_NAMES: Array = [
	"ClassicMode",
	"Distortion",
	"CRT",
	"OLED",
	"BackBufferCopy",
	"RingTelescopeView",
	"CustomViewportContainer",
	"Video"
]

const TELESCOPE_NODE_NAMES: Array = [
	"RingTelescopeView",
	"Video",
	"CustomViewportContainer",
	"EnceladusFeed"
]

static func apply_recolor(hud_root: Node, shift_data: Dictionary) -> void:
	if not hud_root or not is_instance_valid(hud_root):
		return

	var current_hash: int = shift_data["hash"]
	var global_processed: Dictionary = {}
	if hud_root.has_meta("_global_processed_resources") and hud_root.has_meta("_last_shift_hash") and hud_root.get_meta("_last_shift_hash") == current_hash:
		global_processed = hud_root.get_meta("_global_processed_resources")
	else:
		hud_root.set_meta("_global_processed_resources", global_processed)
		hud_root.set_meta("_last_shift_hash", current_hash)

	var manifests: Array = []
	_recolor_node_recursive(hud_root, shift_data, global_processed, false, current_hash, manifests)
	for m in manifests:
		_sync_cargo_manifest(m)

static func _recolor_node_recursive(node: Node, shift_data: Dictionary, processed: Dictionary, is_inside_telescope: bool, current_hash: int, manifests: Array) -> void:
	if not node or not is_instance_valid(node):
		return

	if not is_inside_telescope and node.name in TELESCOPE_NODE_NAMES:
		is_inside_telescope = true

	var node_already_processed: bool = false
	if node.has_meta("_last_processed_hash") and node.get_meta("_last_processed_hash") == current_hash:
		node_already_processed = true
	else:
		node.set_meta("_last_processed_hash", current_hash)

	if not node_already_processed:
		if node is Control and node.theme:
			_recolor_theme(node.theme, shift_data, processed)

		var is_viewport_texture_rect: bool = (node is TextureRect) and (node.texture is ViewportTexture)
		if node.name == "TextureRect" and is_inside_telescope:
			is_viewport_texture_rect = true

		if node is Label:
			if node.has_color_override("font_color"):
				var current_c = node.get_color("font_color")
				if not node.has_meta("_orig_font_color_override"):
					node.set_meta("_orig_font_color_override", current_c)
				elif node.has_meta("_last_font_color_override"):
					node.set_meta("_orig_font_color_override", ColorUtils.update_orig_color_if_needed(current_c, node.get_meta("_orig_font_color_override"), node.get_meta("_last_font_color_override")))
				var shifted_c = ColorUtils.recolor_color(node.get_meta("_orig_font_color_override"), shift_data)
				node.add_color_override("font_color", shifted_c)
				node.set_meta("_last_font_color_override", shifted_c)

			if node.has_color_override("font_color_shadow"):
				var current_c = node.get_color("font_color_shadow")
				if not node.has_meta("_orig_font_shadow_override"):
					node.set_meta("_orig_font_shadow_override", current_c)
				elif node.has_meta("_last_font_shadow_override"):
					node.set_meta("_orig_font_shadow_override", ColorUtils.update_orig_color_if_needed(current_c, node.get_meta("_orig_font_shadow_override"), node.get_meta("_last_font_shadow_override")))
				var shifted_c = ColorUtils.recolor_color(node.get_meta("_orig_font_shadow_override"), shift_data)
				node.add_color_override("font_color_shadow", shifted_c)
				node.set_meta("_last_font_shadow_override", shifted_c)

		if node.get_script() and not is_inside_telescope:
			var script_vars: Dictionary = {}
			if node.has_meta("_orig_script_colors"):
				script_vars = node.get_meta("_orig_script_colors")
			
			var script_dicts: Dictionary = {}
			if node.has_meta("_orig_script_dict_colors"):
				script_dicts = node.get_meta("_orig_script_dict_colors")

			for p in node.get_property_list():
				if (p.usage & (PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_EDITOR)) and not p.name.begins_with("_"):
					if p.type == TYPE_COLOR and not p.name in ["modulate", "self_modulate", "color", "default_color"]:
						var current_c = node.get(p.name)
						if current_c is Color:
							var meta_key = "_last_script_color_" + p.name
							if not script_vars.has(p.name):
								script_vars[p.name] = current_c
							elif node.has_meta(meta_key):
								script_vars[p.name] = ColorUtils.update_orig_color_if_needed(current_c, script_vars[p.name], node.get_meta(meta_key))
					elif p.type == TYPE_DICTIONARY:
						var current_dict = node.get(p.name)
						if current_dict is Dictionary:
							var orig_dict: Dictionary = script_dicts.get(p.name, {})
							var meta_key = "_last_script_dict_" + p.name
							var last_dict: Dictionary = node.get_meta(meta_key) if node.has_meta(meta_key) else {}
							var dict_has_color: bool = false
							for k in current_dict:
								var val = current_dict[k]
								if val is Color:
									dict_has_color = true
									if not orig_dict.has(k):
										orig_dict[k] = val
									elif last_dict.has(k):
										orig_dict[k] = ColorUtils.update_orig_color_if_needed(val, orig_dict[k], last_dict[k])

							if p.name == "colorOverrides" and ("scanArea" in node or "mineralColor" in node):
								if not orig_dict.has("CARGO_EQUIPMENT"):
									orig_dict["CARGO_EQUIPMENT"] = Color(0.0, 1.0, 0.0)
								dict_has_color = true

							if dict_has_color:
								script_dicts[p.name] = orig_dict
			
			node.set_meta("_orig_script_colors", script_vars)

			for prop_name in script_vars:
				var shifted_c = ColorUtils.recolor_color(script_vars[prop_name], shift_data)
				node.set(prop_name, shifted_c)
				node.set_meta("_last_script_color_" + prop_name, shifted_c)

			node.set_meta("_orig_script_dict_colors", script_dicts)

			for prop_name in script_dicts:
				var target_dict = node.get(prop_name)
				if target_dict is Dictionary:
					var new_dict = target_dict.duplicate()
					var last_dict: Dictionary = {}
					for k in script_dicts[prop_name]:
						var orig_c: Color = script_dicts[prop_name][k]
						var shifted_c = ColorUtils.recolor_color(orig_c, shift_data)
						new_dict[k] = shifted_c
						last_dict[k] = shifted_c
					node.set(prop_name, new_dict)
					node.set_meta("_last_script_dict_" + prop_name, last_dict)

		var is_excluded: bool = is_inside_telescope or is_viewport_texture_rect or (node.name in EXCLUDED_NODE_NAMES) or ("Viewport" in node.name) or (node is ViewportContainer)

		if node.name == "Ship" and node is Sprite:
			is_excluded = false

		if node is CanvasItem and not is_excluded:
			var mod = node.modulate
			if mod != Color(1.0, 1.0, 1.0, 1.0) or node.has_meta("_orig_modulate"):
				if not node.has_meta("_orig_modulate"):
					node.set_meta("_orig_modulate", mod)
				elif node.has_meta("_last_modulate"):
					node.set_meta("_orig_modulate", ColorUtils.update_orig_color_if_needed(mod, node.get_meta("_orig_modulate"), node.get_meta("_last_modulate")))
				var shifted_c = ColorUtils.recolor_color(node.get_meta("_orig_modulate"), shift_data)
				node.modulate = shifted_c
				node.set_meta("_last_modulate", shifted_c)

			var self_mod = node.self_modulate
			if self_mod != Color(1.0, 1.0, 1.0, 1.0) or node.has_meta("_orig_self_modulate"):
				if not node.has_meta("_orig_self_modulate"):
					node.set_meta("_orig_self_modulate", self_mod)
				elif node.has_meta("_last_self_modulate"):
					node.set_meta("_orig_self_modulate", ColorUtils.update_orig_color_if_needed(self_mod, node.get_meta("_orig_self_modulate"), node.get_meta("_last_self_modulate")))
				var shifted_c = ColorUtils.recolor_color(node.get_meta("_orig_self_modulate"), shift_data)
				node.self_modulate = shifted_c
				node.set_meta("_last_self_modulate", shifted_c)

	if "colors" in node and "scanner" in node:
		manifests.append(node)
		return

	for i in range(node.get_child_count()):
		var child = node.get_child(i)
		if child is Timer or child is AnimationPlayer or child is Tween or child is AudioStreamPlayer or child is AudioStreamPlayer2D or child is AudioStreamPlayer3D:
			continue

		_recolor_node_recursive(child, shift_data, processed, is_inside_telescope, current_hash, manifests)

static func _recolor_theme(theme: Theme, shift_data: Dictionary, processed: Dictionary) -> void:
	var res_id: int = theme.get_instance_id()
	if processed.has(res_id):
		return
	processed[res_id] = true

	var orig_colors: Dictionary = {}
	if theme.has_meta("_orig_colors"):
		orig_colors = theme.get_meta("_orig_colors")

	var color_types: Array = theme.get_type_list("color")
	for type_name in color_types:
		var type_str: String = type_name
		for color_name in theme.get_color_list(type_str):
			var c_name: String = color_name
			var dict_key: String = type_str + "|" + c_name

			if not orig_colors.has(dict_key):
				orig_colors[dict_key] = theme.get_color(c_name, type_str)

			theme.set_color(c_name, type_str, ColorUtils.recolor_color(orig_colors[dict_key], shift_data))

	if not theme.has_meta("_orig_colors"):
		theme.set_meta("_orig_colors", orig_colors)

	var style_types: Array = theme.get_type_list("stylebox")
	for type_name in style_types:
		for style_name in theme.get_stylebox_list(type_name):
			var sb = theme.get_stylebox(style_name, type_name)
			if sb is StyleBoxFlat:
				_recolor_stylebox_flat(sb as StyleBoxFlat, shift_data, processed)

static func _recolor_stylebox_flat(sb: StyleBoxFlat, shift_data: Dictionary, processed: Dictionary) -> void:
	var res_id: int = sb.get_instance_id()
	if processed.has(res_id):
		return
	processed[res_id] = true

	if sb.draw_center:
		if not sb.has_meta("_orig_bg_color"):
			sb.set_meta("_orig_bg_color", sb.bg_color)
		sb.bg_color = ColorUtils.recolor_color(sb.get_meta("_orig_bg_color"), shift_data)

	if sb.border_width_left > 0 or sb.border_width_right > 0 or sb.border_width_top > 0 or sb.border_width_bottom > 0:
		if not sb.has_meta("_orig_border_color"):
			sb.set_meta("_orig_border_color", sb.border_color)
		sb.border_color = ColorUtils.recolor_color(sb.get_meta("_orig_border_color"), shift_data)

	if sb.shadow_size > 0:
		if not sb.has_meta("_orig_shadow_color"):
			sb.set_meta("_orig_shadow_color", sb.shadow_color)
		sb.shadow_color = ColorUtils.recolor_color(sb.get_meta("_orig_shadow_color"), shift_data)

static func _sync_cargo_manifest(node: Node) -> void:
	if not node or not is_instance_valid(node):
		return

	if "colors" in node and node.get("colors") is Dictionary:
		var scanner_node = null
		if "scannerNode" in node and node.scannerNode:
			scanner_node = node.scannerNode
		elif "scanner" in node and node.scanner:
			scanner_node = node.get_node_or_null(node.scanner)

		if scanner_node and "colorOverrides" in scanner_node and scanner_node.colorOverrides is Dictionary:
			for m in scanner_node.colorOverrides:
				node.colors[m] = scanner_node.colorOverrides[m]

