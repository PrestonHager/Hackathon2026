## Pad ascent targets and blended insertion toward LEO periapsis.
class_name MissionLiftoffRoutines
extends RefCounted


func _quad_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var omt: float = 1.0 - t
	return omt * omt * a + 2.0 * omt * t * b + t * t * c


## Climb with constant screen-X (vertical), then ease into LEO peri with a bow to +X (orbit direction at peri).
## `min_vertical_climb` avoids a degenerate bezier when the pad is almost at peri altitude (tiny vertical leg).
func liftoff_vertical_then_leo_insert(
	rocket: Sprite2D,
	p0: Vector2,
	insert_gp: Vector2,
	vertical_phase_ratio: float,
	turn_outset: float,
	min_vertical_climb: float,
	u: float
) -> void:
	var split: float = clampf(vertical_phase_ratio, 0.18, 0.72)
	var climb: float = maxf(min_vertical_climb, 4.0)
	# +Y is down: climb = decrease Y. End vertical leg clearly above peri when possible.
	var y_top: float = minf(p0.y - climb, insert_gp.y - 4.0)
	if y_top >= p0.y - 0.5:
		y_top = p0.y - climb
	var p_vertex := Vector2(p0.x, y_top)
	if u < split:
		var tt: float = u / split
		tt = tt * tt * (3.0 - 2.0 * tt)
		rocket.global_position = p0.lerp(p_vertex, tt)
	else:
		var tt: float = (u - split) / maxf(1.0 - split, 1e-5)
		tt = tt * tt * (3.0 - 2.0 * tt)
		if p_vertex.distance_squared_to(insert_gp) < 9.0:
			rocket.global_position = p_vertex.lerp(insert_gp, tt)
			return
		var cx: float = maxf(p_vertex.x, insert_gp.x) + maxf(turn_outset, 0.0)
		var cy: float = lerpf(p_vertex.y, insert_gp.y, 0.28)
		var ctrl := Vector2(cx, cy)
		rocket.global_position = _quad_bezier(p_vertex, ctrl, insert_gp, tt)


func liftoff_target_global(
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


func liftoff_radial_endpoint_from(
	leo_path_global_origin: Vector2,
	p0: Vector2,
	liftoff_distance: float
) -> Vector2:
	var outward: Vector2 = p0 - leo_path_global_origin
	if outward.length() < 2.0:
		outward = Vector2(0.0, -1.0)
	return p0 + outward.normalized() * liftoff_distance


## Legacy radial-out then blend to insert (can push the rocket out of a fixed camera frame).
func liftoff_ascent_blend(
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
