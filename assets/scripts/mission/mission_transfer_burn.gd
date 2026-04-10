## Transfer PathFollow2D motion: constant speed along the curve (linear progress vs mission time).
## Burn vs coast is visual only (sprite); `t_burn` + `t_coast` set total duration.
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
	var t_total: float = maxf(t_burn + t_coast, 1e-5)
	var u: float = clampf(elapsed / t_total, 0.0, 1.0)
	rocket_transfer.progress = lerpf(sp, clen, u)
	if rocket_transfer.progress >= d_burn_end - 0.5:
		rocket.texture = tex_coast
	else:
		rocket.texture = tex_burn
