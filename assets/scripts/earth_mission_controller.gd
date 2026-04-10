extends Node2D

## Scripted mission orchestration: liftoff → LEO → transfer → lunar capture.
## Logic is split under `res://assets/scripts/mission/` (geometry, camera, burn, bootstrap).

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
@export var moon_orbit_speed: float = 0.036 ## Moon on Earth-centered path (map motion).
@export var liftoff_use_radial: bool = true
@export var liftoff_distance: float = 188.0
@export var liftoff_blend_to_leo_insertion: bool = true
@export var liftoff_radial_phase_ratio: float = 0.52
@export var liftoff_target_offset: Vector2 = Vector2(0.0, -130.0)
@export var pad_offset_from_earth: Vector2 = Vector2(-24.0, -157.0)
@export var leo_peri_max_wait: float = 22.0
@export var leo_circ_speed_boost_max: float = 2.35
@export var transfer_visual_grow_duration: float = 1.85
@export var transfer_path_drift_in_grow_fraction: float = 0.072
@export var transfer_coast_during_camera_fraction: float = 0.048

@export_group("Lunar capture")
@export var lunar_orbit_radius: float = 38.0
@export var lunar_capture_duration: float = 2.15
@export var lunar_capture_burn_fraction: float = 0.42
@export var lunar_orbit_speed: float = 0.16

@export_group("Camera (higher zoom = closer; lower = wider; use non-increasing values top→bottom)")
@export var zoom_intro: Vector2 = Vector2(0.72, 0.72)
@export var zoom_liftoff: Vector2 = Vector2(0.68, 0.68)
@export var zoom_leo: Vector2 = Vector2(0.60, 0.60)
@export var zoom_transfer_reveal: Vector2 = Vector2(0.50, 0.50)
@export var zoom_full_system: Vector2 = Vector2(0.42, 0.42)
@export var camera_zoom_duration: float = 1.05
@export var camera_wide_duration: float = 1.45
@export var camera_focus_offset: Vector2 = Vector2.ZERO

@export_group("KSP-style predicted paths")
@export var color_leo_prediction: Color = Color(0.45, 0.65, 0.95, 0.55)
@export var color_moon_prediction: Color = Color(0.68, 0.7, 0.9, 0.48)

@export_group("Earth")
@export var earth_animation: StringName = &"Earth"
@export var earth_anim_speed_scale: float = 1.0

@export_group("Debug")
@export var mission_debug_logging: bool = true

@onready var camera: Camera2D = $Camera2D
@onready var ksp_overlay: Node2D = $KspOrbitOverlay
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
var _xfer_progress_after_growth: float = 0.0
var _phase: Phase = Phase.INTRO
var _moon_motion_enabled: bool = false
var _leo_circ_elapsed: float = 0.0
var _capture_r0: Vector2 = Vector2.ZERO
var _capture_dir: Vector2 = Vector2.RIGHT
var _transfer_coast_cam_active: bool = false
var _transfer_coast_cam_t: float = 0.0
var _transfer_coast_p0: float = 0.0
var _transfer_coast_p1: float = 0.0
var _transfer_coast_cam_duration: float = 1.0
## Transfer tween segment logging: last_segment tracks burn/coast/early_coast transitions.
var _transfer_burn_debug_state: Dictionary = {"last_segment": -1}


func _phase_name() -> String:
	return Phase.keys()[_phase]


func _mdbg(step: String, detail: String = "") -> void:
	if not mission_debug_logging:
		return
	if detail.is_empty():
		print("[Mission] phase=", _phase_name(), " | ", step)
	else:
		print("[Mission] phase=", _phase_name(), " | ", step, " | ", detail)


func _ready() -> void:
	_transfer_burn_debug_state["last_segment"] = -1
	_align_world_to_earth()
	camera.zoom = zoom_intro
	camera.make_current()
	_start_earth_animation()

	orbit_visual.visible = false
	moon.visible = false
	moon_orbit_visual.visible = false
	transfer_visual.visible = false

	MissionSceneBootstrap.apply_earth_centered_paths(
		leo_path, moon_path, orbit_visual, moon_orbit_visual, color_leo_prediction, color_moon_prediction
	)
	var xfer: Dictionary = MissionSceneBootstrap.build_transfer_path(transfer_path)
	_transfer_curve_length = xfer["curve_length"]
	_full_ellipse_transfer_local = xfer["full_ellipse_local"]
	MissionSceneBootstrap.build_lunar_parking_path(lunar_orbit_path, lunar_orbit_radius)
	_transfer_visual_grow_step(0.0)

	_sync_ksp_transfer_apsides_markers()
	ksp_overlay.set_transfer_apsides_visible(false)

	var peri_off: float = leo_path.curve.get_closest_offset(Vector2(0.0, -MissionConstants.LEO_R))
	leo_follow.progress = peri_off
	_set_rocket_coast()
	_mdbg("READY", "curve_len=%s xfer_after_growth will be set later" % _transfer_curve_length)
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
	camera.global_position = c + camera_focus_offset
	pad_anchor.global_position = c + pad_offset_from_earth


