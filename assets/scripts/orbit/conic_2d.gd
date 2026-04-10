## Two-body conic sections in 2D around a single focus at the origin. +Y is down (Godot 2D).
## True anomaly ν = 0 at periapsis. Periapsis points along -Y so injection at LEO matches (0, -r_pe).
## Use for Hohmann-style patches and circular parking orbits (KSP-style map plane).
## Reference via `preload("res://assets/scripts/orbit/conic_2d.gd")` from mission code.
extends RefCounted


static func ellipse_radius(a: float, e: float, nu: float) -> float:
	return a * (1.0 - e * e) / (1.0 + e * cos(nu))


## Cartesian position; periapsis direction is -Y (screen up).
static func position_peri_up(a: float, e: float, nu: float) -> Vector2:
	var r: float = ellipse_radius(a, e, nu)
	return Vector2(r * sin(nu), -r * cos(nu))


static func hohmann_semimajor_eccentricity(r_pe: float, r_ap: float) -> Vector2:
	var a: float = (r_pe + r_ap) * 0.5
	var e: float = absf(r_ap - r_pe) / maxf(r_pe + r_ap, 1e-6)
	return Vector2(a, e)


static func transfer_arc_points(r_pe: float, r_ap: float, nu_from: float, nu_to: float, segments: int) -> PackedVector2Array:
	var ae: Vector2 = hohmann_semimajor_eccentricity(r_pe, r_ap)
	var a: float = ae.x
	var e: float = ae.y
	var pts := PackedVector2Array()
	var n: int = maxi(segments, 2)
	for i in range(n + 1):
		var u := float(i) / float(n)
		var nu := lerpf(nu_from, nu_to, u)
		pts.append(position_peri_up(a, e, nu))
	return pts


## Half-ellipse from periapsis (LEO) to apoapsis (outer radius), for Path2D / trajectory.
static func transfer_half_ellipse_curve(r_pe: float, r_ap: float, steps: int) -> Curve2D:
	var pts: PackedVector2Array = transfer_arc_points(r_pe, r_ap, 0.0, PI, steps)
	var curve := Curve2D.new()
	for p in pts:
		curve.add_point(p)
	return curve


## Closed ellipse around focus (full prediction loop like KSP map).
static func closed_ellipse_outline(r_pe: float, r_ap: float, segments: int) -> PackedVector2Array:
	var ae: Vector2 = hohmann_semimajor_eccentricity(r_pe, r_ap)
	var a: float = ae.x
	var e: float = ae.y
	var pts := PackedVector2Array()
	var n: int = maxi(segments, 8)
	for i in range(n + 1):
		var nu := TAU * float(i) / float(n)
		pts.append(position_peri_up(a, e, nu))
	return pts


## Radial blend from inner LEO ring to full ellipse (UI “orbit line resolves” effect).
static func morph_radial_from_leo_ring(full_outline: PackedVector2Array, leo_r: float, g: float) -> PackedVector2Array:
	var gg: float = clampf(g, 0.0, 1.0)
	var n: int = full_outline.size()
	var out := PackedVector2Array()
	if n < 2:
		return out
	out.resize(n)
	for i in range(n):
		var f: Vector2 = full_outline[i]
		var rad: float = f.length()
		var dir: Vector2 = f / rad if rad > 0.5 else Vector2(1.0, 0.0)
		var inner: Vector2 = dir * leo_r
		out[i] = inner.lerp(f, gg)
	return out


## Circle with periapsis at (0, -radius): matches focus-centered parking orbit “top” injection.
static func circle_points_top_peri(radius: float, segments: int, phase: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = maxi(segments, 8)
	for i in range(n + 1):
		var t := phase + TAU * float(i) / float(n)
		pts.append(Vector2(sin(t), -cos(t)) * radius)
	return pts


static func circle_curve2d_top_peri(radius: float, segments: int) -> Curve2D:
	var pts: PackedVector2Array = circle_points_top_peri(radius, segments)
	var curve := Curve2D.new()
	for p in pts:
		curve.add_point(p)
	return curve


## Standard param (cos, sin) circle in parent frame — e.g. moon orbit around planet, lunar parking.
static func circle_points_standard(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = maxi(segments, 8)
	for i in range(n + 1):
		var t := TAU * float(i) / float(n)
		pts.append(Vector2(cos(t), sin(t)) * radius)
	return pts


static func circle_curve2d_standard(radius: float, segments: int) -> Curve2D:
	var pts: PackedVector2Array = circle_points_standard(radius, segments)
	var curve := Curve2D.new()
	for p in pts:
		curve.add_point(p)
	return curve


static func periapsis_position(r_pe: float, r_ap: float) -> Vector2:
	var ae: Vector2 = hohmann_semimajor_eccentricity(r_pe, r_ap)
	return position_peri_up(ae.x, ae.y, 0.0)


static func apoapsis_position(r_pe: float, r_ap: float) -> Vector2:
	var ae: Vector2 = hohmann_semimajor_eccentricity(r_pe, r_ap)
	return position_peri_up(ae.x, ae.y, PI)
