extends Node

## Headless Combat & Regression Test Suite for CLASH.
## Run via:
##   Godot_console.exe --headless --path <project> res://Scenes/Tests/CombatRegressionSuite.tscn

var _passed: int = 0
var _failed: int = 0
var _match_ended: bool = false
var _match_winner: int = 0

var _saved_tokens: int = 0
var _saved_completed: Array[String] = []


func _ready() -> void:
	if RunManager.meta_data != null:
		_saved_tokens = RunManager.meta_data.circuit_tokens
		_saved_completed = RunManager.meta_data.completed_trials.duplicate()

	GameManager.game_over.connect(func(w: int) -> void:
		_match_ended = true
		_match_winner = w
	)

	print("\n============================================================")
	print("  CLASH AUTOMATED COMBAT & REGRESSION TEST SUITE")
	print("============================================================")

	_test_block_and_sp_recovery()
	_test_guard_break_ignores_block()
	_test_dodge_success_and_failure()
	_test_parry_success_and_failure()
	_test_reversal_steals_offence()
	_test_initial_clash_priority_and_tie()
	_test_wall_crush_sp_and_hp_overflow()
	_test_feint_combine_and_skip_live_path()
	_test_multi_lock_and_cost_cap()
	_test_repeat_sp_scaling()
	_test_opening_and_opportunity()
	_test_injured_tick_and_cure()
	_test_retaliate_current_clash()
	_test_tiring_normal_vs_heavy()
	_test_class_passives_all_four()
	_test_super_one_use_per_match()
	_test_equipment_and_sponsor_modifiers()
	_test_run_save_load_roundtrip()
	_test_all_28_dojo_trials()

	# Restore user's meta save data cleanly
	TrialManager.clear_active_trial()
	RunManager.is_arcade_mode = false
	RunManager.active_sponsor = null
	RunManager.active_gym_buff = ""
	RunManager.next_fight_statuses.clear()
	if RunManager.meta_data != null:
		RunManager.meta_data.circuit_tokens = _saved_tokens
		RunManager.meta_data.completed_trials = _saved_completed
		RunManager._save_global_data()

	print("============================================================")
	print("  SUITE SUMMARY: %d PASSED / %d FAILED" % [_passed, _failed])
	print("============================================================\n")
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("--quit-after-tests"):
		get_tree().quit(0 if _failed == 0 else 1)


#region Assertion Helpers

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		printerr("  [FAIL] ", label, (" — " + detail) if detail != "" else "")


func _action(card_name: String) -> ActionData:
	var a: ActionData = ClassFactory.find_action_resource(card_name)
	if a == null:
		for b: ActionData in ClassFactory.get_basic_actions():
			if b.display_name.to_lower() == card_name.to_lower():
				a = b
				break
	assert(a != null, "Missing test action: " + card_name)
	return a.duplicate(true) as ActionData


func _setup_match(
	p1_class: CharacterData.ClassType = CharacterData.ClassType.NONE,
	p1_hp: int = 10,
	p1_sp: int = 5,
	p2_class: CharacterData.ClassType = CharacterData.ClassType.NONE,
	p2_hp: int = 10,
	p2_sp: int = 5,
	start_mom: int = 0,
	combo_attacker: int = 0,
	priority_p: int = 1
) -> void:
	TrialManager.clear_active_trial()
	RunManager.is_arcade_mode = false
	RunManager.active_sponsor = null
	RunManager.active_gym_buff = ""
	RunManager.next_fight_statuses.clear()

	var p1: CharacterData = _make_fighter("P1", p1_class, p1_hp, p1_sp)
	var p2: CharacterData = _make_fighter("P2", p2_class, p2_hp, p2_sp)
	GameManager.p1_data = p1
	GameManager.p2_data = p2
	GameManager.apply_environment_rules("Dojo")
	GameManager.reset_combat()
	p1.max_hp = p1_hp
	p1.current_hp = p1_hp
	p1.max_sp = p1_sp
	p1.current_sp = p1_sp
	p2.max_hp = p2_hp
	p2.current_hp = p2_hp
	p2.max_sp = p2_sp
	p2.current_sp = p2_sp
	GameManager.state.momentum = start_mom
	GameManager.state.current_combo_attacker = combo_attacker
	GameManager.state.priority_player = priority_p
	_match_ended = false
	_match_winner = 0


