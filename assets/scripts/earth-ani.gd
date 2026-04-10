extends Node2D

## Pad → LEO → Hohmann transfer → moon orbit.
## Orbit Path2D nodes are centered on Earth each run. Transfer motion uses a high-res half-ellipse;
## the orange dashed overlay is the full ellipse (peri on LEO, apo on lunar altitude).

enum Phase {
	INTRO,
	LIFTOFF,
	LEO_ORBIT,
	TRANSFER_BURN,
	MOON_ORBIT,
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
@export var liftoff_target_offset: Vector2 = Vector2(0.0, -130.0)
## Pad position relative to Earth sprite center (match your layout if Earth moves).
@export var pad_offset_from_earth: Vector2 = Vector2(-24.0, -157.0)
@export var leo_peri_sync_duration: float = 0.85

@export_group("Camera (zoom > 1 = closer, < 1 = wider view)")
@export var zoom_intro: Vector2 = Vector2(1.0, 1.0)
@export var zoom_liftoff: Vector2 = Vector2(0.9, 0.9)
@export var zoom_leo: Vector2 = Vector2(0.85, 0.85)
@export var zoom_transfer_reveal: Vector2 = Vector2(0.88, 0.88)
@export var zoom_full_system: Vector2 = Vector2(0.52, 0.52)
@export var camera_zoom_duration: float = 1.05
@export var camera_wide_duration: float = 1.45

const TEX_ROCKET := preload("res://assets/sprites/rocket.png")
const TEX_BURN := preload("res://assets/sprites/rocket-burn.png")

const LEO_R := 130.0
const MOON_R := 235.0
const ROCKET_HEADING := 1.5708
const TRANSFER_CURVE_STEPS := 128
const FULL_ELLIPSE_SEGMENTS := 240

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
@onready var rocket_moon: PathFollow2D = $MoonOrbitPath/RocketMoon
@onready var moon_orbit_visual: Line2D = $MoonOrbitPath/MoonOrbitVisual
@onready var transfer_path: Path2D = $TransferPath
@onready var transfer_visual: DashedPolyline2D = $TransferPath/TransferOrbitVisual
@onready var rocket_transfer: PathFollow2D = $TransferPath/RocketTransfer

var _phase: Phase = Phase.INTRO


func _ready() -> void:
	_align_world_to_earth()
	camera.zoom = zoom_intro * 1.14
	camera.make_current()

	orbit_visual.visible = false
	moon.visible = false
	moon_orbit_visual.visible = false
	transfer_visual.visible = false
	_build_transfer_path()

	moon_follow.progress_ratio = 0.12
	rocket_moon.progress_ratio = 0.1

	var peri_off: float = leo_path.curve.get_closest_offset(Vector2(0.0, -LEO_R))
	leo_follow.progress = peri_off
	_set_rocket_coast()
	_run_mission()


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

	var full_pts := PackedVector2Array()
	for i in range(FULL_ELLIPSE_SEGMENTS + 1):
		var t := TAU * float(i) / float(FULL_ELLIPSE_SEGMENTS)
		full_pts.append(Vector2(b * cos(t), cy + a * sin(t)))
	transfer_visual.set_polyline(full_pts)


func _tween_camera_wait(zoom: Vector2, duration: float) -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "zoom", zoom, duration)
	await tw.finished


func _set_rocket_burning() -> void:
	rocket.texture = TEX_BURN


func _set_rocket_coast() -> void:
	rocket.texture = TEX_ROCKET


func _attach_rocket_to_leo() -> void:
	var peri_off: float = leo_path.curve.get_closest_offset(Vector2(0.0, -LEO_R))
	leo_follow.progress = peri_off
	rocket.reparent(leo_follow, false)
	rocket.position = Vector2.ZERO
	rocket.rotation = ROCKET_HEADING
	await get_tree().process_frame


