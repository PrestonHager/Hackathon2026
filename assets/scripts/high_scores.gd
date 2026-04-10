extends Node
## Persists a local JSON scoreboard under `user://`.

const FILE_PATH := "user://mission_high_scores.json"
const MAX_ENTRIES := 10


func load_entries() -> Array:
	if not FileAccess.file_exists(FILE_PATH):
		return []
	var f: FileAccess = FileAccess.open(FILE_PATH, FileAccess.READ)
	if f == null:
		return []
	var txt: String = f.get_as_text()
	if txt.is_empty():
		return []
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null or typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed


func _write_entries(entries: Array) -> void:
	var f: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("HighScores: could not write ", FILE_PATH)
		return
	f.store_string(JSON.stringify(entries))


func submit(player_name: String, score: int) -> void:
	var clean: String = player_name.strip_edges()
	if clean.is_empty():
		clean = "Pilot"
	clean = clean.substr(0, 24)
	var entries: Array = load_entries()
	entries.append(
		{"name": clean, "score": score, "t": int(Time.get_unix_time_from_system())}
	)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	_write_entries(entries)


func top_entries() -> Array:
	var e: Array = load_entries()
	e.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	return e