func _make_fighter(n: String, ctype: CharacterData.ClassType, hp: int, sp: int) -> CharacterData:
	var c: CharacterData
	if ctype != CharacterData.ClassType.NONE and ClassFactory.class_registry.has(ctype):
		c = ClassFactory.create_character(ctype, n)
	else:
		c = CharacterData.new()
		c.character_name = n
		c.class_type = ctype
	c.max_hp = hp
	c.current_hp = hp
	c.max_sp = sp
	c.current_sp = sp
	return c


func _clash(
	p1_card: ActionData,
	p2_card: ActionData,
	p1_extra: Dictionary = {},
	p2_extra: Dictionary = {},
	p1_feint: ActionData = null
) -> void:
	_match_ended = false
	_match_winner = 0
	GameManager.current_state = GameManager.State.SELECTION
	GameManager.player_select_action(1, p1_card, p1_extra)
	GameManager.state.p2_action_queue = p2_card
	GameManager.state.p2_rage_active = bool(p2_extra.get("rage", false))
	GameManager.state.p2_keep_up_active = bool(p2_extra.get("keep_up", false))
	if GameManager.state.p1_action_queue != null and GameManager.state.p1_action_queue.feint:
		GameManager.current_state = GameManager.State.FEINT_CHECK
		GameManager.state.p1_pending_feint = true
		GameManager.player_select_action(1, p1_feint, {})
	else:
		GameManager.resolve_clash()

#endregion


#region Core Mechanic Tests

func _test_block_and_sp_recovery() -> void:
	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.NONE, 10, 5, 5, 2)
	GameManager.p1_data.current_sp = 1
	_clash(_action("Basic Block"), _action("Basic Light"))
	_check("Block stops 1 dmg & recovers +2 SP", GameManager.p1_data.current_hp == 5 and GameManager.p1_data.current_sp == 3,
		"hp=%d sp=%d" % [GameManager.p1_data.current_hp, GameManager.p1_data.current_sp])


func _test_guard_break_ignores_block() -> void:
	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.NONE, 5, 5, 3, 1)
	_clash(_action("Basic Technical"), _action("Perfect Block"))
	_check("Guard Break bypasses Block 4", GameManager.p2_data.current_hp == 4, "p2_hp=%d" % GameManager.p2_data.current_hp)


func _test_dodge_success_and_failure() -> void:
	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.NONE, 5, 5, 5, 2)
	_clash(_action("Basic Dodge"), _action("Basic Technical"))
	_check("Dodge 2 nullifies Cost 2 Guard Break + Tiring",
		GameManager.p1_data.current_hp == 5 and GameManager.p1_data.current_sp == 4 and GameManager.state.momentum == 5,
		"hp=%d sp=%d mom=%d" % [GameManager.p1_data.current_hp, GameManager.p1_data.current_sp, GameManager.state.momentum])

	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.NONE, 5, 5, 5, 2)
	_clash(_action("Basic Dodge"), _action("Basic Heavy"))
	_check("Dodge 2 fails against Cost 3 Heavy", GameManager.p1_data.current_hp == 2, "hp=%d" % GameManager.p1_data.current_hp)


func _test_parry_success_and_failure() -> void:
	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.NONE, 5, 5, 5, 2)
	_clash(_action("Basic Parry"), _action("Basic Heavy"))
	_check("Parry succeeds vs Mom 3 (0 dmg, Mom 5->4, p2_must_opener)",
		GameManager.p1_data.current_hp == 5 and GameManager.state.momentum == 4 and GameManager.state.p2_must_opener,
		"hp=%d mom=%d must_opener=%s" % [GameManager.p1_data.current_hp, GameManager.state.momentum, str(GameManager.state.p2_must_opener)])

	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.NONE, 5, 5, 5, 2)
	_clash(_action("Basic Parry"), _action("Lariat"))
	_check("Parry fails vs Mom 2 (Mom == Fall Back 2 -> takes 3 dmg)",
		GameManager.p1_data.current_hp == 2 and not GameManager.state.p2_must_opener,
		"hp=%d must_opener=%s" % [GameManager.p1_data.current_hp, str(GameManager.state.p2_must_opener)])


