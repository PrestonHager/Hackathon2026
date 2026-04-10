## Transfer PathFollow2D burn + coast progress (arc length) and rocket texture.
class_name MissionTransferBurn
extends RefCounted


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
	if sp >= d_burn_end - 0.25:
		var t_all: float = maxf(t_burn + t_coast, 1e-6)
		var s_all: float = clampf(elapsed / t_all, 0.0, 1.0)
		rocket_transfer.progress = lerpf(sp, clen, s_all)
		rocket.texture = tex_coast
		return
	if elapsed <= t_burn:
		var s: float = clampf(elapsed / maxf(t_burn, 1e-6), 0.0, 1.0)
		s = s * s
		var dist: float = lerpf(sp, d_burn_end, s)
		rocket_transfer.progress = dist
		rocket.texture = tex_burn
	else:
		var s2: float = clampf((elapsed - t_burn) / maxf(t_coast, 1e-6), 0.0, 1.0)
		var dist2: float = lerpf(d_burn_end, clen, s2)
		rocket_transfer.progress = dist2
		rocket.texture = tex_coast
