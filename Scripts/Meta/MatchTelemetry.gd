class_name MatchTelemetry
extends RefCounted
## Live per-match, per-run, and career combat telemetry collector.
## Subscribes to GameManager signals during real gameplay matches (skips headless runners, trials, and tutorials).

const MAX_MATCH_HISTORY: int = 30
const AchievementManagerScript = preload("res://Scripts/Meta/AchievementManager.gd")
const RunSaveManagerScript = preload("res://Scripts/RunSaveManager.gd")

var _bound: bool = false
var _tracking_active: bool = false
var _local_player_id: int = 1
var _current_match: Dictionary = {}
var _used_super_this_clash: bool = false
var _current_combo_streak: int = 0
var _enabled_in_headless_tests: bool = false


static func new_stats_bucket() -> Dictionary:
	return {
		"matches": 0,
		"wins": 0,
		"losses": 0,
		"clashes": 0,
		"damage_dealt": 0,
		"damage_taken": 0,
		"parries": 0,
		"dodges": 0,
		"reversals": 0,
		"guard_breaks": 0,
		"wall_crushes_inflicted": 0,
		"wall_crushes_suffered": 0,
		"supers_used": 0,
		"super_finishes": 0,
		"flawless_wins": 0,
		"max_combo": 0,
		"highest_league": 0,
		"leagues_won": 0,
		"clean_wall_leagues": 0,
		"double_boss_wins": 0,
		"rival_wins": 0,
		"wins_by_class": {},
		"league_wins_by_class": {},
		"cards_played": {},
	}


static func merge_into(target: Dictionary, delta: Dictionary) -> void:
	for key: String in [
		"matches", "wins", "losses", "clashes", "damage_dealt", "damage_taken",
		"parries", "dodges", "reversals", "guard_breaks",
		"wall_crushes_inflicted", "wall_crushes_suffered",
		"supers_used", "super_finishes", "flawless_wins",
		"leagues_won", "clean_wall_leagues", "double_boss_wins", "rival_wins",
	]:
		target[key] = int(target.get(key, 0)) + int(delta.get(key, 0))

	target["max_combo"] = maxi(int(target.get("max_combo", 0)), int(delta.get("max_combo", 0)))
	target["highest_league"] = maxi(int(target.get("highest_league", 0)), int(delta.get("highest_league", 0)))

	for map_key: String in ["wins_by_class", "league_wins_by_class", "cards_played"]:
		var src_map: Variant = delta.get(map_key, {})
		if src_map is Dictionary:
			if not (target.get(map_key) is Dictionary):
				target[map_key] = {}
			var dst_map: Dictionary = target[map_key] as Dictionary
			for k: Variant in (src_map as Dictionary).keys():
				var ks: String = str(k)
				dst_map[ks] = int(dst_map.get(ks, 0)) + int((src_map as Dictionary)[k])


static func get_top_card(cards_played: Dictionary) -> String:
	var best_name: String = "—"
	var best_count: int = 0
	for k: Variant in cards_played.keys():
		var cnt: int = int(cards_played[k])
		if cnt > best_count:
			best_count = cnt
			best_name = str(k)
	if best_count > 0:
		return "%s (%d×)" % [best_name, best_count]
	return best_name


static func format_summary_bbcode(stats: Dictionary, is_run_summary: bool = false) -> String:
	var clashes: int = int(stats.get("clashes", 0))
	var dealt: int = int(stats.get("damage_dealt", 0))
	var taken: int = int(stats.get("damage_taken", 0))
	var parries: int = int(stats.get("parries", 0))
	var dodges: int = int(stats.get("dodges", 0))
	var reversals: int = int(stats.get("reversals", 0))
	var gbs: int = int(stats.get("guard_breaks", 0))
	var wc_inf: int = int(stats.get("wall_crushes_inflicted", 0))
	var wc_suf: int = int(stats.get("wall_crushes_suffered", 0))
	var max_c: int = int(stats.get("max_combo", 0))
	var cards_map: Dictionary = stats.get("cards_played", {}) as Dictionary if stats.get("cards_played") is Dictionary else {}
	var top_card: String = get_top_card(cards_map)

	var lines: Array[String] = []
	if is_run_summary:
		var fights_won: int = int(stats.get("wins", 0))
		lines.append("[b][color=#ffd966]RUN SUMMARY[/color][/b]  ·  Fights Won: [b]%d[/b]  ·  Clashes: [b]%d[/b]" % [fights_won, clashes])
	else:
		lines.append("[b][color=#7fd8ff]MATCH SUMMARY[/color][/b]  ·  Clashes: [b]%d[/b]  ·  Best Combo: [b]%d[/b]" % [clashes, max_c])

	lines.append("Damage Dealt: [color=#ff8866][b]%d[/b][/color]   |   Damage Taken: [color=#ff5555][b]%d[/b][/color]" % [dealt, taken])
	lines.append("Parries: [b]%d[/b]   ·   Dodges: [b]%d[/b]   ·   Reversals: [b]%d[/b]   ·   Guard Breaks: [b]%d[/b]" % [parries, dodges, reversals, gbs])
	lines.append("Wall Crushes: [b]%d[/b] inflicted / [b]%d[/b] suffered   ·   Top Card: [color=#ffe066]%s[/color]" % [wc_inf, wc_suf, top_card])
	return "\n".join(lines)