func _test_reversal_steals_offence() -> void:
	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.NONE, 5, 5, 6, 2)
	_clash(_action("Basic Reversal"), _action("Basic Positioning"))
	_check("Reversal flips attacker to P1 on Fall Back", GameManager.get_attacker() == 1 and GameManager.state.momentum == 5,
		"attacker=%d mom=%d" % [GameManager.get_attacker(), GameManager.state.momentum])


func _test_initial_clash_priority_and_tie() -> void:
	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.NONE, 5, 5, 0, 0, 2)
	_clash(_action("Basic Light"), _action("Haymaker"))
	_check("Initial Clash: lower Cost (1) beats higher Cost (3) despite P2 priority",
		GameManager.get_attacker() == 1 and GameManager.state.momentum == 4,
		"attacker=%d mom=%d" % [GameManager.get_attacker(), GameManager.state.momentum])

	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.NONE, 5, 5, 0, 0, 2)
	_clash(_action("Basic Light"), _action("Basic Light"))
	_check("Initial Clash tie: Priority Token awards P2 & swaps to P1",
		GameManager.get_attacker() == 2 and GameManager.state.priority_player == 1,
		"attacker=%d prio=%d" % [GameManager.get_attacker(), GameManager.state.priority_player])


func _test_wall_crush_sp_and_hp_overflow() -> void:
	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.NONE, 5, 5, 8, 2)
	GameManager.p1_data.current_sp = 0
	# Def +1 SP in Phase 1 -> 1 SP, then Wall Crush (Fall Back 2) drains 1 SP + 1 HP
	_clash(_action("Basic Parry"), _action("Haymaker"))
	_check("Wall Crush overflows SP into HP at Mom 8",
		GameManager.p1_data.current_sp == 0 and GameManager.p1_data.current_hp == 4,
		"hp=%d sp=%d" % [GameManager.p1_data.current_hp, GameManager.p1_data.current_sp])


func _test_feint_combine_and_skip_live_path() -> void:
	_setup_match(CharacterData.ClassType.NONE, 1, 4, CharacterData.ClassType.NONE, 1, 4, 5, 2)
	_clash(_action("Wind up"), _action("Basic Light"), {}, {}, _action("Quick Dodge"))
	_check("Feint combine via player_select_action dodges Light & KOs Sensei",
		GameManager.p1_data.current_hp == 1 and GameManager.p2_data.current_hp <= 0,
		"p1_hp=%d p2_hp=%d" % [GameManager.p1_data.current_hp, GameManager.p2_data.current_hp])

	_setup_match(CharacterData.ClassType.NONE, 5, 4, CharacterData.ClassType.NONE, 5, 4, 5, 2)
	_clash(_action("Wind up"), _action("Basic Light"), {}, {}, null)
	_check("Skip Feint via player_select_action(null) preserves base Wind up (1 dmg dealt, 1 taken)",
		GameManager.p1_data.current_hp == 4 and GameManager.p2_data.current_hp == 4,
		"p1_hp=%d p2_hp=%d" % [GameManager.p1_data.current_hp, GameManager.p2_data.current_hp])


func _test_multi_lock_and_cost_cap() -> void:
	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.NONE, 5, 5, 0, 0, 1)
	_clash(_action("Grab"), _action("Basic Reversal"))
	_check("Multi 2 locks opponent card & caps P1 next cost to 2",
		GameManager.state.p2_locked_card != null and GameManager.state.p2_locked_card.display_name == "Basic Reversal" and GameManager.state.p1_cost_limit == 2,
		"locked=%s limit=%d" % [str(GameManager.state.p2_locked_card), GameManager.state.p1_cost_limit])


