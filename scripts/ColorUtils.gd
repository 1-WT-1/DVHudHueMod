extends Reference

const ANGLES_HSV: Array = [0.0, 60.0, 120.0, 180.0, 240.0, 300.0]
const ANGLES_OKLCH: Array = [29.3, 109.7, 142.5, 196.5, 264.1, 327.2]
const CUSP_ANGLES_OKLCH: Array = [29.3, 109.7, 142.5, 196.5, 264.1, 327.2]
const CUSP_VALUES_OKLCH: Array = [0.63, 0.96, 0.87, 0.80, 0.45, 0.70]
const PREFIXES: Array = ["r", "y", "g", "c", "b", "m"]

const TOE_K1: float = 0.206
const TOE_K2: float = 0.03
const TOE_K3: float = (1.0 + TOE_K1) / (1.0 + TOE_K2)
const ONE_THIRD: float = 1.0 / 3.0

static func oklch_to_rgb(L: float, C: float, h_deg: float) -> Vector3:
	var h_rad: float = deg2rad(h_deg)
	var a: float = C * cos(h_rad)
	var b: float = C * sin(h_rad)
	
	var l_prime: float = L + 0.3963377774 * a + 0.2158037573 * b
	var m_prime: float = L - 0.1055613458 * a - 0.0638541728 * b
	var s_prime: float = L - 0.0894841775 * a - 1.2914855480 * b
	
	var l: float = l_prime * l_prime * l_prime
	var m: float = m_prime * m_prime * m_prime
	var s: float = s_prime * s_prime * s_prime
	
	var r: float = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
	var g: float = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
	var b_val: float = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
	
	return Vector3(max(0.0, r), max(0.0, g), max(0.0, b_val))

static func rgb_to_oklch(rgb: Vector3) -> Vector3:
	var r: float = rgb.x
	var g: float = rgb.y
	var b_val: float = rgb.z
	
	var l: float = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b_val
	var m: float = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b_val
	var s: float = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b_val
	
	var l_prime: float = sign(l) * pow(abs(l), 1.0 / 3.0)
	var m_prime: float = sign(m) * pow(abs(m), 1.0 / 3.0)
	var s_prime: float = sign(s) * pow(abs(s), 1.0 / 3.0)
	
	var L: float = 0.2104542553 * l_prime + 0.7936177850 * m_prime - 0.0040720468 * s_prime
	var a: float = 1.9779984951 * l_prime - 2.4285922050 * m_prime + 0.4505937099 * s_prime
	var b: float = 0.0259040371 * l_prime + 0.7827717662 * m_prime - 0.8086757660 * s_prime
	
	var C: float = sqrt(a * a + b * b)
	var h_deg: float = wrapf(rad2deg(atan2(b, a)), 0.0, 360.0)
		
	return Vector3(L, C, h_deg)

static func _angle_dist(a1: float, a2: float) -> float:
	var diff: float = abs(a1 - a2)
	return 360.0 - diff if diff > 180.0 else diff

static func _signed_angle_diff(from_angle: float, to_angle: float) -> float:
	return wrapf(to_angle - from_angle + 180.0, 0.0, 360.0) - 180.0

