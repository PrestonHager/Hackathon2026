## Pad ascent targets and blended insertion toward LEO periapsis.
class_name MissionLiftoffRoutines
extends RefCounted


static func liftoff_target_global(
	leo_path_global_origin: Vector2,
	rocket_global: Vector2,
	liftoff_use_radial: bool,
	liftoff_distance: float,
	liftoff_target_offset: Vector2
) -> Vector2:
	if liftoff_use_radial:
		var outward: Vector2 = rocket_global - leo_path_global_origin
		if outward.length() < 2.0:
			outward = Vector2(0.0, -1.0)
		return rocket_global + outward.normalized() * liftoff_distance
	return leo_path_global_origin + liftoff_target_offset


static func liftoff_radial_endpoint_from(
	leo_path_global_origin: Vector2,
	p0: Vector2,
	liftoff_distance: float
) -> Vector2:
	var outward: Vector2 = p0 - leo_path_global_origin
	if outward.length() < 2.0:
		outward = Vector2(0.0, -1.0)
	return p0 + outward.normalized() * liftoff_distance


static func liftoff_ascent_blend(
	rocket: Sprite2D,
	leo_path_global_origin: Vector2,
	p0: Vector2,
	insert_gp: Vector2,
	liftoff_radial_phase_ratio: float,
	liftoff_distance: float,
	u: float
) -> void:
	var split: float = clampf(liftoff_radial_phase_ratio, 0.12, 0.88)
	var p_radial: Vector2 = liftoff_radial_endpoint_from(leo_path_global_origin, p0, liftoff_distance)
	if u < split:
		var s: float = u / split
		s = s * s
		rocket.global_position = p0.lerp(p_radial, s)
	else:
		var s2: float = (u - split) / (1.0 - split)
		s2 = s2 * s2 * (3.0 - 2.0 * s2)
		rocket.global_position = p_radial.lerp(insert_gp, s2)