func _test_repeat_sp_scaling() -> void:
	_setup_match(CharacterData.ClassType.NONE, 5, 2, CharacterData.ClassType.NONE, 5, 5, 3, 1)
	_clash(_action("Roll Punch"), _action("Basic Reversal"))
	_check("Repeat 3 with 2 SP executes 2 hits (2 dmg, 0 SP left)",
		GameManager.p2_data.current_hp == 3 and GameManager.p1_data.current_sp == 0,
		"p2_hp=%d p1_sp=%d" % [GameManager.p2_data.current_hp, GameManager.p1_data.current_sp])


func _test_opening_and_opportunity() -> void:
	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.NONE, 5, 5, 5, 2)
	_clash(_action("Resounding Parry"), _action("Basic Heavy"))
	_check("Create Opening 2 sets p1_opening_stat = 2", GameManager.state.p1_opening_stat == 2, "opening=%d" % GameManager.state.p1_opening_stat)

	_setup_match(CharacterData.ClassType.NONE, 5, 1, CharacterData.ClassType.NONE, 5, 0, 5, 0)
	_clash(_action("Push Kick"), _action("Basic Positioning"))
	_check("Opportunity 1 granted by Push Kick", GameManager.state.p1_opportunity_stat == 1, "opp=%d" % GameManager.state.p1_opportunity_stat)
	_clash(_action("Drop Kick"), _action("Basic Block"))
	_check("Opportunity 1 discounts Drop Kick (2->1 SP) and lands 3 dmg",
		GameManager.p1_data.current_sp == 0 and GameManager.p2_data.current_hp == 2,
		"p1_sp=%d p2_hp=%d" % [GameManager.p1_data.current_sp, GameManager.p2_data.current_hp])


func _test_injured_tick_and_cure() -> void:
	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.NONE, 5, 5, 3, 1)
	_clash(_action("Twist Arm"), _action("Perfect Block"))
	_check("Injured applied through Block without ticking on application clash",
		GameManager.has_status(2, "Injured") and GameManager.p2_data.current_hp == 5,
		"has_inj=%s p2_hp=%d" % [str(GameManager.has_status(2, "Injured")), GameManager.p2_data.current_hp])
	_clash(_action("Basic Light"), _action("Perfect Block"))
	_check("Injured ticks for 1 HP on subsequent clash", GameManager.p2_data.current_hp == 4, "p2_hp=%d" % GameManager.p2_data.current_hp)
	_clash(_action("Basic Light"), _action("Basic Parry"))
	_check("Fall Back cures Injured cleanly", not GameManager.has_status(2, "Injured"), "still_injured")


func _test_retaliate_current_clash() -> void:
	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.NONE, 5, 5, 5, 2)
	_clash(_action("Redirect"), _action("Lariat"))
	_check("Retaliate reflects Lariat's 3 dmg in current clash",
		GameManager.p2_data.current_hp == 2 and GameManager.p1_data.current_hp == 2,
		"p1_hp=%d p2_hp=%d" % [GameManager.p1_data.current_hp, GameManager.p2_data.current_hp])


func _test_tiring_normal_vs_heavy() -> void:
	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.QUICK, 5, 0, 3, 1)
	_clash(_action("Headbutt"), _action("Adept Block"))
	_check("Tiring drains SP only on non-Heavy fighter (clamps at 0 SP, 0 HP loss)",
		GameManager.p2_data.current_sp == 0 and GameManager.p2_data.current_hp == 5,
		"p2_hp=%d p2_sp=%d" % [GameManager.p2_data.current_hp, GameManager.p2_data.current_sp])

	_setup_match(CharacterData.ClassType.NONE, 5, 5, CharacterData.ClassType.HEAVY, 5, 4, 3, 1)
	GameManager.p2_data.current_sp = 0
	_clash(_action("Headbutt"), _action("Adept Block"))
	_check("Tiring overflows into HP damage on Heavy fighter at low SP",
		GameManager.p2_data.current_sp == 0 and GameManager.p2_data.current_hp == 4,
		"p2_hp=%d p2_sp=%d" % [GameManager.p2_data.current_hp, GameManager.p2_data.current_sp])