static func get_shift_data(opts: Dictionary) -> Dictionary:
	var mode: String = opts.get("color_space", "HSV")
	var angles: Array = ANGLES_OKLCH if mode.begins_with("OK") else ANGLES_HSV

	var prefixes: Array = PREFIXES

	var channels: Array = []
	channels.resize(6)
	for i in range(6):
		var prev_idx: int = (i + 5) % 6
		var next_idx: int = (i + 1) % 6
		var gap_l: float = _angle_dist(angles[prev_idx], angles[i])
		var gap_r: float = _angle_dist(angles[i], angles[next_idx])
		var prefix: String = prefixes[i]
		
		channels[i] = [
			angles[i],
			gap_l / 2.0,
			gap_r / 2.0,
			opts.get(prefix + "_lightness", 1.0),
			opts.get(prefix + "_chroma", 1.0),
			opts.get(prefix + "_hue", 0.0)
		]

	var mode_int: int = 1
	if mode == "OKLCH": mode_int = 0
	elif mode == "HSV": mode_int = 1
	elif mode == "HSL": mode_int = 2
	elif mode == "OKHSV": mode_int = 3
	elif mode == "OKHSL": mode_int = 4

	var is_identity: bool = (
		opts.get("master_lightness", 1.0) == 1.0 and
		opts.get("master_chroma", 1.0) == 1.0 and
		opts.get("master_hue", 0.0) == 0.0
	)
	if is_identity:
		for i in range(6):
			var prefix: String = prefixes[i]
			if opts.get(prefix + "_lightness", 1.0) != 1.0 or \
			   opts.get(prefix + "_chroma", 1.0) != 1.0 or \
			   opts.get(prefix + "_hue", 0.0) != 0.0:
				is_identity = false
				break

	return {
		"mode": mode,
		"mode_int": mode_int,
		"is_identity": is_identity,
		"overlap": opts.get("overlap", 0.0) / 100.0,
		"is_gimp_clamp": opts.get("lightness_mode", "HDR Multiplier") == "GIMP Clamp",
		"master_l": opts.get("master_lightness", 1.0) - 1.0,
		"master_c": opts.get("master_chroma", 1.0) - 1.0,
		"master_h": opts.get("master_hue", 0.0),
		"channels": channels,
		"hash": opts.hash()
	}

static func _get_cusp_lightness(h_deg: float) -> float:
	var h: float = wrapf(h_deg, 0.0, 360.0)
	
	for i in range(6):
		var i_next: int = (i + 1) % 6
		var a1: float = CUSP_ANGLES_OKLCH[i]
		var a2: float = CUSP_ANGLES_OKLCH[i_next]
		
		if i == 5:
			if h >= a1 or h < a2:
				var dist: float = wrapf(a2 - a1, 0.0, 360.0)
				var progress: float = wrapf(h - a1, 0.0, 360.0)
				var t: float = progress / max(0.001, dist)
				return lerp(CUSP_VALUES_OKLCH[i], CUSP_VALUES_OKLCH[i_next], t)
		else:
			if h >= a1 and h < a2:
				var t: float = (h - a1) / (a2 - a1)
				return lerp(CUSP_VALUES_OKLCH[i], CUSP_VALUES_OKLCH[i_next], t)
				
	return 0.75

static func recolor_theme(theme: Theme, shift_data: Dictionary) -> void:
	pass

static func update_orig_color_if_needed(current_c: Color, orig_c: Color, last_c: Color) -> Color:
	var r1 = int(current_c.r * 255.0)
	var g1 = int(current_c.g * 255.0)
	var b1 = int(current_c.b * 255.0)
	var r2 = int(last_c.r * 255.0)
	var g2 = int(last_c.g * 255.0)
	var b2 = int(last_c.b * 255.0)
	
	if abs(r1 - r2) > 1 or abs(g1 - g2) > 1 or abs(b1 - b2) > 1:
		return current_c
	
	if abs(current_c.a - last_c.a) > 0.01:
		orig_c.a = current_c.a
		return orig_c
		
	return orig_c

