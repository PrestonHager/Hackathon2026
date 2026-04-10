extends Node2D
## KSP-style map markers for predicted transfer Pe/Ap in the parent’s local space (e.g. mission root).

@export var pe_radius: float = 5.0
@export var ap_radius: float = 5.0
@export var pe_color: Color = Color(0.25, 0.82, 0.98, 0.92)
@export var ap_color: Color = Color(0.95, 0.38, 0.22, 0.92)

var _pe_local: Vector2 = Vector2.ZERO
var _ap_local: Vector2 = Vector2.ZERO
var _show_transfer_apsides: bool = false


func set_transfer_apsides_visible(p_visible: bool) -> void:
	_show_transfer_apsides = p_visible
	queue_redraw()


func set_transfer_apsides_local(peri_local: Vector2, apo_local: Vector2) -> void:
	_pe_local = peri_local
	_ap_local = apo_local
	queue_redraw()


func _draw() -> void:
	if not _show_transfer_apsides:
		return
	draw_circle(_pe_local, pe_radius, pe_color)
	draw_circle(_ap_local, ap_radius, ap_color)
