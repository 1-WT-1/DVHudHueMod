extends Reference

static func oklch_to_rgb(L, C, h_deg):
	var h_rad = deg2rad(h_deg)
	var a = C * cos(h_rad)
	var b = C * sin(h_rad)
	
	var l_prime = L + 0.3963377774 * a + 0.2158037573 * b
	var m_prime = L - 0.1055613458 * a - 0.0638541728 * b
	var s_prime = L - 0.0894841775 * a - 1.2914855480 * b
	
	var l = l_prime * l_prime * l_prime
	var m = m_prime * m_prime * m_prime
	var s = s_prime * s_prime * s_prime
	
	var r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
	var g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
	var b_val = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
	
	return Vector3(max(0.0, r), max(0.0, g), max(0.0, b_val))

static func rgb_to_oklch(rgb):
	var r = rgb.x
	var g = rgb.y
	var b_val = rgb.z
	
	var l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b_val
	var m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b_val
	var s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b_val
	
	var l_prime = sign(l) * pow(abs(l), 1.0 / 3.0)
	var m_prime = sign(m) * pow(abs(m), 1.0 / 3.0)
	var s_prime = sign(s) * pow(abs(s), 1.0 / 3.0)
	
	var L = 0.2104542553 * l_prime + 0.7936177850 * m_prime - 0.0040720468 * s_prime
	var a = 1.9779984951 * l_prime - 2.4285922050 * m_prime + 0.4505937099 * s_prime
	var b = 0.0259040371 * l_prime + 0.7827717662 * m_prime - 0.8086758033 * s_prime
	
	var C = sqrt(a * a + b * b)
	var h_deg = rad2deg(atan2(b, a))
	if h_deg < 0.0:
		h_deg += 360.0
		
	return [L, C, h_deg]

static func transform_channel_oklch(base_rgb, l_mult, c_mult, h_shift):
	var oklch = rgb_to_oklch(base_rgb)
	var L = oklch[0] * l_mult
	var C = oklch[1] * c_mult
	var h = fmod(oklch[2] + h_shift, 360.0)
	if h < 0.0:
		h += 360.0
	return oklch_to_rgb(L, C, h)

static func transform_channel_hsv(base_rgb, l_mult, c_mult, h_shift):
	var col = Color(base_rgb.x, base_rgb.y, base_rgb.z)
	var h = fmod(col.h * 360.0 + h_shift, 360.0) / 360.0
	if h < 0.0:
		h += 1.0
	var s = clamp(col.s * c_mult, 0.0, 1.0)
	var v = col.v * l_mult
	var new_col = Color.from_hsv(h, s, v)
	return Vector3(new_col.r, new_col.g, new_col.b)

static func compute_basis_vectors(opts):
	var mode = opts.get("color_space", "HSV")
	
	var r_l = opts.get("r_lightness", 1.0)
	var r_c = opts.get("r_chroma", 1.0)
	var r_h = opts.get("r_hue", 0.0)
	
	var g_l = opts.get("g_lightness", 1.0)
	var g_c = opts.get("g_chroma", 1.0)
	var g_h = opts.get("g_hue", 0.0)
	
	var b_l = opts.get("b_lightness", 1.0)
	var b_c = opts.get("b_chroma", 1.0)
	var b_h = opts.get("b_hue", 0.0)
	
	var base_r = Vector3(1.0, 0.0, 0.0)
	var base_g = Vector3(0.0, 1.0, 0.0)
	var base_b = Vector3(0.0, 0.0, 1.0)
	
	var v_r = Vector3()
	var v_g = Vector3()
	var v_b = Vector3()
	
	if mode == "HSV":
		v_r = transform_channel_hsv(base_r, r_l, r_c, r_h)
		v_g = transform_channel_hsv(base_g, g_l, g_c, g_h)
		v_b = transform_channel_hsv(base_b, b_l, b_c, b_h)
	else:
		v_r = transform_channel_oklch(base_r, r_l, r_c, r_h)
		v_g = transform_channel_oklch(base_g, g_l, g_c, g_h)
		v_b = transform_channel_oklch(base_b, b_l, b_c, b_h)
		
	return {
		"v_r": v_r,
		"v_g": v_g,
		"v_b": v_b
	}

static func recolor_color(c, v_r, v_g, v_b):
	var r_new = max(0.0, c.r * v_r.x + c.g * v_g.x + c.b * v_b.x)
	var g_new = max(0.0, c.r * v_r.y + c.g * v_g.y + c.b * v_b.y)
	var b_new = max(0.0, c.r * v_r.z + c.g * v_g.z + c.b * v_b.z)
	return Color(r_new, g_new, b_new, c.a)
