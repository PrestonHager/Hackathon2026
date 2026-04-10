extends Control

@onready var _score_value: Label = $Margin/VBox/ScoreValue
@onready var _name_field: LineEdit = $Margin/VBox/NameRow/NameField
@onready var _save_btn: Button = $Margin/VBox/NameRow/SaveBtn
@onready var _board: Label = $Margin/VBox/BoardScroll/BoardText
@onready var _menu_btn: Button = $Margin/VBox/MainMenuBtn


func _ready() -> void:
	var score: int = MissionState.budget_remaining_millions()
	_score_value.text = "$%d M" % score
	_save_btn.pressed.connect(_on_save_pressed)
	_menu_btn.pressed.connect(_on_menu_pressed)
	_name_field.text_submitted.connect(func(_t: String) -> void: _on_save_pressed())
	_refresh_board()


func _on_save_pressed() -> void:
	HighScores.submit(_name_field.text, MissionState.budget_remaining_millions())
	_refresh_board()


func _on_menu_pressed() -> void:
	MissionState.go_main_menu()


func _refresh_board() -> void:
	var lines: PackedStringArray = PackedStringArray()
	var rank: int = 1
	for e: Variant in HighScores.top_entries():
		var d: Dictionary = e
		lines.append("%d. %s — $%d M" % [rank, str(d["name"]), int(d["score"])])
		rank += 1
	if lines.is_empty():
		_board.text = "No scores saved yet."
	else:
		_board.text = "\n".join(lines)
