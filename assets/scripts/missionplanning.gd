extends Node2D

## Used only when starting a fresh plan (see _ready).
@export var starting_budget_millions: int = 75
@export var max_crew: int = 3

@onready var _budget_label: Label = $budget
@onready var _budget_slider: HSlider = $budgetSlider
@onready var _crew_total_label: Label = $crewTotalLabel

@onready var _alien_minus: Button = $alien/Minus
@onready var _alien_plus: Button = $alien/Plus
@onready var _alien_count: Label = $alien/CountLabel

@onready var _astronaut_minus: Button = $astronaut/Minus
@onready var _astronaut_plus: Button = $astronaut/Plus
@onready var _astronaut_count: Label = $astronaut/CountLabel

@onready var _bear_minus: Button = $bear/Minus
@onready var _bear_plus: Button = $bear/Plus
@onready var _bear_count: Label = $bear/CountLabel

@onready var _buff_minus: Button = $BuffGuy/Minus
@onready var _buff_plus: Button = $BuffGuy/Plus
@onready var _buff_count: Label = $BuffGuy/CountLabel

@onready var _btn_back: Button = $BackBtn
@onready var _btn_next: Button = $NextBtn


func _ready() -> void:
	if MissionState.planning_phase == MissionState.PlanningPhase.NONE:
		MissionState.start_new_plan(starting_budget_millions)
	MissionState.planning_phase = MissionState.PlanningPhase.CREW

	_budget_slider.min_value = 0.0
	_budget_slider.max_value = float(MissionState.initial_budget_millions)
	_budget_slider.step = 1.0
	_budget_slider.editable = false
	_budget_slider.focus_mode = Control.FOCUS_NONE
	_budget_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_alien_minus.pressed.connect(_on_minus_pressed.bind("alien"))
	_alien_plus.pressed.connect(_on_plus_pressed.bind("alien"))
	_astronaut_minus.pressed.connect(_on_minus_pressed.bind("astronaut"))
	_astronaut_plus.pressed.connect(_on_plus_pressed.bind("astronaut"))
	_bear_minus.pressed.connect(_on_minus_pressed.bind("bear"))
	_bear_plus.pressed.connect(_on_plus_pressed.bind("bear"))
	_buff_minus.pressed.connect(_on_minus_pressed.bind("buff"))
	_buff_plus.pressed.connect(_on_plus_pressed.bind("buff"))

	_btn_back.pressed.connect(_on_back_pressed)
	_btn_next.pressed.connect(_on_next_pressed)

	_refresh_ui()


func _total_crew() -> int:
	var n: int = 0
	for k in MissionState.crew_counts:
		n += MissionState.crew_counts[k]
	return n


func _can_add(type_key: String) -> bool:
	if _total_crew() >= max_crew:
		return false
	return MissionState.budget_remaining_millions() >= int(MissionState.CREW_COSTS[type_key])


func _on_plus_pressed(type_key: String) -> void:
	if not _can_add(type_key):
		return
	MissionState.crew_counts[type_key] += 1
	_refresh_ui()


func _on_minus_pressed(type_key: String) -> void:
	if MissionState.crew_counts[type_key] <= 0:
		return
	MissionState.crew_counts[type_key] -= 1
	_refresh_ui()


func _on_back_pressed() -> void:
	MissionState.go_main_menu()


func _on_next_pressed() -> void:
	MissionState.go_cargo()


func _refresh_ui() -> void:
	var remaining: int = MissionState.budget_remaining_millions()
	_budget_label.text = "Budget: $%d M left  (pool $%d M)" % [remaining, MissionState.initial_budget_millions]
	_budget_slider.max_value = float(MissionState.initial_budget_millions)
	_budget_slider.value = float(remaining)

	_crew_total_label.text = "Crew: %d / %d  (− / +)" % [_total_crew(), max_crew]

	_alien_count.text = str(MissionState.crew_counts["alien"])
	_astronaut_count.text = str(MissionState.crew_counts["astronaut"])
	_bear_count.text = str(MissionState.crew_counts["bear"])
	_buff_count.text = str(MissionState.crew_counts["buff"])

	_alien_plus.disabled = not _can_add("alien")
	_astronaut_plus.disabled = not _can_add("astronaut")
	_bear_plus.disabled = not _can_add("bear")
	_buff_plus.disabled = not _can_add("buff")

	_alien_minus.disabled = MissionState.crew_counts["alien"] <= 0
	_astronaut_minus.disabled = MissionState.crew_counts["astronaut"] <= 0
	_bear_minus.disabled = MissionState.crew_counts["bear"] <= 0
	_buff_minus.disabled = MissionState.crew_counts["buff"] <= 0