func bind_signals() -> void:
	if _bound:
		return
	if not GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.connect(_on_state_changed)
	if not GameManager.clash_resolved.is_connected(_on_clash_resolved):
		GameManager.clash_resolved.connect(_on_clash_resolved)
	if not GameManager.damage_dealt.is_connected(_on_damage_dealt):
		GameManager.damage_dealt.connect(_on_damage_dealt)
	if not GameManager.wall_crush_occurred.is_connected(_on_wall_crush):
		GameManager.wall_crush_occurred.connect(_on_wall_crush)
	if not GameManager.combat_callout.is_connected(_on_combat_callout):
		GameManager.combat_callout.connect(_on_combat_callout)
	if not GameManager.game_over.is_connected(_on_game_over):
		GameManager.game_over.connect(_on_game_over)
	_bound = true


func reset_match_tracking(local_player_id: int = 1) -> void:
	_local_player_id = local_player_id
	_current_match = new_stats_bucket()
	_used_super_this_clash = false
	_current_combo_streak = 0
	_tracking_active = _should_track_current_match()


func _should_track_current_match() -> bool:
	if not _enabled_in_headless_tests and DisplayServer.get_name() == "headless":
		return false
	if OS.get_cmdline_args().has("--server"):
		return false
	if TutorialManager.is_tutorial_active or TrialManager.is_trial_active:
		return false
	return true


func _on_state_changed(new_state: GameManager.State) -> void:
	if new_state == GameManager.State.SETUP:
		var local_id: int = 1
		if GameManager.multiplayer.has_multiplayer_peer() and not GameManager.multiplayer.get_peers().is_empty():
			if GameManager.multiplayer.get_unique_id() == GameManager.p2_network_id:
				local_id = 2
		reset_match_tracking(local_id)


func _on_clash_resolved(_winner_id: int, p1_card: ActionData, p2_card: ActionData, _results: Dictionary) -> void:
	if not _tracking_active:
		return
	_current_match["clashes"] = int(_current_match["clashes"]) + 1
	var my_card: ActionData = p1_card if _local_player_id == 1 else p2_card
	_used_super_this_clash = false
	if my_card != null:
		var cname: String = my_card.display_name
		var cards_map: Dictionary = _current_match["cards_played"] as Dictionary
		cards_map[cname] = int(cards_map.get(cname, 0)) + 1
		if my_card.is_super:
			_current_match["supers_used"] = int(_current_match["supers_used"]) + 1
			_used_super_this_clash = true
		if my_card.type == ActionData.Type.OFFENCE:
			_current_combo_streak += maxi(1, my_card.repeat_count)
			_current_match["max_combo"] = maxi(int(_current_match["max_combo"]), _current_combo_streak)
		else:
			_current_combo_streak = 0


func _on_damage_dealt(target_id: int, amount: int, is_blocked: bool) -> void:
	if not _tracking_active or is_blocked or amount <= 0:
		return
	if target_id == _local_player_id:
		_current_match["damage_taken"] = int(_current_match["damage_taken"]) + amount
	else:
		_current_match["damage_dealt"] = int(_current_match["damage_dealt"]) + amount


func _on_wall_crush(player_id: int, _dmg: int) -> void:
	if not _tracking_active:
		return
	if player_id == _local_player_id:
		_current_match["wall_crushes_suffered"] = int(_current_match["wall_crushes_suffered"]) + 1
	else:
		_current_match["wall_crushes_inflicted"] = int(_current_match["wall_crushes_inflicted"]) + 1


