extends Node2D



@onready var cg_slider = $PadAnchor/Rocket/CGSlider
@onready var cp_slider = $PadAnchor/Rocket/CPSlider
@onready var stability_label = $StabilityLabel

# Visual markers (optional but recommended)
@onready var cg_marker = $CGMarker
@onready var cp_marker = $CPMarker

# Rocket height for mapping slider → position
var rocket_height = 200.0   # adjust to your sprite size

func _ready():
	# Configure sliders
	cg_slider.min_value = 0
	cg_slider.max_value = 1
	cg_slider.step = 0.01
	cg_slider.value = 0.3   # default CG

	cp_slider.min_value = 0
	cp_slider.max_value = 1
	cp_slider.step = 0.01
	cp_slider.value = 0.6   # default CP

	# Connect signals
	cg_slider.value_changed.connect(_on_slider_changed)
	cp_slider.value_changed.connect(_on_slider_changed)

	update_system()


func _on_slider_changed(value):
	update_system()


func update_system():
	var cg = cg_slider.value
	var cp = cp_slider.value

	var stability = cg - cp

	update_visuals(cg, cp)
	update_label(stability)


func update_visuals(cg, cp):
	# Map slider (0–1) to rocket vertical position
	# Top = 0, Bottom = rocket_height

	var cg_y = -cg * rocket_height
	var cp_y = -cp * rocket_height

	cg_marker.position.y = cg_y
	cp_marker.position.y = cp_y


func update_label(stability):
	var text = ""

	if stability > 0.05:
		text = "Stable ✅"
	elif stability < -0.05:
		text = "Unstable ❌"
	else:
		text = "Marginal ⚠️"

	stability_label.text = "Stability: %.2f\n%s" % [stability, text]