static func recolor_color(c: Color, shift_data: Dictionary) -> Color:
	if shift_data.get("is_identity", false):
		return c

	var h_orig: float = 0.0
	var L_or_v: float = 0.0
	var C_or_s: float = 0.0
	var mode_int: int = shift_data.get("mode_int", 1)
	
	var max_val: float = c.v
	var hdr_multiplier: float = 1.0
	var c_sdr: Color = c
	if max_val > 1.0:
		hdr_multiplier = max_val
		c_sdr = Color(c.r / max_val, c.g / max_val, c.b / max_val, c.a)

	if mode_int == 0:
		var linear_c: Color = to_linear(c_sdr)
		var oklch: Vector3 = rgb_to_oklch(Vector3(linear_c.r, linear_c.g, linear_c.b))
		L_or_v = oklch.x
		C_or_s = oklch.y
		h_orig = oklch.z
	elif mode_int == 1:
		h_orig = c_sdr.h * 360.0
		C_or_s = c_sdr.s
		L_or_v = c_sdr.v
	elif mode_int == 2:
		var hsl: Vector3 = rgb_to_hsl(Vector3(c_sdr.r, c_sdr.g, c_sdr.b))
		h_orig = hsl.x * 360.0
		C_or_s = hsl.y
		L_or_v = hsl.z
	elif mode_int == 3:
		var okhsv: Vector3 = srgb_to_okhsv(Vector3(c_sdr.r, c_sdr.g, c_sdr.b))
		h_orig = okhsv.x * 360.0
		C_or_s = okhsv.y
		L_or_v = okhsv.z
	elif mode_int == 4:
		var okhsl: Vector3 = srgb_to_okhsl(Vector3(c_sdr.r, c_sdr.g, c_sdr.b))
		h_orig = okhsl.x * 360.0
		C_or_s = okhsl.y
		L_or_v = okhsl.z

	var overlap: float = shift_data["overlap"]
	var total_h_shift: float = shift_data["master_h"]
	var total_c_mult: float = shift_data["master_c"]
	var total_l_shift: float = shift_data["master_l"]

	for ch in shift_data["channels"]:
		var s_diff: float = _signed_angle_diff(ch[0], h_orig)
		var diff: float = abs(s_diff)
		var half_gap: float = ch[2] if s_diff >= 0.0 else ch[1]

		var tw: float = half_gap * overlap
		var t_in: float = half_gap - tw
		var t_out: float = half_gap + tw

		var weight: float = 0.0
		if diff <= t_in:
			weight = 1.0
		elif diff < t_out and tw > 0.0:
			weight = 1.0 - ((diff - t_in) / (2.0 * tw))
			
		if weight > 0.0:
			total_h_shift += ch[5] * weight
			total_c_mult += (ch[4] - 1.0) * weight
			total_l_shift += (ch[3] - 1.0) * weight
			
	total_c_mult = max(0.0, 1.0 + total_c_mult)
	var h_new: float = wrapf(h_orig + total_h_shift, 0.0, 360.0)
	var val_new: float = L_or_v

	if shift_data["is_gimp_clamp"]:
		if total_l_shift > 0.0:
			val_new += (total_l_shift * (1.0 - val_new))
		elif total_l_shift < 0.0:
			val_new *= (total_l_shift + 1.0)
	else:
		val_new *= (1.0 + total_l_shift)
		
	val_new = max(0.0, val_new)

	var out_c: Color = c_sdr
	if mode_int == 0:
		var rgb: Vector3 = oklch_to_rgb(val_new, C_or_s * total_c_mult, h_new)
		out_c = to_srgb(Color(rgb.x, rgb.y, rgb.z, c.a))
	elif mode_int == 1:
		out_c = Color.from_hsv(h_new / 360.0, clamp(C_or_s * total_c_mult, 0.0, 1.0), val_new, c.a)
	elif mode_int == 2:
		var rgb: Vector3 = hsl_to_rgb(Vector3(h_new / 360.0, clamp(C_or_s * total_c_mult, 0.0, 1.0), clamp(val_new, 0.0, 1.0)))
		out_c = Color(rgb.x, rgb.y, rgb.z, c.a)
	elif mode_int == 3:
		var rgb: Vector3 = okhsv_to_srgb(Vector3(h_new / 360.0, clamp(C_or_s * total_c_mult, 0.0, 1.0), clamp(val_new, 0.0, 1.0)))
		out_c = Color(rgb.x, rgb.y, rgb.z, c.a)
	elif mode_int == 4:
		var rgb: Vector3 = okhsl_to_srgb(Vector3(h_new / 360.0, clamp(C_or_s * total_c_mult, 0.0, 1.0), clamp(val_new, 0.0, 1.0)))
		out_c = Color(rgb.x, rgb.y, rgb.z, c.a)

	return Color(out_c.r * hdr_multiplier, out_c.g * hdr_multiplier, out_c.b * hdr_multiplier, c.a)

static func _srgb_to_linear_channel(c: float) -> float:
	if c <= 0.04045:
		return c / 12.92
	else:
		return pow((c + 0.055) / 1.055, 2.4)

static func _linear_to_srgb_channel(c: float) -> float:
	if c <= 0.0031308:
		return c * 12.92
	else:
		return 1.055 * pow(c, 1.0 / 2.4) - 0.055

