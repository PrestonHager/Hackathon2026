## Camera zoom helpers: only zoom out (never increase zoom vs current frame).
class_name MissionCameraRoutines
extends RefCounted


## Returns a Tween, SceneTreeTimer, or null. Caller: `if r is SceneTreeTimer: await r.timeout else: await r.finished`.
static func tween_zoom_out_only(host: Node, camera: Camera2D, zoom: Vector2, duration: float) -> Variant:
	var target := Vector2(minf(camera.zoom.x, zoom.x), minf(camera.zoom.y, zoom.y))
	if is_equal_approx(target.x, camera.zoom.x) and is_equal_approx(target.y, camera.zoom.y):
		return null
	var tw := host.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera, "zoom", target, duration)
	return tw