func _sync_ksp_transfer_apsides_markers() -> void:
	var O := MissionConstants.Orbit
	var pe: Vector2 = O.periapsis_position(MissionConstants.LEO_R, MissionConstants.MOON_R)
	var ap: Vector2 = O.apoapsis_position(MissionConstants.LEO_R, MissionConstants.MOON_R)
	ksp_overlay.set_transfer_apsides_local(earth.position + pe, earth.position + ap)


func _transfer_visual_grow_step(g: float) -> void:
	var pts: PackedVector2Array = MissionTransferGeometry.transfer_visual_polyline(
		_full_ellipse_transfer_local, MissionConstants.LEO_R, g
	)
	if pts.size() >= 2:
		transfer_visual.set_polyline(pts)


func _transfer_morphed_point(off: float, g: float) -> Vector2:
	return MissionTransferGeometry.morphed_point(
		transfer_path.curve, _transfer_curve_length, MissionConstants.LEO_R, off, g
	)


func _transfer_morphed_heading(off: float, g: float) -> float:
	return MissionTransferGeometry.morphed_heading(
		transfer_path.curve, _transfer_curve_length, MissionConstants.LEO_R, off, g
	)


func _transfer_growth_with_rocket_step(u: float) -> void:
	var uu: float = clampf(u, 0.0, 1.0)
	var frac: float = clampf(transfer_path_drift_in_grow_fraction, 0.0, 0.35)
	var off: float = _transfer_curve_length * frac * uu
	_transfer_visual_grow_step(uu)
	if uu > 0.001:
		rocket.position = _transfer_morphed_point(off, uu)
	rocket.rotation = _transfer_morphed_heading(off, uu) + MissionConstants.ROCKET_HEADING


func _run_transfer_visual_growth_with_rocket() -> void:
	_mdbg("TRANSFER_GROWTH", "reparent rocket under TransferPath, tween dashed orbit")
	rocket.reparent(transfer_path, true)
	rocket.z_index = 6
	_set_rocket_burning()
	await get_tree().process_frame
	_transfer_growth_with_rocket_step(0.0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_transfer_growth_with_rocket_step, 0.0, 1.0, transfer_visual_grow_duration)
	await tw.finished
	_transfer_visual_grow_step(1.0)
	var frac: float = clampf(transfer_path_drift_in_grow_fraction, 0.0, 0.35)
	_xfer_progress_after_growth = _transfer_curve_length * frac
	rocket.position = _transfer_morphed_point(_xfer_progress_after_growth, 1.0)
	rocket.rotation = _transfer_morphed_heading(_xfer_progress_after_growth, 1.0) + MissionConstants.ROCKET_HEADING
	_mdbg("TRANSFER_GROWTH", "done xfer_prog=%s attaching PathFollow" % snappedf(_xfer_progress_after_growth, 0.1))
	await _attach_rocket_to_transfer(_xfer_progress_after_growth)


func _begin_transfer_camera_coast() -> void:
	_transfer_coast_p0 = rocket_transfer.progress
	var add: float = _transfer_curve_length * clampf(transfer_coast_during_camera_fraction, 0.0, 0.2)
	_transfer_coast_p1 = minf(_transfer_coast_p0 + add, _transfer_curve_length * 0.92)
	_transfer_coast_cam_duration = maxf(camera_zoom_duration * 0.85 + camera_wide_duration, 0.05)
	_transfer_coast_cam_t = 0.0
	_transfer_coast_cam_active = true
	_mdbg(
		"CAMERA_COAST",
		"p0=%s p1=%s dur=%s (moon still hidden)" % [
			snappedf(_transfer_coast_p0, 0.1),
			snappedf(_transfer_coast_p1, 0.1),
			snappedf(_transfer_coast_cam_duration, 0.01)
		]
	)