func _test_class_passives_all_four() -> void:
	# Heavy Rage
	_setup_match(CharacterData.ClassType.HEAVY, 4, 0, CharacterData.ClassType.NONE, 3, 0, 3, 1)
	_clash(_action("Drop Kick"), _action("Basic Block"), { "rage": true })
	_check("Heavy Passive (Rage): pays 2 HP at 0 SP and lands lethal 3 dmg",
		GameManager.p1_data.current_hp == 2 and GameManager.p2_data.current_hp <= 0,
		"p1_hp=%d p2_hp=%d" % [GameManager.p1_data.current_hp, GameManager.p2_data.current_hp])

	# Patient Bide
	_setup_match(CharacterData.ClassType.PATIENT, 5, 4, CharacterData.ClassType.NONE, 2, 4, 4, 2)
	GameManager.p1_data.current_sp = 2
	GameManager.p2_data.current_sp = 1
	_clash(_action("Active Block"), _action("Basic Light"))
	_check("Patient Passive (Bide): Fall Back arms patient_buff_active", GameManager.p1_data.patient_buff_active)
	_clash(_action("Haymaker"), _action("Basic Block"))
	_check("Patient Passive (Bide): adds +1 Dmg to next action for lethal KO",
		GameManager.p2_data.current_hp <= 0 and not GameManager.p1_data.patient_buff_active)

	# Quick Relentless
	_setup_match(CharacterData.ClassType.QUICK, 5, 3, CharacterData.ClassType.NONE, 5, 0, 3, 1)
	_clash(_action("Roll Punch"), _action("Basic Reversal"))
	_check("Quick Passive (Relentless): 3-hit Repeat refunds +1 SP and keeps combo alive",
		GameManager.p1_data.current_sp == 1 and GameManager.state.current_combo_attacker == 1,
		"sp=%d combo=%d" % [GameManager.p1_data.current_sp, GameManager.state.current_combo_attacker])

	# Technical Custom Technique (+Opener)
	_setup_match(CharacterData.ClassType.TECHNICAL, 5, 4, CharacterData.ClassType.NONE, 1, 4, 0, 0, 1)
	_clash(_action("Basic Technical"), _action("Perfect Block"), { "technique": 1 })
	_check("Technical Passive (Custom Technique +Opener): costs +1 SP and KOs through Block",
		GameManager.p1_data.current_sp == 1 and GameManager.p2_data.current_hp <= 0,
		"sp=%d p2_hp=%d" % [GameManager.p1_data.current_sp, GameManager.p2_data.current_hp])


func _test_super_one_use_per_match() -> void:
	_setup_match(CharacterData.ClassType.NONE, 6, 6, CharacterData.ClassType.NONE, 10, 4, 1, 1)
	_clash(_action("Vital Point Assault"), _action("Perfect Block"))
	_check("Super marks has_used_super = true and deals Repeat Guard Break dmg",
		GameManager.p1_data.has_used_super and GameManager.p2_data.current_hp == 4,
		"used=%s p2_hp=%d" % [str(GameManager.p1_data.has_used_super), GameManager.p2_data.current_hp])


func _test_equipment_and_sponsor_modifiers() -> void:
	var p1: CharacterData = _make_fighter("P1", CharacterData.ClassType.NONE, 6, 5)
	var p2: CharacterData = _make_fighter("P2", CharacterData.ClassType.NONE, 6, 5)
	var eq: EquipmentData = EquipmentData.new()
	eq.item_name = "Test Gloves"
	eq.damage_modifier = 2
	eq.starting_opportunity = 2
	p1.equipment.append(eq)

	GameManager.p1_data = p1
	GameManager.p2_data = p2
	GameManager.apply_environment_rules("Dojo")
	GameManager.reset_combat()

	_check("Equipment starting_opportunity applies in reset_combat()",
		GameManager.state.p1_opportunity_stat == 2, "opp=%d" % GameManager.state.p1_opportunity_stat)

	# Verify +damage_modifier does NOT turn 0-dmg Basic Positioning into an attack
	GameManager.state.momentum = 3
	GameManager.state.current_combo_attacker = 1
	_clash(_action("Basic Positioning"), _action("Basic Reversal"))
	_check("Equipment +damage_modifier does not add dmg to 0-dmg utility cards",
		GameManager.p2_data.current_hp == 6, "p2_hp=%d" % GameManager.p2_data.current_hp)


