## Transfer ellipse morphing toward lunar parking ring (root-local polyline for overlay).
class_name MissionLunarGeometry
extends RefCounted


static func orbit_morph_polyline_root_local(
	root: Node2D,
	transfer_path: Path2D,
	full_ellipse_transfer_local: PackedVector2Array,
	moon_global: Vector2,
	lunar_orbit_radius: float,
	w: float
) -> PackedVector2Array:
	var n: int = full_ellipse_transfer_local.size()
	var pts := PackedVector2Array()
	if n < 2:
		return pts
	pts.resize(n)
	for i in range(n):
		var pb: Vector2 = transfer_path.to_global(full_ellipse_transfer_local[i])
		var ang: float = TAU * float(i) / float(n - 1)
		var ps: Vector2 = moon_global + Vector2(cos(ang), sin(ang)) * lunar_orbit_radius
		var pg: Vector2 = pb.lerp(ps, w)
		pts[i] = root.to_local(pg)
	return pts