func _end_transfer_camera_coast() -> void:
	_transfer_coast_cam_active = false
	rocket_transfer.progress = lerpf(_transfer_coast_p0, _transfer_coast_p1, 1.0)
	_mdbg("CAMERA_COAST", "end progress=%s" % snappedf(rocket_transfer.progress, 0.1))


func _tween_camera_wait(zoom: Vector2, duration: float) -> void:
	var job: Variant = MissionCameraRoutines.tween_zoom_out_only(self, camera, zoom, duration)
	if job == null:
		return
	if job is SceneTreeTimer:
		await job.timeout
	else:
		await job.finished


func _set_rocket_burning() -> void:
	rocket.texture = MissionConstants.TEX_BURN


func _set_rocket_coast() -> void:
	rocket.texture = MissionConstants.TEX_ROCKET


func _attach_rocket_to_leo() -> void:
	_mdbg("ATTACH_LEO", "snap rocket to RocketLEO at peri")
	var peri_off: float = leo_path.curve.get_closest_offset(Vector2(0.0, -MissionConstants.LEO_R))
	leo_follow.progress = peri_off
	await get_tree().process_frame
	rocket.reparent(leo_follow, true)
	rocket.position = Vector2.ZERO
	rocket.rotation = MissionConstants.ROCKET_HEADING
	await get_tree().process_frame


func _wait_leo_min_then_periapsis() -> void:
	var peri_r: float = MissionPathMath.progress_ratio_at_local(leo_path, Vector2(0.0, -MissionConstants.LEO_R))
	var t0 := Time.get_ticks_usec() / 1_000_000.0
	while true:
		await get_tree().process_frame
		var elapsed := Time.get_ticks_usec() / 1_000_000.0 - t0
		var dr := fposmod(leo_follow.progress_ratio - peri_r + 1.0, 1.0)
		var near_peri: bool = minf(dr, 1.0 - dr) < MissionConstants.PERI_EPS
		if elapsed >= leo_orbit_duration and near_peri:
			break
		if elapsed > leo_peri_max_wait:
			break
	leo_follow.progress_ratio = peri_r
	await get_tree().process_frame


func _attach_rocket_to_transfer(progress_on_path: float = -1.0) -> void:
	var sp: float = progress_on_path if progress_on_path >= 0.0 else clampf(_xfer_progress_after_growth, 0.0, _transfer_curve_length)
	_mdbg("ATTACH_TRANSFER", "RocketTransfer.progress=%s clen=%s" % [snappedf(sp, 0.1), snappedf(_transfer_curve_length, 0.1)])
	sp = clampf(sp, 0.0, _transfer_curve_length)
	rocket_transfer.progress = sp
	await get_tree().process_frame
	rocket.reparent(rocket_transfer, true)
	rocket.position = Vector2.ZERO
	rocket.rotation = MissionConstants.ROCKET_HEADING
	await get_tree().process_frame


func _orbit_morph_step(w: float) -> void:
	var pts: PackedVector2Array = MissionLunarGeometry.orbit_morph_polyline_root_local(
		self, transfer_path, _full_ellipse_transfer_local, moon.global_position, lunar_orbit_radius, w
	)
	if pts.size() >= 2:
		transfer_visual.set_polyline(pts)


func _capture_lunar_step(w_lin: float) -> void:
	var lw: float = w_lin * w_lin
	var cap: Vector2 = moon.global_position + _capture_dir * lunar_orbit_radius
	rocket.global_position = _capture_r0.lerp(cap, lw)
	_orbit_morph_step(lw)
	var bf: float = clampf(lunar_capture_burn_fraction, 0.08, 0.95)
	if w_lin < bf - 1e-6:
		rocket.texture = MissionConstants.TEX_BURN
	else:
		rocket.texture = MissionConstants.TEX_ROCKET


func _begin_lunar_capture_sequence() -> void:
	_mdbg("LUNAR_CAPTURE", "start — reparent rocket to mission root for capture tween")
	ksp_overlay.set_transfer_apsides_visible(false)
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
	rocket.global_position = moon.global_position + _capture_dir * lunar_orbit_radius

	transfer_visual.reparent(lunar_orbit_path, false)
	transfer_visual.position = Vector2.ZERO
	transfer_visual.set_polyline(MissionSceneBootstrap.lunar_circle_polyline_local(lunar_orbit_radius))

	await get_tree().process_frame
	var loff: float = lunar_orbit_path.curve.get_closest_offset(lunar_orbit_path.to_local(rocket.global_position))
	rocket_lunar.progress = loff
	await get_tree().process_frame
	rocket.reparent(rocket_lunar, true)
	rocket.position = Vector2.ZERO
	rocket.rotation = MissionConstants.ROCKET_HEADING
	await get_tree().process_frame