func _test_run_save_load_roundtrip() -> void:
	var test_name: String = "__regression_roundtrip_test"
	var test_file: String = test_name + ".tres"
	var p: CharacterData = ClassFactory.create_character(CharacterData.ClassType.HEAVY, test_name)
	var sponsor: SponsorData = load("res://Data/Sponsors/TitanDemolitions.tres") as SponsorData

	RunManager.current_run_name = test_name
	RunManager.current_level = 4
	RunManager.current_map_index = 3
	RunManager.leagues_completed = 2
	RunManager.current_rerolls = 5
	RunManager.active_gym_buff = "iron_stance"
	RunManager.next_fight_statuses = ["Injured"]
	RunManager.is_boss_match = true
	RunManager.is_rival_match = false
	RunManager.active_sponsor = sponsor
	RunManager.player_run_data = p
	RunManager.player_owned_tree_ids = [76, 66]
	RunManager.tournament_map = []
	RunManager.save_run()

	var loaded: RunSaveData = RunManager.peek_save_file(test_file)
	var ok: bool = (
		loaded != null
		and loaded.run_name == test_name
		and loaded.current_level == 4
		and loaded.leagues_completed == 2
		and loaded.current_rerolls == 5
		and loaded.active_gym_buff == "iron_stance"
		and loaded.next_fight_statuses.has("Injured")
		and loaded.is_boss_match
		and loaded.active_sponsor != null
		and loaded.active_sponsor.item_name == sponsor.item_name
	)
	_check("RunSaveData roundtrip preserves sponsor, league, rerolls, gym buff, statuses, boss flags", ok)
	RunManager.delete_save_file(test_file)

#endregion


#region All 28 Dojo Trials Verification

