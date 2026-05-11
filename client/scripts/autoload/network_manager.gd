extends Node

const SERVER_URL = "http://localhost:8000/api"

var _http_requests: Dictionary = {}

func request(endpoint: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)

	var url = SERVER_URL + endpoint
	var headers = ["Content-Type: application/json"]
	var result_code
	var response_data

	if method == HTTPClient.METHOD_GET:
		result_code = http.request(url, headers, method)
	elif method == HTTPClient.METHOD_POST:
		var json_body = JSON.stringify(body)
		result_code = http.request(url, headers, method, json_body)

	if result_code != OK:
		http.queue_free()
		return {"error": "Request failed: " + str(result_code)}

	var response = await http.request_completed
	var _result = response[0]
	var _code = response[1]
	var _headers = response[2]
	var body_data = response[3]

	var json = JSON.new()
	var parse_result = json.parse(body_data.get_string_from_utf8())

	http.queue_free()

	if parse_result != OK:
		return {"error": "JSON parse failed"}

	return json.data


func get_heroes() -> Dictionary:
	return await request("/game/heroes")

func get_equipment() -> Dictionary:
	return await request("/game/equipment")

func get_monsters() -> Dictionary:
	return await request("/game/monsters")

func get_buildings() -> Dictionary:
	return await request("/game/buildings")

func refresh_tavern() -> Dictionary:
	return await request("/game/tavern/refresh")

func generate_map(seed_val: int = -1) -> Dictionary:
	var endpoint = "/game/map/generate"
	if seed_val >= 0:
		endpoint += "?seed=" + str(seed_val)
	return await request(endpoint)

func ai_explore(hero_data: Dictionary) -> Dictionary:
	return await request("/ai/explore", HTTPClient.METHOD_POST, hero_data)

func ai_combat(combat_data: Dictionary) -> Dictionary:
	return await request("/ai/combat", HTTPClient.METHOD_POST, combat_data)
