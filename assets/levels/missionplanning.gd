extends Node2D

# -------- SETTINGS --------
var max_passengers := 3
var selected_count := 0

var budget := 50   # in millions

# Character costs
var costs := {
	"alien": 20,
	"astronaut": 15,
	"bear": 10
}

# -------- NODE REFERENCES --------
@onready var budget_label = $budget/Label

@onready var alien_btn = $alien/Button
@onready var astronaut_btn = $astronaut/Button
@onready var bear_btn = $bear/Button


func _ready():
	# Connect buttons
	alien_btn.pressed.connect(_on_add_pressed.bind("alien"))
	astronaut_btn.pressed.connect(_on_add_pressed.bind("astronaut"))
	bear_btn.pressed.connect(_on_add_pressed.bind("bear"))

	_update_budget_label()


# -------- CORE FUNCTION --------
func _on_add_pressed(character_name: String):

	# Check passenger limit
	if selected_count >= max_passengers:
		print("Max passengers reached")
		return

	var cost = costs[character_name]

	# Check budget
	if budget - cost < 0:
		print("Not enough budget")
		return

	# Deduct budget
	budget -= cost
	selected_count += 1

	print(character_name, " added!")

	_update_budget_label()

	# OPTIONAL: disable button after selecting
	match character_name:
		"alien":
			alien_btn.disabled = true
		"astronaut":
			astronaut_btn.disabled = true
		"bear":
			bear_btn.disabled = true


# -------- UI UPDATE --------
func _update_budget_label():
	budget_label.text = "Budget: $%d M" % budget
