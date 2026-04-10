extends Node2D

## Pad → LEO → Hohmann transfer → lunar capture. Transfer motion uses PathFollow2D arc length (progress).
## Dashed transfer ellipse grows from a LEO-sized ring to the full ellipse. Liftoff is radial away from Earth.

enum Phase {
	INTRO,
	LIFTOFF,
	LEO_ORBIT,
	TRANSFER_BURN,
	LUNAR_CAPTURE,
	LUNAR_ORBIT,
}

@export var intro_duration: float = 1.2
@export var liftoff_duration: float = 2.5
@export var leo_orbit_duration: float = 5.5
@export var leo_circularization_burn: float = 0.55
@export var transfer_burn_duration: float = 1.15
@export var transfer_coast_duration: float = 3.2
@export var transfer_burn_path_fraction: float = 0.14
@export var leo_orbit_speed: float = 0.105
@export var moon_orbit_speed: float = 0.036
## If true, liftoff moves along the surface normal (away from Earth); avoids screen-down motion when the pad is high on the disc.
@export var liftoff_use_radial: bool = true
@export var liftoff_distance: float = 188.0
## Fallback when liftoff_use_radial is false: offset from Earth (orbit center), +Y is down in Godot.
@export var liftoff_target_offset: Vector2 = Vector2(0.0, -130.0)
@export var pad_offset_from_earth: Vector2 = Vector2(-24.0, -157.0)
@export var leo_peri_max_wait: float = 22.0
@export var leo_circ_speed_boost_max: float = 2.35
@export var transfer_visual_grow_duration: float = 1.85

@export_group("Lunar capture")
@export var lunar_orbit_radius: float = 38.0
@export var lunar_capture_duration: float = 2.15
@export var lunar_capture_burn_fraction: float = 0.42
@export var lunar_orbit_speed: float = 0.16

@export_group("Camera (zoom > 1 = closer, < 1 = wider view)")
@export var zoom_intro: Vector2 = Vector2(1.0, 1.0)
@export var zoom_liftoff: Vector2 = Vector2(0.9, 0.9)
@export var zoom_leo: Vector2 = Vector2(0.85, 0.85)
@export var zoom_transfer_reveal: Vector2 = Vector2(0.88, 0.88)
@export var zoom_full_system: Vector2 = Vector2(0.52, 0.52)
@export var camera_zoom_duration: float = 1.05
@export var camera_wide_duration: float = 1.45

@export_group("Earth")
@export var earth_animation: StringName = &"Earth"
@export var earth_anim_speed_scale: float = 1.0

const TEX_ROCKET := preload("res://assets/sprites/rocket.png")
const TEX_BURN := preload("res://assets/sprites/rocket-burn.png")

const LEO_R := 130.0
const MOON_R := 235.0
const ROCKET_HEADING := 1.5708
const TRANSFER_CURVE_STEPS := 128
const FULL_ELLIPSE_SEGMENTS := 240
const LUNAR_PATH_SEGMENTS := 48
const PERI_EPS := 0.018

@onready var camera: Camera2D = $Camera2D
@onready var earth: AnimatedSprite2D = $Earth
@onready var pad_anchor: Node2D = $PadAnchor
@onready var rocket: Sprite2D = $PadAnchor/Rocket
@onready var leo_path: Path2D = $LEO_OrbitPath
@onready var leo_follow: PathFollow2D = $LEO_OrbitPath/RocketLEO
@onready var orbit_visual: Line2D = $LEO_OrbitPath/OrbitVisual
@onready var moon_path: Path2D = $MoonOrbitPath
@onready var moon_follow: PathFollow2D = $MoonOrbitPath/MoonFollow
@onready var moon: Sprite2D = $MoonOrbitPath/MoonFollow/Moon
@onready var lunar_orbit_path: Path2D = $MoonOrbitPath/MoonFollow/LunarOrbitPath
@onready var rocket_lunar: PathFollow2D = $MoonOrbitPath/MoonFollow/LunarOrbitPath/RocketLunar
@onready var moon_orbit_visual: Line2D = $MoonOrbitPath/MoonOrbitVisual
@onready var transfer_path: Path2D = $TransferPath
@onready var transfer_visual: DashedPolyline2D = $TransferPath/TransferOrbitVisual
@onready var rocket_transfer: PathFollow2D = $TransferPath/RocketTransfer

