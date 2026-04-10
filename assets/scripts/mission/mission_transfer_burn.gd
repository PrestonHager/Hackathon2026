## Transfer PathFollow2D motion: accelerate through burn, then decelerate toward apoapsis (moon).
class_name MissionTransferBurn
extends RefCounted


static func _ease_in_cubic(t: float) -> float:
	return t * t * t


static func _ease_out_cubic(t: float) -> float:
	var u: float = 1.0 - t
	return 1.0 - u * u * u


static func run_elapsed_from(
	rocket_transfer: PathFollow2D,
	rocket: Sprite2D,
	tex_burn: Texture2D,
	tex_coast: Texture2D,
	curve_length: float,
	start_p: float,
	burn_end: float,
	t_burn: float,
	t_coast: float,
	elapsed: float
) -> void:
	var clen: float = curve_length
	var d_burn_end: float = clampf(burn_end, 0.04, 0.45) * clen
	var sp: float = clampf(start_p, 0.0, clen)
	var t_b: float = maxf(t_burn, 1e-5)
	var t_c: float = maxf(t_coast, 1e-5)

	if sp >= d_burn_end - 0.25:
		var t_all: float = t_b + t_c
		var u: float = clampf(elapsed / t_all, 0.0, 1.0)
		var s: float = _ease_out_cubic(u)
		rocket_transfer.progress = lerpf(sp, clen, s)
		rocket.texture = tex_coast
	elif elapsed < t_b:
		var tb: float = clampf(elapsed / t_b, 0.0, 1.0)
		var s_burn: float = _ease_in_cubic(tb)
		rocket_transfer.progress = lerpf(sp, d_burn_end, s_burn)
		rocket.texture = tex_burn
	else:
		var tc: float = clampf((elapsed - t_b) / t_c, 0.0, 1.0)
		var s_coast: float = _ease_out_cubic(tc)
		rocket_transfer.progress = lerpf(d_burn_end, clen, s_coast)
		rocket.texture = tex_coast
