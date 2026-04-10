## Morphed transfer path sampling (matches dashed prediction growth) and polyline updates.
class_name MissionTransferGeometry
extends RefCounted

const _Orbit := preload("res://assets/scripts/orbit/conic_2d.gd")


static func morphed_point(curve: Curve2D, curve_length: float, leo_r: float, off: float, g: float) -> Vector2:
	var p_full: Vector2 = curve.sample_baked(clampf(off, 0.0, curve_length))
	var rad: float = p_full.length()
	var dir: Vector2 = p_full / rad if rad > 0.5 else Vector2(1.0, 0.0)
	var inner: Vector2 = dir * leo_r
	return inner.lerp(p_full, clampf(g, 0.0, 1.0))


static func morphed_heading(curve: Curve2D, curve_length: float, leo_r: float, off: float, g: float) -> float:
	var eps: float = clampf(curve_length * 0.004, 2.0, 14.0)
	var o0: float = clampf(off - eps, 0.0, curve_length)
	var o1: float = clampf(off + eps, 0.0, curve_length)
	var p0: Vector2 = morphed_point(curve, curve_length, leo_r, o0, g)
	var p1: Vector2 = morphed_point(curve, curve_length, leo_r, o1, g)
	return (p1 - p0).angle()


static func transfer_visual_polyline(
	full_ellipse_local: PackedVector2Array,
	leo_r: float,
	g: float
) -> PackedVector2Array:
	if full_ellipse_local.size() < 2:
		return PackedVector2Array()
	return _Orbit.morph_radial_from_leo_ring(full_ellipse_local, leo_r, g)