func _on_combat_callout(target_id: int, text: String, _color: Color) -> void:
	if not _tracking_active:
		return
	if target_id == _local_player_id:
		if text == "PARRIED!":
			_current_match["parries"] = int(_current_match["parries"]) + 1
		elif text == "DODGED!":
			_current_match["dodges"] = int(_current_match["dodges"]) + 1
		elif text == "REVERSAL!":
			_current_match["reversals"] = int(_current_match["reversals"]) + 1
	else:
		if text == "GUARD BREAK!":
			_current_match["guard_breaks"] = int(_current_match["guard_breaks"]) + 1


func _on_game_over(winner_id: int) -> void:
	if not _tracking_active:
		return
	_tracking_active = false

	var local_won: bool = (winner_id == _local_player_id)
	_current_match["matches"] = 1
	_current_match["wins"] = 1 if local_won else 0
	_current_match["losses"] = 0 if local_won else 1

	var my_data: CharacterData = GameManager.p1_data if _local_player_id == 1 else GameManager.p2_data
	var opp_data: CharacterData = GameManager.p2_data if _local_player_id == 1 else GameManager.p1_data
	var my_class: String = ClassFactory.class_enum_to_string(my_data.class_type) if my_data != null else "Unknown"
	var opp_class: String = ClassFactory.class_enum_to_string(opp_data.class_type) if opp_data != null else "Unknown"

	if local_won:
		var wbc: Dictionary = _current_match["wins_by_class"] as Dictionary
		wbc[my_class] = int(wbc.get(my_class, 0)) + 1
		if int(_current_match["damage_taken"]) == 0:
			_current_match["flawless_wins"] = 1
		if _used_super_this_clash:
			_current_match["super_finishes"] = 1
		if RunManager.is_arcade_mode:
			if RunManager.is_rival_match:
				_current_match["rival_wins"] = 1
			if RunManager.is_boss_match and opp_data != null:
				var boss_mod_count: int = 0
				for eq: EquipmentData in opp_data.equipment:
					if eq != null and eq.get("boss_epithet") != null and str(eq.get("boss_epithet")) != "":
						boss_mod_count += 1
				if boss_mod_count >= 2:
					_current_match["double_boss_wins"] = 1

	# Snapshot for GameOverScreen
	RunManager.last_match_summary = _current_match.duplicate(true)

	# Roll into active Circuit run stats
	if RunManager.is_arcade_mode:
		if RunManager.run_stats.is_empty():
			RunManager.run_stats = new_stats_bucket()
		merge_into(RunManager.run_stats, _current_match)
		if not local_won:
			RunManager.last_run_summary = RunManager.run_stats.duplicate(true)

	# Roll into persistent career_stats & match_history
	var meta: GlobalSaveData = RunManager.meta_data
	if meta != null:
		if meta.career_stats.is_empty():
			meta.career_stats = new_stats_bucket()
		merge_into(meta.career_stats, _current_match)

		var mode_str: String = "Quick Match"
		if RunManager.is_arcade_mode:
			mode_str = "The Circuit"
		elif GameManager.multiplayer.has_multiplayer_peer() and not GameManager.multiplayer.get_peers().is_empty():
			mode_str = "Online"
		elif GameManager.p2_is_custom:
			mode_str = "Local 2P"

		var history_entry: Dictionary = {
			"timestamp": Time.get_datetime_string_from_system(false, true),
			"mode": mode_str,
			"result": "WIN" if local_won else "LOSS",
			"fighter": my_data.character_name if my_data != null else "Fighter",
			"fighter_class": my_class,
			"opponent": opp_data.character_name if opp_data != null else "Opponent",
			"opponent_class": opp_class,
			"clashes": int(_current_match["clashes"]),
			"damage_dealt": int(_current_match["damage_dealt"]),
			"damage_taken": int(_current_match["damage_taken"]),
			"parries": int(_current_match["parries"]),
			"top_card": get_top_card(_current_match["cards_played"] as Dictionary),
			"league": RunManager.leagues_completed + 1 if RunManager.is_arcade_mode else 0,
		}
		meta.match_history.push_front(history_entry)
		while meta.match_history.size() > MAX_MATCH_HISTORY:
			meta.match_history.pop_back()

		RunSaveManagerScript.save_global_save(meta)
		RunManager.last_unlocked_achievements = AchievementManagerScript.evaluate(RunManager, meta)