var _full_ellipse_transfer_local: PackedVector2Array = PackedVector2Array()
var _transfer_curve_length: float = 1.0
var _phase: Phase = Phase.INTRO
var _moon_motion_enabled: bool = false
var _leo_circ_elapsed: float = 0.0
var _capture_r0: Vector2 = Vector2.ZERO
var _capture_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	_align_world_to_earth()
	camera.zoom = zoom_intro * 1.14
	camera.make_current()

	_start_earth_animation()

	orbit_visual.visible = false
	moon.visible = false
	moon_orbit_visual.visible = false
	transfer_visual.visible = false
	_build_transfer_path()
	_build_lunar_orbit_path()
	_transfer_visual_grow_step(0.0)

	var peri_off: float = leo_path.curve.get_closest_offset(Vector2(0.0, -LEO_R))
	leo_follow.progress = peri_off
	_set_rocket_coast()
	_run_mission()


func _start_earth_animation() -> void:
	if earth.sprite_frames == null:
		return
	earth.speed_scale = earth_anim_speed_scale
	if earth.sprite_frames.has_animation(earth_animation):
		earth.play(earth_animation)
	else:
		var names := earth.sprite_frames.get_animation_names()
		if names.size() > 0:
			earth.play(names[0])


func _align_world_to_earth() -> void:
	var c: Vector2 = earth.global_position
	leo_path.global_position = c
	moon_path.global_position = c
	transfer_path.global_position = c
	camera.global_position = c
	pad_anchor.global_position = c + pad_offset_from_earth


func _transfer_ellipse_ab() -> Vector3:
	var a: float = (LEO_R + MOON_R) * 0.5
	var c: float = (MOON_R - LEO_R) * 0.5
	var b: float = sqrt(maxf(0.0, a * a - c * c))
	return Vector3(a, b, c)


func _build_transfer_path() -> void:
	var abc := _transfer_ellipse_ab()
	var a: float = abc.x
	var b: float = abc.y
	var cy: float = abc.z
	var curve := Curve2D.new()
	for i in range(TRANSFER_CURVE_STEPS + 1):
		var u := float(i) / float(TRANSFER_CURVE_STEPS)
		var t := lerpf(-PI * 0.5, PI * 0.5, u)
		curve.add_point(Vector2(b * cos(t), cy + a * sin(t)))
	transfer_path.curve = curve
	_transfer_curve_length = maxf(transfer_path.curve.get_baked_length(), 1.0)

	_full_ellipse_transfer_local.clear()
	for i in range(FULL_ELLIPSE_SEGMENTS + 1):
		var t := TAU * float(i) / float(FULL_ELLIPSE_SEGMENTS)
		_full_ellipse_transfer_local.append(Vector2(b * cos(t), cy + a * sin(t)))


func _transfer_visual_grow_step(g: float) -> void:
	var n: int = _full_ellipse_transfer_local.size()
	if n < 2:
		return
	var gg: float = clampf(g, 0.0, 1.0)
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in range(n):
		var f: Vector2 = _full_ellipse_transfer_local[i]
		var rad: float = f.length()
		var dir: Vector2 = f / rad if rad > 0.5 else Vector2(1.0, 0.0)
		var inner: Vector2 = dir * LEO_R
		pts[i] = inner.lerp(f, gg)
	transfer_visual.set_polyline(pts)


func _play_transfer_visual_growth() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_transfer_visual_grow_step, 0.0, 1.0, transfer_visual_grow_duration)
	await tw.finished
	_transfer_visual_grow_step(1.0)


func _build_lunar_orbit_path() -> void:
	var curve := Curve2D.new()
	var r := lunar_orbit_radius
	for i in range(LUNAR_PATH_SEGMENTS + 1):
		var t := TAU * float(i) / float(LUNAR_PATH_SEGMENTS)
		curve.add_point(Vector2(cos(t) * r, sin(t) * r))
	lunar_orbit_path.curve = curve


func _lunar_circle_polyline_local() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(FULL_ELLIPSE_SEGMENTS + 1):
		var t := TAU * float(i) / float(FULL_ELLIPSE_SEGMENTS)
		pts.append(Vector2(cos(t), sin(t)) * lunar_orbit_radius)
	return pts


func _encounter_moon_progress_ratio() -> float:
	return _progress_ratio_at_local(moon_path, Vector2(0.0, MOON_R))


func _prime_moon_phase_for_encounter() -> void:
	var t_remain: float = camera_zoom_duration * 0.85 + camera_wide_duration + 0.08
	t_remain += transfer_burn_duration + transfer_coast_duration
	var enc: float = _encounter_moon_progress_ratio()
	moon_follow.progress_ratio = fposmod(enc - moon_orbit_speed * t_remain, 1.0)