func _test_all_28_dojo_trials() -> void:
	var cases: Array[Dictionary] = [
		# Tier 1 (9)
		{ "id": "drill_block_vs_light", "win": [{"c": "Basic Block"}], "trap": [{"c": "Basic Parry"}] },
		{ "id": "drill_dodge_vs_guard_break", "win": [{"c": "Basic Dodge"}], "trap": [{"c": "Basic Block"}] },
		{ "id": "drill_parry_vs_heavy", "win": [{"c": "Basic Parry"}], "trap": [{"c": "Basic Block"}] },
		{ "id": "drill_reversal_vs_fallback", "win": [{"c": "Basic Reversal"}], "trap": [{"c": "Basic Block"}] },
		{ "id": "drill_combo_and_momentum_swap", "win": [{"c": "Basic Parry"}, {"c": "Basic Light"}], "trap": [{"c": "Basic Block"}, {"c": "Basic Block"}] },
		{ "id": "drill_initial_clash_priority", "win": [{"c": "Basic Light"}], "trap": [{"c": "Haymaker"}] },
		{ "id": "drill_guard_break_vs_block", "win": [{"c": "Basic Technical"}], "trap": [{"c": "Basic Heavy"}] },
		{ "id": "drill_wall_crush_danger", "win": [{"c": "Adept Block"}], "trap": [{"c": "Basic Parry"}] },
		{ "id": "drill_opening_and_counter", "win": [{"c": "Resounding Parry"}, {"c": "Resounding Counter"}], "trap": [{"c": "Basic Block"}, {"c": "Basic Block"}] },
		# Tier 2 (6)
		{ "id": "passive_heavy_rage", "win": [{"c": "Drop Kick", "e": {"rage": true}}], "trap": [{"c": "Basic Heavy", "e": {"rage": true}}] },
		{ "id": "passive_patient_bide", "win": [{"c": "Active Block"}, {"c": "Haymaker"}], "trap": [{"c": "Basic Block"}, {"c": "Basic Block"}] },
		{ "id": "passive_quick_relentless", "win": [{"c": "Roll Punch"}, {"c": "Basic Light"}], "trap": [{"c": "Basic Heavy"}, {"c": "Basic Light"}] },
		{ "id": "passive_technical_technique", "win": [{"c": "Basic Technical", "e": {"technique": 1}}], "trap": [{"c": "Basic Light"}] },
		{ "id": "hybrid_crushing_block", "win": [{"c": "Crushing Block"}], "trap": [{"c": "Basic Block"}] },
		{ "id": "hybrid_breakout", "win": [{"c": "Breakout"}], "trap": [{"c": "Basic Reversal"}] },
		# Tier 3 (13)
		{ "id": "puzzle_feint_combine", "win": [{"c": "Wind up", "feint": "Quick Dodge"}], "trap": [{"c": "Wind up", "feint": ""}] },
		{ "id": "puzzle_opportunity_tempo", "win": [{"c": "Push Kick"}, {"c": "Drop Kick"}], "trap": [{"c": "Basic Reversal"}, {"c": "Basic Light"}] },
		{ "id": "puzzle_grandmaster_exam", "win": [{"c": "Resounding Parry"}, {"c": "Resounding Counter"}, {"c": "Basic Technical", "e": {"technique": 1}}], "trap": [{"c": "Basic Block"}, {"c": "Basic Block"}, {"c": "Basic Block"}] },
		{ "id": "puzzle_drain_the_tank", "win": [{"c": "Headbutt"}, {"c": "Headbutt"}], "trap": [{"c": "Basic Light"}, {"c": "Basic Light"}] },
		{ "id": "puzzle_grapplers_trap", "win": [{"c": "Grab"}, {"c": "Throw"}], "trap": [{"c": "Haymaker"}, {"c": "Basic Light"}] },
		{ "id": "puzzle_retaliate_recoil", "win": [{"c": "Redirect"}], "trap": [{"c": "Crushing Block"}] },
		{ "id": "puzzle_wall_super_unlock", "win": [{"c": "Knee Crush"}, {"c": "Vital Point Assault"}], "trap": [{"c": "Basic Heavy"}, {"c": "Basic Heavy"}] },
		{ "id": "puzzle_feint_cure_injury", "win": [{"c": "Go with the Flow", "feint": "Basic Technical"}, {"c": "Perfect Strike"}], "trap": [{"c": "Basic Positioning"}, {"c": "Perfect Strike"}] },
		{ "id": "puzzle_bleeding_out", "win": [{"c": "Twist Arm"}, {"c": "Basic Technical"}], "trap": [{"c": "Basic Light"}, {"c": "Basic Light"}] },
		{ "id": "puzzle_stamina_choke", "win": [{"c": "Tiring Parry"}, {"c": "Basic Light"}], "trap": [{"c": "Basic Parry"}, {"c": "Basic Block"}] },
		{ "id": "puzzle_slip_and_strike", "win": [{"c": "Slip Behind"}, {"c": "Strike Back"}], "trap": [{"c": "Basic Dodge"}, {"c": "Basic Block"}] },
		{ "id": "puzzle_master_tech_chain", "win": [{"c": "Master Tech"}, {"c": "Drop Kick"}], "trap": [{"c": "Basic Technical"}, {"c": "Basic Technical"}] },
		{ "id": "puzzle_ten_hit_barrage", "win": [{"c": "Roll Punch"}, {"c": "Ultimate Barrage"}], "trap": [{"c": "Basic Heavy"}, {"c": "Ultimate Barrage"}] },
	]

	_check("Trial roster count matches test coverage (%d trials)" % TrialManager.get_all_trials().size(),
		TrialManager.get_all_trials().size() == cases.size())

	for tc: Dictionary in cases:
		var tid: String = str(tc["id"])
		var win_res: String = _run_trial_line(tid, tc["win"])
		var trap_res: String = _run_trial_line(tid, tc["trap"])
		_check("Dojo Trial '%s' (win=CLEARED, trap!=CLEARED)" % tid,
			win_res == "CLEARED" and trap_res != "CLEARED",
			"win=%s trap=%s" % [win_res, trap_res])


