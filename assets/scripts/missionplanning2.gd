extends Control

const _TEXTURE_LINEAR := CanvasItem.TEXTURE_FILTER_LINEAR

@onready var _budget_label: Label = $VBox/BudgetLabel
@onready var _budget_slider: HSlider = $VBox/BudgetSlider
@onready var _req_label: Label = $VBox/ReqLabel
@onready var _slots_label: Label = $VBox/SlotsLabel
@onready var _rows_parent: VBoxContainer = $VBox/Scroll/Rows
@onready var _btn_back: Button = $VBox/Nav/BackBtn
@onready var _btn_next: Button = $VBox/Nav/NextBtn


func _ready() -> void:
	MissionState.planning_phase = MissionState.PlanningPhase.CARGO
	_budget_slider.min_value = 0.0
	_budget_slider.step = 1.0
	_budget_slider.editable = false
	_budget_slider.focus_mode = Control.FOCUS_NONE
	_budget_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_back.pressed.connect(_on_back)
	_btn_next.pressed.connect(_on_next)
	_build_rows()
	_refresh()


func _build_rows() -> void:
	for c in _rows_parent.get_children():
		c.queue_free()
	for it in MissionState.CARGO_ITEMS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_l := Label.new()
		name_l.texture_filter = _TEXTURE_LINEAR
		name_l.text = "%s — $%d M each" % [it["name"], it["cost"]]
		name_l.add_theme_font_size_override("font_size", 11)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var stats := Label.new()
		stats.texture_filter = _TEXTURE_LINEAR
		stats.text = "F%+d W%+d H%+d M%+d" % [
			int(it["food"]),
			int(it["water"]),
			int(it["health"]),
			int(it["morale"]),
		]
		stats.add_theme_font_size_override("font_size", 10)
		stats.custom_minimum_size.x = 118
		var minus := Button.new()
		minus.texture_filter = _TEXTURE_LINEAR
		minus.text = "−"
		minus.custom_minimum_size = Vector2(28, 24)
		var cnt := Label.new()
		cnt.texture_filter = _TEXTURE_LINEAR
		cnt.custom_minimum_size = Vector2(32, 0)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var plus := Button.new()
		plus.texture_filter = _TEXTURE_LINEAR
		plus.text = "+"
		plus.custom_minimum_size = Vector2(28, 24)
		var id: String = it["id"]
		minus.pressed.connect(_on_minus.bind(id))
		plus.pressed.connect(_on_plus.bind(id))
		row.add_child(name_l)
		row.add_child(stats)
		row.add_child(minus)
		row.add_child(cnt)
		row.add_child(plus)
		_rows_parent.add_child(row)
		row.set_meta("count_label", cnt)
		row.set_meta("minus_btn", minus)
		row.set_meta("plus_btn", plus)


func _on_minus(item_id: String) -> void:
	if int(MissionState.cargo_counts.get(item_id, 0)) <= 0:
		return
	MissionState.cargo_counts[item_id] -= 1
	_refresh()


func _on_plus(item_id: String) -> void:
	if not MissionState.cargo_can_add(item_id):
		return
	MissionState.cargo_counts[item_id] += 1
	_refresh()


func _on_back() -> void:
	MissionState.go_crew()


func _on_next() -> void:
	MissionState.go_explanation()


func _requirements_line() -> String:
	var f: int = MissionState.cargo_category_total("food")
	var w: int = MissionState.cargo_category_total("water")
	var h: int = MissionState.cargo_category_total("health")
	var m: int = MissionState.cargo_category_total("morale")
	return (
		"Minimum totals — food %d, water %d, health %d, morale %d\n"
		+ "Current — food %d/%d  water %d/%d  health %d/%d  morale %d/%d"
	) % [
		MissionState.MIN_FOOD,
		MissionState.MIN_WATER,
		MissionState.MIN_HEALTH,
		MissionState.MIN_MORALE,
		f,
		MissionState.MIN_FOOD,
		w,
		MissionState.MIN_WATER,
		h,
		MissionState.MIN_HEALTH,
		m,
		MissionState.MIN_MORALE,
	]


func _refresh() -> void:
	var remaining: int = MissionState.budget_remaining_millions()
	_budget_label.text = "Budget: $%d M left  (pool $%d M)" % [remaining, MissionState.initial_budget_millions]
	_budget_slider.max_value = float(MissionState.initial_budget_millions)
	_budget_slider.value = float(remaining)
	_req_label.text = _requirements_line()
	_slots_label.text = "Cargo units: %d / %d" % [MissionState.cargo_total_units(), MissionState.MAX_CARGO_SLOTS]

	for i in _rows_parent.get_child_count():
		var row: HBoxContainer = _rows_parent.get_child(i) as HBoxContainer
		var id: String = MissionState.CARGO_ITEMS[i]["id"]
		var n: int = int(MissionState.cargo_counts.get(id, 0))
		row.get_meta("count_label").text = str(n)
		row.get_meta("minus_btn").disabled = n <= 0
		row.get_meta("plus_btn").disabled = not MissionState.cargo_can_add(id)

	_btn_next.disabled = not MissionState.cargo_requirements_met()