static func to_linear(c: Color) -> Color:
	return Color(
		_srgb_to_linear_channel(c.r),
		_srgb_to_linear_channel(c.g),
		_srgb_to_linear_channel(c.b),
		c.a
	)

static func to_srgb(c: Color) -> Color:
	return Color(
		_linear_to_srgb_channel(c.r),
		_linear_to_srgb_channel(c.g),
		_linear_to_srgb_channel(c.b),
		c.a
	)

static func _cbrt(x: float) -> float:
	return sign(x) * pow(abs(x), ONE_THIRD)

static func rgb_to_hsl(rgb: Vector3) -> Vector3:
	var r: float = rgb.x
	var g: float = rgb.y
	var b: float = rgb.z
	var max_val: float = max(r, max(g, b))
	var min_val: float = min(r, min(g, b))
	var h: float = 0.0
	var s: float = 0.0
	var l: float = (max_val + min_val) / 2.0

	if max_val != min_val:
		var d: float = max_val - min_val
		s = d / (2.0 - max_val - min_val) if l > 0.5 else d / (max_val + min_val)
		if max_val == r:
			h = (g - b) / d + (6.0 if g < b else 0.0)
		elif max_val == g:
			h = (b - r) / d + 2.0
		elif max_val == b:
			h = (r - g) / d + 4.0
		h /= 6.0

	return Vector3(h, s, l)

static func _hue_to_rgb(p: float, q: float, t: float) -> float:
	if t < 0.0:
		t += 1.0
	if t > 1.0:
		t -= 1.0
	if t < 1.0 / 6.0:
		return p + (q - p) * 6.0 * t
	if t < 1.0 / 2.0:
		return q
	if t < 2.0 / 3.0:
		return p + (q - p) * (2.0 / 3.0 - t) * 6.0
	return p

static func hsl_to_rgb(hsl: Vector3) -> Vector3:
	var h: float = hsl.x
	var s: float = hsl.y
	var l: float = hsl.z
	var r: float = l
	var g: float = l
	var b: float = l

	if s != 0.0:
		var q: float = l * (1.0 + s) if l < 0.5 else l + s - l * s
		var p: float = 2.0 * l - q
		r = _hue_to_rgb(p, q, h + 1.0 / 3.0)
		g = _hue_to_rgb(p, q, h)
		b = _hue_to_rgb(p, q, h - 1.0 / 3.0)

	return Vector3(r, g, b)

static func linear_srgb_to_oklab(rgb: Vector3) -> Vector3:
	var r: float = rgb.x
	var g: float = rgb.y
	var b: float = rgb.z
	
	var l: float = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
	var m: float = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
	var s: float = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

	var l_: float = _cbrt(l)
	var m_: float = _cbrt(m)
	var s_: float = _cbrt(s)

	return Vector3(
		0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
		1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
		0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
	)

static func oklab_to_linear_srgb(lab: Vector3) -> Vector3:
	var L: float = lab.x
	var a: float = lab.y
	var b: float = lab.z
	
	var l_: float = L + 0.3963377774 * a + 0.2158037573 * b
	var m_: float = L - 0.1055613458 * a - 0.0638541728 * b
	var s_: float = L - 0.0894841775 * a - 1.2914855480 * b

	var l: float = l_ * l_ * l_
	var m: float = m_ * m_ * m_
	var s: float = s_ * s_ * s_

	return Vector3(
		4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
	)

static func toe(x: float) -> float:
	return 0.5 * (TOE_K3 * x - TOE_K1 + sqrt((TOE_K3 * x - TOE_K1) * (TOE_K3 * x - TOE_K1) + 4.0 * TOE_K2 * TOE_K3 * x))

static func toe_inv(x: float) -> float:
	return (x * x + TOE_K1 * x) / (TOE_K3 * (x + TOE_K2))

