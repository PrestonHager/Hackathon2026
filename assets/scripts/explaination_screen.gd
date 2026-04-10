extends Control

@onready var _btn_back: Button = $Margin/VBox/Nav/BackBtn
@onready var _btn_continue: Button = $Margin/VBox/Nav/ContinueBtn


func _ready() -> void:
	MissionState.planning_phase = MissionState.PlanningPhase.EXPLANATION
	_btn_back.pressed.connect(_on_back_pressed)
	_btn_continue.pressed.connect(_on_continue_pressed)


func _on_continue_pressed() -> void:
	MissionState.launch_mission()


func _on_back_pressed() -> void:
	MissionState.go_cargo()
