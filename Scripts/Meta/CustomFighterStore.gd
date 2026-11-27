class_name CustomFighterStore
extends RefCounted
## Persistent JSON storage & CharacterData hydration for player-created Quick Match / Local 2P fighters.
## Supports selectable Point-Buy Tiers and Sandbox Mode (all classes) vs Class-restricted decks.

const CUSTOM_DIR: String = "user://custom_fighters/"

const POINT_BUY_TIERS: Array[Dictionary] = [
	{ "id": "standard", "label": "Standard (0 pts)", "points": 0 },
	{ "id": "veteran", "label": "Veteran (5 pts)", "points": 5 },
	{ "id": "champion", "label": "Champion (9 pts)", "points": 9 },
]


static func get_tier_points(tier_id: String) -> int:
	for tier: Dictionary in POINT_BUY_TIERS:
		if str(tier["id"]) == tier_id:
			return int(tier["points"])
	return 0


static func get_tier_label(tier_id: String) -> String:
	for tier: Dictionary in POINT_BUY_TIERS:
		if str(tier["id"]) == tier_id:
			return str(tier["label"])
	return "Standard (0 pts)"


static func get_origin_tag(is_sandbox: bool) -> String:
	return "Custom · Sandbox" if is_sandbox else "Custom · Class"


static func sanitize_id(fighter_name: String) -> String:
	var cleaned: String = fighter_name.strip_edges().to_lower().validate_filename()
	cleaned = cleaned.replace(" ", "_")
	if cleaned == "":
		cleaned = "custom_fighter"
	return cleaned


static func list_fighters() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(CUSTOM_DIR)
	if dir == null:
		return results

	dir.list_dir_begin()
	var fn: String = dir.get_next()
	while fn != "":
		if not dir.current_is_dir() and fn.ends_with(".json"):
			var loaded: Dictionary = load_fighter_file(CUSTOM_DIR + fn)
			if not loaded.is_empty():
				results.append(loaded)
		fn = dir.get_next()
	dir.list_dir_end()

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
	)
	return results


static func load_fighter_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return {}
	return _normalize_data(parsed as Dictionary)


static func save_fighter(data: Dictionary) -> Error:
	if not DirAccess.dir_exists_absolute(CUSTOM_DIR):
		DirAccess.make_dir_absolute(CUSTOM_DIR)

	var norm: Dictionary = _normalize_data(data)
	var path: String = CUSTOM_DIR + str(norm["id"]) + ".json"
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("CustomFighterStore: Failed to open for write: ", path)
		return ERR_CANT_OPEN
	f.store_string(JSON.stringify(norm, "  "))
	f.close()
	return OK


static func delete_fighter(fighter_id: String) -> void:
	var path: String = CUSTOM_DIR + sanitize_id(fighter_id) + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func get_legal_card_pool(class_type: CharacterData.ClassType, is_sandbox: bool) -> Array[ActionData]:
	var cards: Array[ActionData] = []
	var seen: Dictionary = {}

	# 1. All 8 Basic Actions
	for basic: ActionData in ClassFactory.get_basic_actions():
		_append_unique(cards, seen, basic)

	if is_sandbox:
		# All 4 classes' starter cards + every skill-tree action
		for ctype: CharacterData.ClassType in [
			CharacterData.ClassType.HEAVY,
			CharacterData.ClassType.PATIENT,
			CharacterData.ClassType.QUICK,
			CharacterData.ClassType.TECHNICAL,
		]:
			if ClassFactory.class_registry.has(ctype):
				var def: ClassDefinition = ClassFactory.class_registry[ctype]
				if def != null:
					for sc: ActionData in def.starting_deck:
						_append_unique(cards, seen, sc)
		var all_ids: Array = ClassFactory.ID_TO_NAME_MAP.keys()
		all_ids.sort()
		for id_val: Variant in all_ids:
			var nid: int = int(id_val)
			if nid in ClassFactory.CLASS_ROOT_IDS:
				continue
			var cname: String = str(ClassFactory.ID_TO_NAME_MAP[nid])
			_append_unique(cards, seen, ClassFactory.find_action_resource(cname))
	else:
		# Selected class starter cards + reachable actions from that class's tree root
		if ClassFactory.class_registry.has(class_type):
			var def: ClassDefinition = ClassFactory.class_registry[class_type]
			if def != null:
				for sc: ActionData in def.starting_deck:
					_append_unique(cards, seen, sc)

		var root_id: int = _get_class_root_id(class_type)
		var visited: Dictionary = { root_id: true }
		var queue: Array[int] = [root_id]
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			if cur in ClassFactory.TREE_CONNECTIONS:
				for neighbor: int in ClassFactory.TREE_CONNECTIONS[cur]:
					if not visited.has(neighbor):
						visited[neighbor] = true
						# Don't cross into another class's root
						if neighbor in ClassFactory.CLASS_ROOT_IDS:
							continue
						queue.append(neighbor)
						var cname: Variant = ClassFactory.ID_TO_NAME_MAP.get(neighbor)
						if cname != null:
							_append_unique(cards, seen, ClassFactory.find_action_resource(str(cname)))

	cards.sort_custom(func(a: ActionData, b: ActionData) -> bool:
		if a.type != b.type:
			return int(a.type) < int(b.type)
		if a.cost != b.cost:
			return a.cost < b.cost
		return a.display_name < b.display_name
	)
	return cards