static func compute_max_saturation(a: float, b: float) -> float:
	var k0: float
	var k1: float
	var k2: float
	var k3: float
	var k4: float
	var wl: float
	var wm: float
	var ws: float

	if -1.88170328 * a - 0.80936493 * b > 1.0:
		k0 = +1.19086277; k1 = +1.76576728; k2 = +0.59662641; k3 = +0.75515197; k4 = +0.56771245
		wl = +4.0767416621; wm = -3.3077115913; ws = +0.2309699292
	elif 1.81444104 * a - 1.19445276 * b > 1.0:
		k0 = +0.73956515; k1 = -0.45954404; k2 = +0.08285427; k3 = +0.12541070; k4 = +0.14503204
		wl = -1.2684380046; wm = +2.6097574011; ws = -0.3413193965
	else:
		k0 = +1.35733652; k1 = -0.00915799; k2 = -1.15130210; k3 = -0.50559606; k4 = +0.00692167
		wl = -0.0041960863; wm = -0.7034186147; ws = +1.7076147010

	var S: float = k0 + k1 * a + k2 * b + k3 * a * a + k4 * a * b

	var k_l: float = +0.3963377774 * a + 0.2158037573 * b
	var k_m: float = -0.1055613458 * a - 0.0638541728 * b
	var k_s: float = -0.0894841775 * a - 1.2914855480 * b

	var l_: float = 1.0 + S * k_l
	var m_: float = 1.0 + S * k_m
	var s_: float = 1.0 + S * k_s

	var l: float = l_ * l_ * l_
	var m: float = m_ * m_ * m_
	var s: float = s_ * s_ * s_

	var l_dS: float = 3.0 * k_l * l_ * l_
	var m_dS: float = 3.0 * k_m * m_ * m_
	var s_dS: float = 3.0 * k_s * s_ * s_

	var l_dS2: float = 6.0 * k_l * k_l * l_
	var m_dS2: float = 6.0 * k_m * k_m * m_
	var s_dS2: float = 6.0 * k_s * k_s * s_

	var f: float = wl * l + wm * m + ws * s
	var f1: float = wl * l_dS + wm * m_dS + ws * s_dS
	var f2: float = wl * l_dS2 + wm * m_dS2 + ws * s_dS2

	var divisor: float = f1 * f1 - 0.5 * f * f2
	if abs(divisor) > 1e-6:
		S = S - f * f1 / divisor
	return S

static func find_cusp(a: float, b: float) -> Vector2:
	var S_cusp: float = compute_max_saturation(a, b)
	var rgb_at_max: Vector3 = oklab_to_linear_srgb(Vector3(1.0, S_cusp * a, S_cusp * b))
	var max_rgb: float = max(max(rgb_at_max.x, rgb_at_max.y), rgb_at_max.z)
	var L_cusp: float = _cbrt(1.0 / max_rgb) if abs(max_rgb) > 1e-6 else 0.0
	var C_cusp: float = L_cusp * S_cusp
	return Vector2(L_cusp, C_cusp)

