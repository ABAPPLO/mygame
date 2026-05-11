extends Node

enum GameState { MAIN_MENU, TOWN, MAP, BATTLE }

signal state_changed(new_state: GameState)

var current_state: GameState = GameState.MAIN_MENU
var heroes: Array = []
var max_heroes: int = 3
var building_levels: Dictionary = {
	"tavern": 1,
	"barracks": 1,
	"blacksmith": 1,
}

func change_state(new_state: GameState):
	current_state = new_state
	state_changed.emit(new_state)

	match new_state:
		GameState.MAIN_MENU:
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		GameState.TOWN:
			get_tree().change_scene_to_file("res://scenes/town.tscn")
		GameState.MAP:
			get_tree().change_scene_to_file("res://scenes/world_map.tscn")
		GameState.BATTLE:
			get_tree().change_scene_to_file("res://scenes/battle.tscn")

func add_hero(hero_data: Dictionary) -> bool:
	if heroes.size() >= max_heroes:
		return false
	var hero = {
		"id": hero_data.get("id", ""),
		"name": hero_data.get("name", "Unknown"),
		"hero_class": hero_data.get("class", "Warrior"),
		"personality": hero_data.get("personality", ""),
		"level": 1,
		"exp": 0,
		"stats": hero_data.get("base_stats", {}).duplicate(),
		"max_hp": hero_data.get("base_stats", {}).get("hp", 100),
		"talent": hero_data.get("talent", {}),
		"skills": hero_data.get("skills", []).duplicate(true),
		"equipment_weapon": null,
		"equipment_armor": null,
		"troops": hero_data.get("troops_base", 5),
		"max_troops": hero_data.get("troops_max", 20),
		"pos_x": 1,
		"pos_y": 1,
		"in_town": true,
	}
	heroes.append(hero)
	return true

func get_hero(hero_id: String) -> Dictionary:
	for h in heroes:
		if h.id == hero_id:
			return h
	return {}

func get_active_heroes() -> Array:
	return heroes.filter(func(h): return not h.in_town)

func add_exp_to_hero(hero_id: String, amount: int):
	for h in heroes:
		if h.id == hero_id:
			h.exp += amount
			var exp_needed = h.level * 100
			while h.exp >= exp_needed:
				h.exp -= exp_needed
				h.level += 1
				h.stats.hp = int(h.stats.hp * 1.1)
				h.max_hp = h.stats.hp
				h.stats.atk = int(h.stats.atk * 1.1)
				h.stats.defense = int(h.stats.get("def", 5) * 1.1)
				h.max_troops += 5
				exp_needed = h.level * 100

func get_save_data() -> Dictionary:
	return {
		"heroes": heroes,
		"building_levels": building_levels,
	}

func load_data(data: Dictionary):
	heroes = data.get("heroes", [])
	building_levels = data.get("building_levels", {"tavern": 1, "barracks": 1, "blacksmith": 1})

func new_game():
	heroes.clear()
	building_levels = {"tavern": 1, "barracks": 1, "blacksmith": 1}
	ResourceManager.gold = 100
	ResourceManager.wood = 50
	ResourceManager.stone = 30
	ResourceManager.crystal = 0
