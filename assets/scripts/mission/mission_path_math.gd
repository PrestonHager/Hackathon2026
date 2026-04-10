## Baked Path2D helpers (progress ratio, closest point).
class_name MissionPathMath
extends RefCounted


static func progress_ratio_at_local(path: Path2D, local_point: Vector2) -> float:
	var path_len: float = path.curve.get_baked_length()
	if path_len <= 0.0:
		return 0.0
	var off: float = path.curve.get_closest_offset(local_point)
	return clampf(off / path_len, 0.0, 1.0)