static func find_gamut_intersection(a: float, b: float, L1: float, C1: float, L0: float, cusp: Vector2 = Vector2(-1.0, -1.0)) -> float:
	if cusp.x == -1.0:
		cusp = find_cusp(a, b)

	var t: float = 0.0
	if ((L1 - L0) * cusp.y - (cusp.x - L0) * C1) <= 0.0:
		t = cusp.y * L0 / (C1 * cusp.x + cusp.y * (L0 - L1))
	else:
		t = cusp.y * (L0 - 1.0) / (C1 * (cusp.x - 1.0) + cusp.y * (L0 - L1))
		
		var dL: float = L1 - L0
		var dC: float = C1

		var k_l: float = +0.3963377774 * a + 0.2158037573 * b
		var k_m: float = -0.1055613458 * a - 0.0638541728 * b
		var k_s: float = -0.0894841775 * a - 1.2914855480 * b

		var l_dt: float = dL + dC * k_l
		var m_dt: float = dL + dC * k_m
		var s_dt: float = dL + dC * k_s

		var L: float = L0 * (1.0 - t) + t * L1
		var C: float = t * C1

		var l_: float = L + C * k_l
		var m_: float = L + C * k_m
		var s_: float = L + C * k_s

		var l: float = l_ * l_ * l_
		var m: float = m_ * m_ * m_
		var s: float = s_ * s_ * s_

		var ldt: float = 3.0 * l_dt * l_ * l_
		var mdt: float = 3.0 * m_dt * m_ * m_
		var sdt: float = 3.0 * s_dt * s_ * s_

		var ldt2: float = 6.0 * l_dt * l_dt * l_
		var mdt2: float = 6.0 * m_dt * m_dt * m_
		var sdt2: float = 6.0 * s_dt * s_dt * s_

		var r: float = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s - 1.0
		var r1: float = 4.0767416621 * ldt - 3.3077115913 * mdt + 0.2309699292 * sdt
		var r2: float = 4.0767416621 * ldt2 - 3.3077115913 * mdt2 + 0.2309699292 * sdt2

		var divisor_r: float = r1 * r1 - 0.5 * r * r2
		var u_r: float = r1 / divisor_r if abs(divisor_r) > 1e-6 else 0.0
		var t_r: float = -r * u_r

		var g: float = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s - 1.0
		var g1: float = -1.2684380046 * ldt + 2.6097574011 * mdt - 0.3413193965 * sdt
		var g2: float = -1.2684380046 * ldt2 + 2.6097574011 * mdt2 - 0.3413193965 * sdt2

		var divisor_g: float = g1 * g1 - 0.5 * g * g2
		var u_g: float = g1 / divisor_g if abs(divisor_g) > 1e-6 else 0.0
		var t_g: float = -g * u_g

		var b_v: float = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s - 1.0
		var b1: float = -0.0041960863 * ldt - 0.7034186147 * mdt + 1.7076147010 * sdt
		var b2: float = -0.0041960863 * ldt2 - 0.7034186147 * mdt2 + 1.7076147010 * sdt2

		var divisor_b: float = b1 * b1 - 0.5 * b_v * b2
		var u_b: float = b1 / divisor_b if abs(divisor_b) > 1e-6 else 0.0
		var t_b: float = - b_v * u_b

		t_r = t_r if u_r >= 0.0 else INF
		t_g = t_g if u_g >= 0.0 else INF
		t_b = t_b if u_b >= 0.0 else INF

		t += min(t_r, min(t_g, t_b))

	return t

static func get_ST_max(a_: float, b_: float, cusp: Vector2 = Vector2(-1.0, -1.0)) -> Vector2:
	if cusp.x == -1.0:
		cusp = find_cusp(a_, b_)
	var L: float = cusp.x
	var C: float = cusp.y
	return Vector2(C / L if abs(L) > 1e-6 else 0.0, C / (1.0 - L) if abs(1.0 - L) > 1e-6 else 0.0)

static func get_Cs(L: float, a_: float, b_: float) -> Vector3:
	var cusp: Vector2 = find_cusp(a_, b_)
	var C_max: float = find_gamut_intersection(a_, b_, L, 1.0, L, cusp)
	var ST_max: Vector2 = get_ST_max(a_, b_, cusp)

	var poly_S: float = (
		+7.44778970 + 4.15901240 * b_
		+ a_ * (-2.19557347 + 1.75198401 * b_
		+ a_ * (-2.13704948 - 10.02301043 * b_
		+ a_ * (-4.24894561 + 5.38770819 * b_ + 4.69891013 * a_)))
	)
	var S_mid: float = 0.11516993 + (1.0 / poly_S if abs(poly_S) > 1e-6 else 0.0)

	var poly_T: float = (
		+1.61320320 - 0.68124379 * b_
		+ a_ * (+0.40370612 + 0.90148123 * b_
		+ a_ * (-0.27087943 + 0.61223990 * b_
		+ a_ * (+0.00299215 - 0.45399568 * b_ - 0.14661872 * a_)))
	)
	var T_mid: float = 0.11239642 + (1.0 / poly_T if abs(poly_T) > 1e-6 else 0.0)

	var denom_k: float = min((L * ST_max.x), ((1.0 - L) * ST_max.y))
	var k: float = C_max / denom_k if abs(denom_k) > 1e-6 else 0.0

	var C_a: float = L * S_mid
	var C_b: float = (1.0 - L) * T_mid
	var C_mid: float = 0.0
	if abs(C_a) > 1e-6 and abs(C_b) > 1e-6:
		C_mid = 0.9 * k * sqrt(sqrt(1.0 / (1.0 / (C_a * C_a * C_a * C_a) + 1.0 / (C_b * C_b * C_b * C_b))))

	C_a = L * 0.4
	C_b = (1.0 - L) * 0.8
	var C_0: float = 0.0
	if abs(C_a) > 1e-6 and abs(C_b) > 1e-6:
		C_0 = sqrt(1.0 / (1.0 / (C_a * C_a) + 1.0 / (C_b * C_b)))

	return Vector3(C_0, C_mid, C_max)