func _tween_camera_wait(zoom: Vector2, duration: float) -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "zoom", zoom, duration)
	await tw.finished


func _set_rocket_burning() -> void:
	rocket.texture = TEX_BURN


func _set_rocket_coast() -> void:
	rocket.texture = TEX_ROCKET


func _liftoff_target_global() -> Vector2:
	var earth_c: Vector2 = leo_path.global_position
	var r0: Vector2 = rocket.global_position
	if liftoff_use_radial:
		var outward: Vector2 = r0 - earth_c
		if outward.length() < 2.0:
			outward = Vector2(0.0, -1.0)
		return r0 + outward.normalized() * liftoff_distance
	return earth_c + liftoff_target_offset


func _attach_rocket_to_leo() -> void:
	var peri_off: float = leo_path.curve.get_closest_offset(Vector2(0.0, -LEO_R))
	leo_follow.progress = peri_off
	rocket.reparent(leo_follow, false)
	rocket.position = Vector2.ZERO
	rocket.rotation = ROCKET_HEADING
	await get_tree().process_frame


func _wait_leo_min_then_periapsis() -> void:
	var peri_r: float = _progress_ratio_at_local(leo_path, Vector2(0.0, -LEO_R))
	var t0 := Time.get_ticks_usec() / 1_000_000.0
	while true:
		await get_tree().process_frame
		var elapsed := Time.get_ticks_usec() / 1_000_000.0 - t0
		var dr := fposmod(leo_follow.progress_ratio - peri_r + 1.0, 1.0)
		var near_peri: bool = minf(dr, 1.0 - dr) < PERI_EPS
		if elapsed >= leo_orbit_duration and near_peri:
			break
		if elapsed > leo_peri_max_wait:
			break
	leo_follow.progress_ratio = peri_r
	await get_tree().process_frame


func _progress_ratio_at_local(path: Path2D, local_point: Vector2) -> float:
	var path_len: float = path.curve.get_baked_length()
	if path_len <= 0.0:
		return 0.0
	var off: float = path.curve.get_closest_offset(local_point)
	return clampf(off / path_len, 0.0, 1.0)


func _attach_rocket_to_transfer() -> void:
	rocket_transfer.progress = 0.0
	rocket_transfer.progress_ratio = 0.0
	rocket.reparent(rocket_transfer, false)
	rocket.position = Vector2.ZERO
	rocket.rotation = ROCKET_HEADING
	await get_tree().process_frame


func _orbit_morph_step(w: float) -> void:
	var n: int = _full_ellipse_transfer_local.size()
	if n < 2:
		return
	var moon_g: Vector2 = moon.global_position
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in range(n):
		var pb: Vector2 = transfer_path.to_global(_full_ellipse_transfer_local[i])
		var ang: float = TAU * float(i) / float(n - 1)
		var ps: Vector2 = moon_g + Vector2(cos(ang), sin(ang)) * lunar_orbit_radius
		var pg: Vector2 = pb.lerp(ps, w)
		pts[i] = to_local(pg)
	transfer_visual.set_polyline(pts)


func _capture_lunar_step(w_lin: float) -> void:
	var lw: float = w_lin * w_lin
	var cap: Vector2 = moon.global_position + _capture_dir * lunar_orbit_radius
	rocket.global_position = _capture_r0.lerp(cap, lw)
	_orbit_morph_step(lw)
	var bf: float = clampf(lunar_capture_burn_fraction, 0.08, 0.95)
	if w_lin < bf - 1e-6:
		rocket.texture = TEX_BURN
	else:
		rocket.texture = TEX_ROCKET


func _begin_lunar_capture_sequence() -> void:
	rocket.reparent(self, true)
	transfer_visual.reparent(self, false)
	transfer_visual.z_index = 4
	_capture_r0 = rocket.global_position
	var moon_c: Vector2 = moon.global_position
	var outward: Vector2 = _capture_r0 - moon_c
	if outward.length() < 2.0:
		_capture_dir = Vector2(1.0, 0.0)
	else:
		_capture_dir = outward.normalized()
	_orbit_morph_step(0.0)
	await get_tree().process_frame

	_phase = Phase.LUNAR_CAPTURE
	var tw_cap := create_tween()
	tw_cap.set_trans(Tween.TRANS_LINEAR)
	tw_cap.tween_method(_capture_lunar_step, 0.0, 1.0, lunar_capture_duration)
	await tw_cap.finished
	_set_rocket_coast()
	var cap_end: Vector2 = moon.global_position + _capture_dir * lunar_orbit_radius
	rocket.global_position = cap_end

	transfer_visual.reparent(lunar_orbit_path, false)
	transfer_visual.position = Vector2.ZERO
	transfer_visual.set_polyline(_lunar_circle_polyline_local())

	await get_tree().process_frame
	var loff: float = lunar_orbit_path.curve.get_closest_offset(lunar_orbit_path.to_local(rocket.global_position))
	rocket_lunar.progress = loff
	rocket.reparent(rocket_lunar, false)
	rocket.position = Vector2.ZERO
	rocket.rotation = ROCKET_HEADING
	await get_tree().process_frame