func _process(delta: float) -> void:
	if _transfer_coast_cam_active:
		_transfer_coast_cam_t += delta
		var s: float = clampf(_transfer_coast_cam_t / _transfer_coast_cam_duration, 0.0, 1.0)
		rocket_transfer.progress = lerpf(_transfer_coast_p0, _transfer_coast_p1, s)
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


## Must match branch order in `MissionTransferBurn.run_elapsed_from`.
func _transfer_debug_segment_index(start_p: float, burn_end: float, clen: float, t_burn: float, elapsed: float) -> int:
	var d_burn_end: float = clampf(burn_end, 0.04, 0.45) * clen
	var sp: float = clampf(start_p, 0.0, clen)
	var t_b: float = maxf(t_burn, 1e-5)
	if sp >= d_burn_end - 0.25:
		return 2
	if elapsed < t_b:
		return 0
	return 1


func _transfer_debug_segment_name(segment: int) -> String:
	match segment:
		2:
			return "early_coast"
		1:
			return "coast"
		_:
			return "burn"


func _run_transfer_elapsed_from(start_p: float, burn_end: float, t_burn: float, t_coast: float, elapsed: float) -> void:
	MissionTransferBurn.run_elapsed_from(
		rocket_transfer,
		rocket,
		MissionConstants.TEX_BURN,
		MissionConstants.TEX_ROCKET,
		_transfer_curve_length,
		start_p,
		burn_end,
		t_burn,
		t_coast,
		elapsed
	)
	if mission_debug_logging:
		var seg: int = _transfer_debug_segment_index(
			start_p, burn_end, _transfer_curve_length, t_burn, elapsed
		)
		if seg != _transfer_burn_debug_state.get("last_segment", -999):
			_transfer_burn_debug_state["last_segment"] = seg
			var clen: float = _transfer_curve_length
			var dbe: float = clampf(burn_end, 0.04, 0.45) * clen
			var sp: float = clampf(start_p, 0.0, clen)
			_mdbg(
				"TRANSFER_BURN",
				"segment=%s elapsed=%s progress=%s / clen=%s start_p=%s d_burn_end=%s"
				% [
					_transfer_debug_segment_name(seg),
					snappedf(elapsed, 0.01),
					snappedf(rocket_transfer.progress, 0.1),
					snappedf(clen, 0.1),
					snappedf(sp, 0.1),
					snappedf(dbe, 0.1)
				]
			)


func _encounter_moon_progress_ratio() -> float:
	return MissionPathMath.progress_ratio_at_local(moon_path, Vector2(0.0, MissionConstants.MOON_R))


## Moon stays hidden until transfer ends; place it on the Earth orbit at the encounter angle (+Y / apo side).
func _prime_moon_at_transfer_arrival() -> void:
	var enc: float = _encounter_moon_progress_ratio()
	moon_follow.progress_ratio = enc
	_mdbg("MOON", "visible after transfer — progress_ratio=%s (encounter)" % snappedf(enc, 0.0001))


