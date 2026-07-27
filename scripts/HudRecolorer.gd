extends Reference

const ColorUtils = preload("res://DVHudHueMod/scripts/ColorUtils.gd")

const EXCLUDED_NODE_NAMES = [
	"ClassicMode",
	"Distortion",
	"CRT",
	"OLED",
	"BackBufferCopy",
	"RingTelescopeView",
	"CustomViewportContainer",
	"Video",
	"Offset"
]

static func apply_recolor(hud_root, basis_vectors):
	if not hud_root or not is_instance_valid(hud_root):
		return
		
	var v_r = basis_vectors.get("v_r", Vector3(1, 0, 0))
	var v_g = basis_vectors.get("v_g", Vector3(0, 1, 0))
	var v_b = basis_vectors.get("v_b", Vector3(0, 0, 1))
	
	var processed_resources = {}
	var stats = {"nodes": 0, "themes": 0, "styleboxes": 0, "script_colors": 0}
	_recolor_node_recursive(hud_root, v_r, v_g, v_b, processed_resources, stats)

static func _recolor_node_recursive(node, v_r, v_g, v_b, processed, stats):
	if not node or not is_instance_valid(node):
		return
		
	stats.nodes += 1
		
	if node is Control and node.theme:
		_recolor_theme(node.theme, v_r, v_g, v_b, processed, stats)
		
	var is_inside_telescope_feed = false
	var parent_check = node.get_parent()
	while parent_check:
		if parent_check.name in ["RingTelescopeView", "Video", "Offset", "CustomViewportContainer"]:
			is_inside_telescope_feed = true
			break
		parent_check = parent_check.get_parent()
		
	var is_viewport_texture_rect = (node is TextureRect) and (node.texture is ViewportTexture)
	if node.name == "TextureRect" and node.get_parent() and node.get_parent().name == "EnceladusFeed":
		is_viewport_texture_rect = true
		
	if node is Label and node.has_color_override("font_color"):
		var meta_key = "_orig_font_color_override"
		if not node.has_meta(meta_key):
			node.set_meta(meta_key, node.get_color("font_color"))
		var orig_fc = node.get_meta(meta_key)
		node.add_color_override("font_color", ColorUtils.recolor_color(orig_fc, v_r, v_g, v_b))

	if node.get_script() and not is_inside_telescope_feed:
		for p in node.get_property_list():
			if (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) and p.type == TYPE_COLOR and not p.name.begins_with("_"):
				var prop_name = p.name
				var val = node.get(prop_name)
				if val is Color and val != Color(1, 1, 1, 1) and val != Color(0, 0, 0, 0):
					var meta_key = "_orig_" + prop_name
					if not node.has_meta(meta_key):
						node.set_meta(meta_key, val)
					var orig_c = node.get_meta(meta_key)
					node.set(prop_name, ColorUtils.recolor_color(orig_c, v_r, v_g, v_b))
					stats.script_colors += 1
				
	var is_excluded = is_inside_telescope_feed or is_viewport_texture_rect or (node.name in EXCLUDED_NODE_NAMES) or ("Viewport" in node.name) or (node is ViewportContainer)
	if node is CanvasItem and not is_excluded:
		if node.modulate != Color(1, 1, 1, 1):
			if not node.has_meta("_orig_modulate"):
				node.set_meta("_orig_modulate", node.modulate)
			var orig_mod = node.get_meta("_orig_modulate")
			node.modulate = ColorUtils.recolor_color(orig_mod, v_r, v_g, v_b)
			
		if node.self_modulate != Color(1, 1, 1, 1):
			if not node.has_meta("_orig_self_modulate"):
				node.set_meta("_orig_self_modulate", node.self_modulate)
			var orig_self_mod = node.get_meta("_orig_self_modulate")
			node.self_modulate = ColorUtils.recolor_color(orig_self_mod, v_r, v_g, v_b)

	for child in node.get_children():
		_recolor_node_recursive(child, v_r, v_g, v_b, processed, stats)

static func _recolor_theme(theme, v_r, v_g, v_b, processed, stats):
	var res_id = theme.get_instance_id()
	if processed.has(res_id):
		return
	processed[res_id] = true
	stats.themes += 1
	
	var color_types = theme.get_type_list("color")
	for type_name in color_types:
		for color_name in theme.get_color_list(type_name):
			var meta_key = "_orig_col_" + type_name + "_" + color_name
			if not theme.has_meta(meta_key):
				theme.set_meta(meta_key, theme.get_color(color_name, type_name))
			var orig_c = theme.get_meta(meta_key)
			theme.set_color(color_name, type_name, ColorUtils.recolor_color(orig_c, v_r, v_g, v_b))
			
	var style_types = theme.get_type_list("stylebox")
	for type_name in style_types:
		for style_name in theme.get_stylebox_list(type_name):
			var sb = theme.get_stylebox(style_name, type_name)
			if sb is StyleBoxFlat:
				_recolor_stylebox_flat(sb, v_r, v_g, v_b, processed, stats)

static func _recolor_stylebox_flat(sb, v_r, v_g, v_b, processed, stats):
	var res_id = sb.get_instance_id()
	if processed.has(res_id):
		return
	processed[res_id] = true
	stats.styleboxes += 1
	
	if not sb.has_meta("_orig_bg_color"):
		sb.set_meta("_orig_bg_color", sb.bg_color)
	sb.bg_color = ColorUtils.recolor_color(sb.get_meta("_orig_bg_color"), v_r, v_g, v_b)
	
	if not sb.has_meta("_orig_border_color"):
		sb.set_meta("_orig_border_color", sb.border_color)
	sb.border_color = ColorUtils.recolor_color(sb.get_meta("_orig_border_color"), v_r, v_g, v_b)
	
	if not sb.has_meta("_orig_shadow_color"):
		sb.set_meta("_orig_shadow_color", sb.shadow_color)
	sb.shadow_color = ColorUtils.recolor_color(sb.get_meta("_orig_shadow_color"), v_r, v_g, v_b)