func _run_trial_line(trial_id: String, steps: Array) -> String:
	var t: TrialData = TrialManager.get_trial_by_id(trial_id)
	if t == null:
		return "MISSING_TRIAL"

	TrialManager.clear_active_trial()
	TrialManager.active_trial = t
	TrialManager.is_trial_active = true
	TrialManager.current_turn = 0
	TrialManager._reset_telemetry()
	TrialManager._bind_combat_signals()

	RunManager.is_arcade_mode = false
	RunManager.active_sponsor = null
	RunManager.active_gym_buff = ""

	var p1: CharacterData = TrialManager._build_trial_fighter(t.p1_name, t.p1_class, t.p1_max_hp, t.p1_start_hp, t.p1_max_sp, t.p1_start_sp, t.p1_card_names)
	var p2: CharacterData = TrialManager._build_trial_fighter(t.p2_name, t.p2_class, t.p2_max_hp, t.p2_start_hp, t.p2_max_sp, t.p2_start_sp, t.p2_card_names)

	GameManager.p1_data = p1
	GameManager.p2_data = p2
	GameManager.apply_environment_rules(t.environment)
	GameManager.reset_combat()
	TrialManager.apply_trial_initial_state()

	for step: Dictionary in steps:
		_match_ended = false
		_match_winner = 0
		GameManager.current_state = GameManager.State.SELECTION

		var p1_card: ActionData = _find_card(p1, str(step["c"]))
		var p2_card: ActionData = GameManager.state.p2_locked_card if GameManager.state.p2_locked_card != null else TrialManager.get_bot_card_for_turn(p2)
		var extra: Dictionary = step.get("e", {})
		if p1_card == null:
			return "MISSING_CARD:" + str(step["c"])

		var attacker_id: int = GameManager.get_attacker()
		var needs_opener: bool = (GameManager.state.momentum == 0 or (attacker_id == 1 and GameManager.state.current_combo_attacker == 0) or GameManager.state.p1_must_opener)
		var tech_idx: int = int(extra.get("technique", 0))
		var eff_opener: bool = p1_card.is_opener or (tech_idx == 1 and p1_card.type == ActionData.Type.OFFENCE)
		if attacker_id == 1 and p1_card.type != ActionData.Type.OFFENCE:
			return "ILLEGAL_NEED_OFFENCE"
		if attacker_id == 2 and p1_card.type != ActionData.Type.DEFENCE:
			return "ILLEGAL_NEED_DEFENCE"
		if needs_opener and p1_card.type == ActionData.Type.OFFENCE and not eff_opener:
			return "ILLEGAL_NEEDS_OPENER"
		if p1_card.counter_value > 0 and GameManager.state.p1_opening_stat < p1_card.counter_value:
			return "ILLEGAL_COUNTER_LOCKED"
		if p1_card.is_super and (GameManager.state.momentum != GameManager.get_wall_momentum(1) or p1.has_used_super):
			return "ILLEGAL_SUPER_LOCKED"
		if p1_card.cost > GameManager.state.p1_cost_limit:
			return "ILLEGAL_EXCEEDS_MULTI_LIMIT"
		var eff_cost: int = maxi(0, p1_card.cost + (1 if tech_idx > 0 else 0) - GameManager.state.p1_opportunity_stat)
		if p1.current_sp < eff_cost and not bool(extra.get("rage", false)):
			return "ILLEGAL_CANNOT_AFFORD"

		var feint_name: String = str(step.get("feint", ""))
		var fcard: ActionData = _find_card(p1, feint_name) if feint_name != "" else null
		_clash(p1_card, p2_card, extra, {}, fcard)

		var outcome: Dictionary = TrialManager.evaluate_trial_outcome(_match_ended, _match_winner)
		var status: String = str(outcome.get("status", "CONTINUE"))
		if status != "CONTINUE":
			return status

	return "DID_NOT_FINISH"


func _find_card(c: CharacterData, card_name: String) -> ActionData:
	for a: ActionData in c.deck:
		if a.display_name == card_name:
			return a
	return null

#endregion