func _sync_leo_to_periapsis_for_transfer(duration: float) -> void:
	var peri_ratio: float = _progress_ratio_at_local(leo_path, Vector2(0.0, -LEO_R))
	var p0: float = leo_follow.progress_ratio
	var delta: float = fposmod(peri_ratio - p0, 1.0)
	if delta < 0.003:
		leo_follow.progress_ratio = peri_ratio
		await get_tree().process_frame
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(
		func(t: float) -> void: leo_follow.progress_ratio = fposmod(p0 + t * delta, 1.0),
		0.0, 1.0, duration
	)
	await tw.finished
	leo_follow.progress_ratio = peri_ratio
	await get_tree().process_frame


func _progress_ratio_at_local(path: Path2D, local_point: Vector2) -> float:
	var path_len: float = path.curve.get_baked_length()
	if path_len <= 0.0:
		return 0.0
	var off: float = path.curve.get_closest_offset(local_point)
	return clampf(off / path_len, 0.0, 1.0)


func _attach_rocket_to_transfer() -> void:
	rocket_transfer.progress_ratio = 0.0
	rocket.reparent(rocket_transfer, false)
	rocket.position = Vector2.ZERO
	rocket.rotation = ROCKET_HEADING
	await get_tree().process_frame


func _attach_rocket_to_moon_orbit() -> void:
	var local_snap: Vector2 = moon_path.to_local(rocket.global_position)
	var off: float = moon_path.curve.get_closest_offset(local_snap)
	rocket_moon.progress = off
	rocket.reparent(rocket_moon, false)
	rocket.position = Vector2.ZERO
	rocket.rotation = ROCKET_HEADING
	await get_tree().process_frame


func _process(delta: float) -> void:
	moon_follow.progress_ratio += moon_orbit_speed * delta
	match _phase:
		Phase.LEO_ORBIT:
			leo_follow.progress_ratio += leo_orbit_speed * delta
		Phase.MOON_ORBIT:
			rocket_moon.progress_ratio += moon_orbit_speed * delta


func _run_mission() -> void:
	_phase = Phase.INTRO
	await _tween_camera_wait(zoom_intro, 0.35)
	await get_tree().create_timer(intro_duration).timeout

	_phase = Phase.LIFTOFF
	var tw_zoom_lift := create_tween()
	tw_zoom_lift.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw_zoom_lift.tween_property(camera, "zoom", zoom_liftoff, liftoff_duration * 0.35)
	_set_rocket_burning()
	var ascent_target: Vector2 = leo_path.global_position + liftoff_target_offset
	var tw_lift := create_tween()
	tw_lift.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_lift.tween_property(rocket, "global_position", ascent_target, liftoff_duration)
	await tw_lift.finished
	_set_rocket_coast()

	await _attach_rocket_to_leo()

	_phase = Phase.LEO_ORBIT
	await _tween_camera_wait(zoom_leo, camera_zoom_duration)
	orbit_visual.visible = true
	_set_rocket_burning()
	await get_tree().create_timer(leo_circularization_burn).timeout
	_set_rocket_coast()
	await get_tree().create_timer(leo_orbit_duration).timeout

	await _sync_leo_to_periapsis_for_transfer(leo_peri_sync_duration)

	moon.visible = true
	moon_orbit_visual.visible = true
	transfer_visual.visible = true
	await _tween_camera_wait(zoom_transfer_reveal, camera_zoom_duration * 0.85)
	await _tween_camera_wait(zoom_full_system, camera_wide_duration)

	_phase = Phase.TRANSFER_BURN
	await _attach_rocket_to_transfer()

	var burn_end: float = clampf(transfer_burn_path_fraction, 0.04, 0.45)
	var total_xfer: float = transfer_burn_duration + transfer_coast_duration
	var tw_xfer := create_tween()
	tw_xfer.tween_method(_transfer_progress_step.bind(burn_end), 0.0, 1.0, total_xfer)
	await tw_xfer.finished
	rocket_transfer.progress_ratio = 1.0
	_set_rocket_coast()

	await _attach_rocket_to_moon_orbit()

	_phase = Phase.MOON_ORBIT


func _transfer_progress_step(burn_end: float, u: float) -> void:
	rocket_transfer.progress_ratio = u
	if u < burn_end - 1e-6:
		rocket.texture = TEX_BURN
	else:
		rocket.texture = TEX_ROCKET

