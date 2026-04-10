extends Node
## Shared budget and selections between crew (planning 1) and cargo (planning 2).

enum PlanningPhase { NONE, CREW, CARGO, EXPLANATION }

const PATH_CREW := "res://assets/levels/missionplanning.tscn"
const PATH_CARGO := "res://assets/levels/missionplanning2.tscn"
const PATH_EXPLANATION := "res://assets/levels/explaination_screen.tscn"
const PATH_MAIN_MENU := "res://assets/levels/main_menu.tscn"
const PATH_GAME := "res://assets/levels/maingamescene.tscn"
const PATH_WIN := "res://assets/levels/win_screen.tscn"

const CREW_COSTS := {
	"alien": 20,
	"astronaut": 15,
	"bear": 10,
	"buff": 18,
}

## Each item: id, display name, category contributions (points per unit), cost $M per unit.
const CARGO_ITEMS: Array[Dictionary] = [
	{"id": "mre", "name": "MRE stacks", "food": 2, "water": 0, "health": 0, "morale": 0, "cost": 2},
	{"id": "hydro", "name": "Hydro cubes", "food": 0, "water": 3, "health": 0, "morale": 0, "cost": 2},
	{"id": "medkit", "name": "Medkit", "food": 0, "water": 0, "health": 3, "morale": 0, "cost": 3},
	{"id": "comms", "name": "Comms rig", "food": 0, "water": 0, "health": 0, "morale": 2, "cost": 2},
	{"id": "greens", "name": "Greens pouch", "food": 2, "water": 1, "health": 1, "morale": 0, "cost": 3},
	{"id": "purifier", "name": "Water purifier", "food": 0, "water": 2, "health": 1, "morale": 0, "cost": 3},
	{"id": "vitamins", "name": "Vitamin kit", "food": 0, "water": 0, "health": 2, "morale": 1, "cost": 2},
	{"id": "hobby", "name": "Hobby crate", "food": 0, "water": 0, "health": 0, "morale": 3, "cost": 2},
	{"id": "bars", "name": "Protein bars", "food": 1, "water": 0, "health": 1, "morale": 1, "cost": 1},
	{"id": "ice", "name": "Ice melt packs", "food": 0, "water": 2, "health": 0, "morale": 0, "cost": 1},
]

const MIN_FOOD: int = 5
const MIN_WATER: int = 5
const MIN_HEALTH: int = 4
const MIN_MORALE: int = 4
const MAX_CARGO_SLOTS: int = 20

var planning_phase: PlanningPhase = PlanningPhase.NONE
var initial_budget_millions: int = 75

var crew_counts := {
	"alien": 0,
	"astronaut": 0,
	"bear": 0,
	"buff": 0,
}

## item id -> count
var cargo_counts: Dictionary = {}


func start_new_plan(budget_millions: int) -> void:
	initial_budget_millions = budget_millions
	for k in crew_counts:
		crew_counts[k] = 0
	cargo_counts.clear()
	for it in CARGO_ITEMS:
		cargo_counts[it["id"]] = 0
	planning_phase = PlanningPhase.CREW


func crew_spent_millions() -> int:
	var s: int = 0
	for k in crew_counts:
		s += crew_counts[k] * int(CREW_COSTS[k])
	return s


func cargo_spent_millions() -> int:
	var s: int = 0
	for it in CARGO_ITEMS:
		var id: String = it["id"]
		s += int(cargo_counts.get(id, 0)) * int(it["cost"])
	return s


func budget_remaining_millions() -> int:
	return initial_budget_millions - crew_spent_millions() - cargo_spent_millions()


func cargo_total_units() -> int:
	var n: int = 0
	for v in cargo_counts.values():
		n += int(v)
	return n


func cargo_category_total(cat: String) -> int:
	var t: int = 0
	for it in CARGO_ITEMS:
		var id: String = it["id"]
		var c: int = int(cargo_counts.get(id, 0))
		t += c * int(it.get(cat, 0))
	return t


func cargo_requirements_met() -> bool:
	return (
		cargo_category_total("food") >= MIN_FOOD
		and cargo_category_total("water") >= MIN_WATER
		and cargo_category_total("health") >= MIN_HEALTH
		and cargo_category_total("morale") >= MIN_MORALE
	)


func cargo_can_add(item_id: String) -> bool:
	if cargo_total_units() >= MAX_CARGO_SLOTS:
		return false
	var cost: int = 0
	for it in CARGO_ITEMS:
		if it["id"] == item_id:
			cost = int(it["cost"])
			break
	return budget_remaining_millions() >= cost


func go_crew() -> void:
	get_tree().change_scene_to_file(PATH_CREW)


func go_cargo() -> void:
	planning_phase = PlanningPhase.CARGO
	get_tree().change_scene_to_file(PATH_CARGO)


func go_main_menu() -> void:
	planning_phase = PlanningPhase.NONE
	get_tree().change_scene_to_file(PATH_MAIN_MENU)


## After cargo planning: briefing screen (Earth animation starts from `launch_mission`).
func go_explanation() -> void:
	if not cargo_requirements_met():
		return
	planning_phase = PlanningPhase.EXPLANATION
	get_tree().change_scene_to_file(PATH_EXPLANATION)


func launch_mission() -> void:
	if not cargo_requirements_met():
		return
	planning_phase = PlanningPhase.NONE
	get_tree().change_scene_to_file(PATH_GAME)


func go_win_screen() -> void:
	planning_phase = PlanningPhase.NONE
	get_tree().change_scene_to_file(PATH_WIN)
