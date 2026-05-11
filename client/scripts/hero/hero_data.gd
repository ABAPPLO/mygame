class_name HeroData

var id: String
var name: String
var hero_class: String
var personality: String
var level: int = 1
var exp: int = 0
var stats: Dictionary = {}
var max_hp: int = 100
var talent: Dictionary = {}
var skills: Array = []
var equipment_weapon: String = ""
var equipment_armor: String = ""
var troops: int = 0
var max_troops: int = 20
var pos_x: int = 0
var pos_y: int = 0
var in_town: bool = true


static func from_dict(data: Dictionary) -> HeroData:
	var h = HeroData.new()
	h.id = data.get("id", "")
	h.name = data.get("name", "Unknown")
	h.hero_class = data.get("class", "Warrior")
	h.personality = data.get("personality", "")
	h.level = data.get("level", 1)
	h.exp = data.get("exp", 0)
	h.stats = data.get("base_stats", {}).duplicate()
	h.max_hp = h.stats.get("hp", 100)
	h.talent = data.get("talent", {})
	h.skills = data.get("skills", [])
	h.troops = data.get("troops_base", 5)
	h.max_troops = data.get("troops_max", 20)
	h.pos_x = data.get("pos_x", 1)
	h.pos_y = data.get("pos_y", 1)
	h.in_town = data.get("in_town", true)
	return h


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"hero_class": hero_class,
		"personality": personality,
		"level": level,
		"exp": exp,
		"stats": stats,
		"max_hp": max_hp,
		"talent": talent,
		"skills": skills,
		"equipment_weapon": equipment_weapon,
		"equipment_armor": equipment_armor,
		"troops": troops,
		"max_troops": max_troops,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"in_town": in_town,
	}
