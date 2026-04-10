## One-shot Path2D / Line2D setup from `Orbit` conics (LEO, moon, transfer, lunar parking).
class_name MissionSceneBootstrap
extends RefCounted


static func apply_earth_centered_paths(
	leo_path: Path2D,
	moon_path: Path2D,
	orbit_visual: Line2D,
	moon_orbit_visual: Line2D,
	color_leo: Color,
	color_moon: Color
) -> void:
	var O := MissionConstants.Orbit
	leo_path.curve = O.circle_curve2d_top_peri(MissionConstants.LEO_R, MissionConstants.LEO_PATH_BAKE_SEGMENTS)
	moon_path.curve = O.circle_curve2d_standard(MissionConstants.MOON_R, MissionConstants.MOON_PATH_BAKE_SEGMENTS)
	orbit_visual.points = O.circle_points_top_peri(MissionConstants.LEO_R, 48)
	orbit_visual.default_color = color_leo
	moon_orbit_visual.points = O.circle_points_standard(MissionConstants.MOON_R, 64)
	moon_orbit_visual.default_color = color_moon


static func build_transfer_path(
	transfer_path: Path2D
) -> Dictionary:
	var O := MissionConstants.Orbit
	transfer_path.curve = O.transfer_half_ellipse_curve(
		MissionConstants.LEO_R,
		MissionConstants.MOON_R,
		MissionConstants.TRANSFER_CURVE_STEPS
	)
	var clen: float = maxf(transfer_path.curve.get_baked_length(), 1.0)
	var full: PackedVector2Array = O.closed_ellipse_outline(
		MissionConstants.LEO_R,
		MissionConstants.MOON_R,
		MissionConstants.FULL_ELLIPSE_SEGMENTS
	)
	return {"curve_length": clen, "full_ellipse_local": full}


static func build_lunar_parking_path(lunar_orbit_path: Path2D, lunar_orbit_radius: float) -> void:
	lunar_orbit_path.curve = MissionConstants.Orbit.circle_curve2d_standard(
		lunar_orbit_radius,
		MissionConstants.LUNAR_PATH_SEGMENTS
	)


static func lunar_circle_polyline_local(lunar_orbit_radius: float) -> PackedVector2Array:
	return MissionConstants.Orbit.circle_points_standard(
		lunar_orbit_radius,
		MissionConstants.FULL_ELLIPSE_SEGMENTS
	)
