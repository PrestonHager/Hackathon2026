## One-shot Path2D / Line2D setup from `Orbit` conics (LEO, moon, transfer, lunar parking).
## Orbit Line2D points match Path2D curves; transfer Path2D is the peri→apo slice of the same polyline as the dashed outline.
class_name MissionSceneBootstrap
extends RefCounted


static func _curve2d_from_polyline(pts: PackedVector2Array) -> Curve2D:
	var c := Curve2D.new()
	for p in pts:
		c.add_point(p)
	return c


static func apply_earth_centered_paths(
	leo_path: Path2D,
	moon_path: Path2D,
	orbit_visual: Line2D,
	moon_orbit_visual: Line2D,
	color_leo: Color,
	color_moon: Color
) -> void:
	var O := MissionConstants.Orbit
	var leo_pts: PackedVector2Array = O.circle_points_top_peri(MissionConstants.LEO_R, 48)
	var moon_pts: PackedVector2Array = O.circle_points_standard(MissionConstants.MOON_R, 64)
	leo_path.curve = _curve2d_from_polyline(leo_pts)
	moon_path.curve = _curve2d_from_polyline(moon_pts)
	orbit_visual.points = leo_pts
	orbit_visual.default_color = color_leo
	moon_orbit_visual.points = moon_pts
	moon_orbit_visual.default_color = color_moon


static func build_transfer_path(
	transfer_path: Path2D
) -> Dictionary:
	var O := MissionConstants.Orbit
	var n: int = MissionConstants.FULL_ELLIPSE_SEGMENTS
	var full: PackedVector2Array = O.closed_ellipse_outline(
		MissionConstants.LEO_R,
		MissionConstants.MOON_R,
		n
	)
	# Same ellipse as dashed preview; PathFollow uses open arc peri (ν=0) → apo (ν=π).
	var half_n: int = n >> 1
	var half_pts := PackedVector2Array()
	for i in range(half_n + 1):
		half_pts.append(full[i])
	transfer_path.curve = _curve2d_from_polyline(half_pts)
	var clen: float = maxf(transfer_path.curve.get_baked_length(), 1.0)
	return {"curve_length": clen, "full_ellipse_local": full}


static func build_lunar_parking_path(lunar_orbit_path: Path2D, lunar_orbit_radius: float) -> void:
	var pts: PackedVector2Array = MissionConstants.Orbit.circle_points_standard(
		lunar_orbit_radius,
		MissionConstants.LUNAR_PATH_SEGMENTS
	)
	lunar_orbit_path.curve = _curve2d_from_polyline(pts)


static func lunar_circle_polyline_local(lunar_orbit_radius: float) -> PackedVector2Array:
	return MissionConstants.Orbit.circle_points_standard(
		lunar_orbit_radius,
		MissionConstants.LUNAR_PATH_SEGMENTS
	)