static func okhsl_to_srgb(hsl: Vector3) -> Vector3:
	var h: float = hsl.x
	var s: float = hsl.y
	var l: float = hsl.z
	
	if l >= 0.999:
		return Vector3(1.0, 1.0, 1.0)
	elif l <= 0.001:
		return Vector3(0.0, 0.0, 0.0)

	var a_: float = cos(TAU * h)
	var b_: float = sin(TAU * h)
	var L: float = toe_inv(l)

	var Cs: Vector3 = get_Cs(L, a_, b_)
	var C_0: float = Cs.x
	var C_mid: float = Cs.y
	var C_max: float = Cs.z

	var C: float = 0.0
	var t: float = 0.0
	var k_0: float = 0.0
	var k_1: float = 0.0
	var k_2: float = 0.0
	
	if s < 0.8:
		t = 1.25 * s
		k_0 = 0.0
		k_1 = 0.8 * C_0
		k_2 = (1.0 - k_1 / C_mid) if abs(C_mid) > 1e-6 else 1.0
	else:
		t = 5.0 * (s - 0.8)
		k_0 = C_mid
		k_1 = 0.2 * C_mid * C_mid * 1.25 * 1.25 / C_0 if abs(C_0) > 1e-6 else 0.0
		k_2 = (1.0 - (k_1) / (C_max - C_mid)) if abs(C_max - C_mid) > 1e-6 else 1.0

	var denom_C: float = (1.0 - k_2 * t)
	C = k_0 + t * k_1 / denom_C if abs(denom_C) > 1e-6 else k_0
	var rgb: Vector3 = oklab_to_linear_srgb(Vector3(L, C * a_, C * b_))
	return Vector3(
		_linear_to_srgb_channel(rgb.x),
		_linear_to_srgb_channel(rgb.y),
		_linear_to_srgb_channel(rgb.z)
	)

static func srgb_to_okhsl(rgb: Vector3) -> Vector3:
	var linear_rgb: Vector3 = Vector3(
		_srgb_to_linear_channel(rgb.x),
		_srgb_to_linear_channel(rgb.y),
		_srgb_to_linear_channel(rgb.z)
	)
	var lab: Vector3 = linear_srgb_to_oklab(linear_rgb)
	var L: float = lab.x
	var a: float = lab.y
	var b: float = lab.z
	
	var C: float = sqrt(a * a + b * b)
	var a_: float = a / C if C > 0.0 else 0.0
	var b_: float = b / C if C > 0.0 else 0.0

	var h: float = 0.5 + 0.5 * atan2(-b, -a) / PI

	var Cs: Vector3 = get_Cs(L, a_, b_)
	var C_0: float = Cs.x
	var C_mid: float = Cs.y
	var C_max: float = Cs.z
	
	var s: float = 0.0
	if C < C_mid:
		var k_0: float = 0.0
		var k_1: float = 0.8 * C_0
		var k_2: float = (1.0 - k_1 / C_mid) if abs(C_mid) > 1e-6 else 1.0
		var denom_t: float = (k_1 + k_2 * (C - k_0))
		var t: float = (C - k_0) / denom_t if abs(denom_t) > 1e-6 else 0.0
		s = t * 0.8
	else:
		var k_0: float = C_mid
		var k_1: float = 0.2 * C_mid * C_mid * 1.25 * 1.25 / C_0 if abs(C_0) > 1e-6 else 0.0
		var k_2: float = (1.0 - (k_1) / (C_max - C_mid)) if abs(C_max - C_mid) > 1e-6 else 1.0
		var denom_t: float = (k_1 + k_2 * (C - k_0))
		var t: float = (C - k_0) / denom_t if abs(denom_t) > 1e-6 else 0.0
		s = 0.8 + 0.2 * t

	var l: float = toe(L)
	return Vector3(h, s, l)

