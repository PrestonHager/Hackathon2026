class_name DashedPolyline2D
extends Node2D
## Dashed polyline in local space (e.g. under a Path2D). Used for transfer ellipse visualization.

@export var line_width: float = 2.5
@export var line_color: Color = Color(0.95, 0.55, 0.22, 0.92)
@export var dash_length: float = 11.0
@export var gap_length: float = 9.0

var _points: PackedVector2Array = PackedVector2Array()


func set_polyline(pts: PackedVector2Array) -> void:
	_points = pts
	queue_redraw()


func _draw() -> void:
	if _points.size() < 2:
		return
	var cycle := dash_length + gap_length
	var base := 0.0
	for i in range(_points.size() - 1):
		var a: Vector2 = _points[i]
		var b: Vector2 = _points[i + 1]
		var seg_len: float = a.distance_to(b)
		if seg_len < 0.0001:
			continue
		var dir: Vector2 = (b - a) / seg_len
		var d := 0.0
		while d < seg_len - 1e-6:
			var pos := base + d
			var ph := fposmod(pos, cycle)
			var rem_seg := seg_len - d
			if ph < dash_length:
				var dash_rem := dash_length - ph
				var len_draw := minf(dash_rem, rem_seg)
				var p0 := a + dir * d
				var p1 := a + dir * (d + len_draw)
				draw_line(p0, p1, line_color, line_width, true)
				d += len_draw
			else:
				var gap_rem := cycle - ph
				var len_skip := minf(gap_rem, rem_seg)
				d += len_skip
		base += seg_len