func _process(delta: float) -> void:
	if _moon_motion_enabled:
		moon_follow.progress_ratio += moon_orbit_speed * delta
	match _phase:
		Phase.LEO_ORBIT:
			var mult: float = 1.0
			if _leo_circ_elapsed < leo_circularization_burn:
				_leo_circ_elapsed += delta
				var prog: float = clampf(_leo_circ_elapsed / maxf(leo_circularization_burn, 0.0001), 0.0, 1.0)
				mult = lerpf(1.0, leo_circ_speed_boost_max, prog * prog)
			leo_follow.progress_ratio += leo_orbit_speed * mult * delta
		Phase.LUNAR_ORBIT:
			rocket_lunar.progress_ratio += lunar_orbit_speed * delta


func _run_transfer_elapsed(burn_end: float, t_burn: float, t_coast: float, elapsed: float) -> void:
	var clen: float = _transfer_curve_length
	var d_burn_end: float = clampf(burn_end, 0.04, 0.45) * clen
	if elapsed <= t_burn:
		var s: float = clampf(elapsed / maxf(t_burn, 1e-6), 0.0, 1.0)
		s = s * s
		var dist: float = d_burn_end * s
		rocket_transfer.progress = dist
		rocket.texture = TEX_BURN
	else:
		var s2: float = clampf((elapsed - t_burn) / maxf(t_coast, 1e-6), 0.0, 1.0)
		var dist2: float = lerpf(d_burn_end, clen, s2)
		rocket_transfer.progress = dist2
		rocket.texture = TEX_ROCKET


func _run_mission() -> void:
	_phase = Phase.INTRO
	await _tween_camera_wait(zoom_intro, 0.35)
	await get_tree().create_timer(intro_duration).timeout

	_phase = Phase.LIFTOFF
	var tw_zoom_lift := create_tween()
	tw_zoom_lift.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw_zoom_lift.tween_property(camera, "zoom", zoom_liftoff, liftoff_duration * 0.35)
	_set_rocket_burning()
	var ascent_target: Vector2 = _liftoff_target_global()
	var tw_lift := create_tween()
	tw_lift.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw_lift.tween_property(rocket, "global_position", ascent_target, liftoff_duration)
	await tw_lift.finished
	_set_rocket_coast()

	await _attach_rocket_to_leo()

	_phase = Phase.LEO_ORBIT
	_leo_circ_elapsed = 0.0
	await _tween_camera_wait(zoom_leo, camera_zoom_duration)
	orbit_visual.visible = true
	_set_rocket_burning()
	while _leo_circ_elapsed < leo_circularization_burn:
		await get_tree().process_frame
	_set_rocket_coast()

	await _wait_leo_min_then_periapsis()

	transfer_visual.visible = true
	await _play_transfer_visual_growth()

	moon.visible = true
	moon_orbit_visual.visible = true
	_prime_moon_phase_for_encounter()
	_moon_motion_enabled = true

	await _tween_camera_wait(zoom_transfer_reveal, camera_zoom_duration * 0.85)
	await _tween_camera_wait(zoom_full_system, camera_wide_duration)

	_phase = Phase.TRANSFER_BURN
	await _attach_rocket_to_transfer()

	var burn_end: float = clampf(transfer_burn_path_fraction, 0.04, 0.45)
	var t_total: float = transfer_burn_duration + transfer_coast_duration
	var tw_xfer := create_tween()
	tw_xfer.tween_method(_run_transfer_elapsed.bind(burn_end, transfer_burn_duration, transfer_coast_duration), 0.0, t_total, t_total)
	await tw_xfer.finished
	rocket_transfer.progress = _transfer_curve_length
	rocket_transfer.progress_ratio = 1.0
	_set_rocket_coast()

	await _begin_lunar_capture_sequence()

	_phase = Phase.LUNAR_ORBIT