static func okhsv_to_srgb(hsv: Vector3) -> Vector3:
	var h: float = hsv.x
	var s: float = hsv.y
	var v: float = hsv.z
	
	var a_: float = cos(TAU * h)
	var b_: float = sin(TAU * h)

	var ST_max: Vector2 = get_ST_max(a_, b_)
	var S_max: float = ST_max.x
	var S_0: float = 0.5
	var T: float = ST_max.y
	var k: float = 1.0 - S_0 / S_max if abs(S_max) > 1e-6 else 1.0
	
	var denom_Lv: float = (S_0 + T - T * k * s)
	var L_v: float = 1.0 - s * S_0 / denom_Lv if abs(denom_Lv) > 1e-6 else 1.0
	var C_v: float = s * T * S_0 / denom_Lv if abs(denom_Lv) > 1e-6 else 0.0

	var L: float = v * L_v
	var C: float = v * C_v

	var L_vt: float = toe_inv(L_v)
	var C_vt: float = C_v * L_vt / L_v if L_v > 0.0 else 0.0

	var L_new: float = toe_inv(L)
	C = C * L_new / L if L > 0.0 else 0.0
	L = L_new

	var rgb_scale: Vector3 = oklab_to_linear_srgb(Vector3(L_vt, a_ * C_vt, b_ * C_vt))
	var max_rgb: float = max(rgb_scale.x, max(rgb_scale.y, max(rgb_scale.z, 0.0)))
	var scale_L: float = _cbrt(1.0 / max_rgb) if abs(max_rgb) > 1e-6 else 0.0
	
	L = L * scale_L
	C = C * scale_L

	var rgb: Vector3 = oklab_to_linear_srgb(Vector3(L, C * a_, C * b_))
	return Vector3(
		_linear_to_srgb_channel(rgb.x),
		_linear_to_srgb_channel(rgb.y),
		_linear_to_srgb_channel(rgb.z)
	)

static func srgb_to_okhsv(rgb: Vector3) -> Vector3:
	var linear_rgb: Vector3 = Vector3(
		_srgb_to_linear_channel(rgb.x),
		_srgb_to_linear_channel(rgb.y),
		_srgb_to_linear_channel(rgb.z)
	)
	var lab: Vector3 = linear_srgb_to_oklab(linear_rgb)
	var L: float = lab.x
	var a: float = lab.y
	var b: float = lab.z
	
	var C: float = sqrt(a * a + b * b)
	var a_: float = a / C if C > 0.0 else 0.0
	var b_: float = b / C if C > 0.0 else 0.0

	var h: float = 0.5 + 0.5 * atan2(-b, -a) / PI

	var ST_max: Vector2 = get_ST_max(a_, b_)
	var S_max: float = ST_max.x
	var S_0: float = 0.5
	var T: float = ST_max.y
	var k: float = 1.0 - S_0 / S_max if abs(S_max) > 1e-6 else 1.0

	var denom_t: float = (C + L * T)
	var t: float = T / denom_t if abs(denom_t) > 1e-6 else 0.0
	var L_v: float = t * L
	var C_v: float = t * C

	var L_vt: float = toe_inv(L_v)
	var C_vt: float = C_v * L_vt / L_v if L_v > 0.0 else 0.0

	var rgb_scale: Vector3 = oklab_to_linear_srgb(Vector3(L_vt, a_ * C_vt, b_ * C_vt))
	var max_rgb: float = max(rgb_scale.x, max(rgb_scale.y, max(rgb_scale.z, 0.0)))
	var scale_L: float = _cbrt(1.0 / max_rgb) if abs(max_rgb) > 1e-6 else 0.0

	if scale_L > 0.0:
		L = L / scale_L
		C = C / scale_L

	C = C * toe(L) / L if L > 0.0 else 0.0
	L = toe(L)

	var v: float = L / L_v if L_v > 0.0 else 0.0
	var s: float = (S_0 + T) * C_v / ((T * S_0) + T * k * C_v) if ((T * S_0) + T * k * C_v) > 0.0 else 0.0

	return Vector3(h, s, v)