func _run_mission() -> void:
	_phase = Phase.INTRO
	_mdbg("INTRO", "camera + timer")
	await _tween_camera_wait(zoom_intro, 0.35)
	await get_tree().create_timer(intro_duration).timeout

	_phase = Phase.LIFTOFF
	_mdbg("LIFTOFF", "begin ascent")
	var peri_off_lift: float = leo_path.curve.get_closest_offset(Vector2(0.0, -MissionConstants.LEO_R))
	leo_follow.progress = peri_off_lift
	await get_tree().process_frame
	var insert_gp: Vector2 = leo_follow.global_position
	var p0_lift: Vector2 = rocket.global_position
	var leo_g: Vector2 = leo_path.global_position

	var z_lift := Vector2(minf(camera.zoom.x, zoom_liftoff.x), minf(camera.zoom.y, zoom_liftoff.y))
	var tw_zoom_lift := create_tween()
	tw_zoom_lift.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_zoom_lift.tween_property(camera, "zoom", z_lift, liftoff_duration * 0.35)
	_set_rocket_burning()
	var tw_lift := create_tween()
	if liftoff_blend_to_leo_insertion and liftoff_use_radial:
		tw_lift.tween_method(
			func(u: float) -> void:
				MissionLiftoffRoutines.liftoff_ascent_blend(
					rocket, leo_g, p0_lift, insert_gp, liftoff_radial_phase_ratio, liftoff_distance, u
				),
			0.0,
			1.0,
			liftoff_duration
		)
	elif liftoff_blend_to_leo_insertion:
		tw_lift.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw_lift.tween_property(rocket, "global_position", insert_gp, liftoff_duration)
	else:
		var ascent_target: Vector2 = MissionLiftoffRoutines.liftoff_target_global(
			leo_g, rocket.global_position, liftoff_use_radial, liftoff_distance, liftoff_target_offset
		)
		tw_lift.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_lift.tween_property(rocket, "global_position", ascent_target, liftoff_duration)
	await tw_lift.finished
	_set_rocket_coast()

	await _attach_rocket_to_leo()
	_mdbg("LIFTOFF", "attached LEO PathFollow")

	_phase = Phase.LEO_ORBIT
	_mdbg("LEO_ORBIT", "circularization + wait peri")
	_leo_circ_elapsed = 0.0
	await _tween_camera_wait(zoom_leo, camera_zoom_duration)
	orbit_visual.visible = true
	_set_rocket_burning()
	while _leo_circ_elapsed < leo_circularization_burn:
		await get_tree().process_frame
	_set_rocket_coast()

	await _wait_leo_min_then_periapsis()
	_mdbg("LEO_ORBIT", "periapsis reached — start transfer ellipse growth (moon still off)")

	transfer_visual.visible = true
	ksp_overlay.set_transfer_apsides_visible(true)
	await _run_transfer_visual_growth_with_rocket()

	# Complete Earth→transfer leg (camera coast + burn + coast) before showing the moon to avoid map / motion jumps.
	_phase = Phase.TRANSFER_BURN
	_mdbg("TRANSFER_BURN", "moon hidden; camera coast then burn tween along PathFollow2D")
	_begin_transfer_camera_coast()
	await _tween_camera_wait(zoom_transfer_reveal, camera_zoom_duration * 0.85)
	await _tween_camera_wait(zoom_full_system, camera_wide_duration)
	_end_transfer_camera_coast()

	var burn_end: float = clampf(transfer_burn_path_fraction, 0.04, 0.45)
	var t_total: float = transfer_burn_duration + transfer_coast_duration
	var p_burn_start: float = rocket_transfer.progress
	_mdbg(
		"TRANSFER_BURN",
		"tween START p_start=%s burn_end_frac=%s t_burn=%s t_coast=%s t_total=%s clen=%s"
		% [
			snappedf(p_burn_start, 0.1),
			burn_end,
			transfer_burn_duration,
			transfer_coast_duration,
			t_total,
			snappedf(_transfer_curve_length, 0.1)
		]
	)
	_transfer_burn_debug_state["last_segment"] = -1
	var tw_xfer := create_tween()
	# tween_method passes the interpolated float as the *first* argument; Callable.bind() appends after it,
	# so .bind(start_p, …) wrongly maps elapsed → start_p. Forward elapsed explicitly as the last parameter.
	tw_xfer.tween_method(
		func(transfer_elapsed: float) -> void:
			_run_transfer_elapsed_from(
				p_burn_start, burn_end, transfer_burn_duration, transfer_coast_duration, transfer_elapsed
			),
		0.0,
		t_total,
		t_total
	)
	await tw_xfer.finished
	rocket_transfer.progress = clampf(rocket_transfer.progress, 0.0, _transfer_curve_length)
	_set_rocket_coast()
	_mdbg(
		"TRANSFER_BURN",
		"tween DONE progress=%s / %s — revealing moon + orbit"
		% [snappedf(rocket_transfer.progress, 0.1), snappedf(_transfer_curve_length, 0.1)]
	)

	moon.visible = true
	moon_orbit_visual.visible = true
	_prime_moon_at_transfer_arrival()
	_moon_motion_enabled = true

	await _begin_lunar_capture_sequence()

	_phase = Phase.LUNAR_ORBIT
	_mdbg("LUNAR_ORBIT", "mission transfer sequence finished (rocket on lunar PathFollow)")