static func build_character_data(data: Dictionary) -> CharacterData:
	var norm: Dictionary = _normalize_data(data)
	var ctype: CharacterData.ClassType = int(norm["class_type"]) as CharacterData.ClassType
	var fighter_name: String = str(norm["name"])
	var c: CharacterData = ClassFactory.create_character(ctype, fighter_name, false)
	if c == null:
		return null

	c.max_hp = maxi(1, c.max_hp + int(norm["bonus_hp"]))
	c.max_sp = maxi(1, c.max_sp + int(norm["bonus_sp"]))
	c.current_hp = c.max_hp
	c.current_sp = c.max_sp

	var custom_deck: Array[ActionData] = []
	var card_names: Array = norm.get("deck_cards", []) as Array
	for cn_var: Variant in card_names:
		var cn: String = str(cn_var)
		var card: ActionData = _find_action(cn)
		if card != null and custom_deck.size() < ClassFactory.HAND_LIMIT:
			custom_deck.append(card.duplicate(true) as ActionData)

	if not custom_deck.is_empty():
		c.deck = custom_deck
		c.unlocked_actions = custom_deck.duplicate()

	c.ai_profile = ClassFactory.pick_random_ai_profile()
	return c


static func _find_action(card_name: String) -> ActionData:
	var res: ActionData = ClassFactory.find_action_resource(card_name)
	if res != null:
		return res
	for b: ActionData in ClassFactory.get_basic_actions():
		if b.display_name.to_lower() == card_name.to_lower():
			return b
	return null


static func _get_class_root_id(class_type: CharacterData.ClassType) -> int:
	match class_type:
		CharacterData.ClassType.QUICK: return 73
		CharacterData.ClassType.TECHNICAL: return 74
		CharacterData.ClassType.PATIENT: return 75
		CharacterData.ClassType.HEAVY: return 76
	return 76


static func _append_unique(target: Array[ActionData], seen: Dictionary, card: ActionData) -> void:
	if card == null:
		return
	var k: String = card.display_name.to_lower()
	if seen.has(k):
		return
	seen[k] = true
	target.append(card)


static func _normalize_data(raw: Dictionary) -> Dictionary:
	var name_s: String = str(raw.get("name", "Custom Fighter")).strip_edges()
	if name_s == "":
		name_s = "Custom Fighter"
	var id_s: String = str(raw.get("id", "")).strip_edges()
	if id_s == "":
		id_s = sanitize_id(name_s)
	else:
		id_s = sanitize_id(id_s)

	var ctype_i: int = int(raw.get("class_type", int(CharacterData.ClassType.HEAVY)))
	if ctype_i < 1 or ctype_i > 4:
		ctype_i = int(CharacterData.ClassType.HEAVY)

	var tier_id: String = str(raw.get("point_tier", "veteran"))
	var budget: int = get_tier_points(tier_id)
	var b_hp: int = clampi(int(raw.get("bonus_hp", 0)), 0, budget)
	var b_sp: int = clampi(int(raw.get("bonus_sp", 0)), 0, budget - b_hp)
	var is_sandbox: bool = bool(raw.get("is_sandbox", false))

	var clean_cards: Array[String] = []
	var raw_cards: Variant = raw.get("deck_cards", [])
	if raw_cards is Array:
		for item: Variant in raw_cards:
			var s: String = str(item)
			if s != "" and s not in clean_cards and clean_cards.size() < ClassFactory.HAND_LIMIT:
				clean_cards.append(s)

	return {
		"id": id_s,
		"name": name_s,
		"class_type": ctype_i,
		"point_tier": tier_id,
		"bonus_hp": b_hp,
		"bonus_sp": b_sp,
		"is_sandbox": is_sandbox,
		"deck_cards": clean_cards,
	}
