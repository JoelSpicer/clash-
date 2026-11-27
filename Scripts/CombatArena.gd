extends Node2D

const BotDecisionMakerScript = preload("res://Scripts/Battle/BotDecisionMaker.gd")
const CombatRulesScript = preload("res://Scripts/Battle/CombatRules.gd")

@export_group("Setup")
@export var p1_resource: CharacterData
@export var p2_resource: CharacterData
@export var stop_on_game_over: bool = true

@export_group("Debug Controls")
@export var is_player_1_human: bool = true
@export var is_player_2_human: bool = false
@export var p2_debug_force_card: ActionData

var local_player_id: int = 1
var server_received_inputs: Dictionary = {}

@onready var battle_ui: CanvasLayer = $BattleUI
@onready var tutorial_layer: Node = $"../TutorialLayer"

var _simulation_active: bool = true
var _current_input_player: int = 1


func _ready() -> void:
	# 1. Await a frame so BattleUI finishes its internal _ready
	await get_tree().process_frame

	var log_node: Node = battle_ui.get("combat_log") as Node
	if log_node and log_node.has_method("clear_log"):
		log_node.call("clear_log")

	# 2. Load Player Resources
	if GameManager.next_match_p1_data != null:
		p1_resource = GameManager.next_match_p1_data
	if GameManager.next_match_p2_data != null:
		p2_resource = GameManager.next_match_p2_data

	# 3. Determine Human/AI & Network Status
	is_player_1_human = true
	is_player_2_human = false
	local_player_id = 1

	var my_id: int = 1
	if multiplayer.has_multiplayer_peer():
		my_id = multiplayer.get_unique_id()

	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		is_player_2_human = true
		if my_id == GameManager.p1_network_id:
			local_player_id = 1
		elif my_id == GameManager.p2_network_id:
			local_player_id = 2
		else:
			local_player_id = 0 # Dedicated server Referee
	elif not RunManager.is_arcade_mode and GameManager.p2_is_custom:
		is_player_2_human = true

	# 4. Connect Core Signals
	if not GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.connect(_on_state_changed)
		GameManager.combat_log_updated.connect(_on_log_updated)
		GameManager.clash_resolved.connect(_on_clash_resolved)
		if DisplayServer.get_name() != "headless":
			GameManager.request_clash_animation.connect(Callable(battle_ui, "play_clash_animation"))

	if not battle_ui.is_connected("human_selected_card", _on_human_input_received):
		battle_ui.connect("human_selected_card", _on_human_input_received)
	if not battle_ui.is_connected("p1_mode_toggled", _on_p1_mode_toggled):
		battle_ui.connect("p1_mode_toggled", _on_p1_mode_toggled)
		battle_ui.connect("p2_mode_toggled", _on_p2_mode_toggled)

	# 5. Reset Match State FIRST so BattleUI snapshots true initial stats
	print("--- INITIALIZING MATCH ---")
	GameManager.p1_data = p1_resource
	GameManager.p2_data = p2_resource
	GameManager.reset_combat()

	if TrialManager.is_trial_active:
		TrialManager.apply_trial_initial_state()

	# 6. Initialize UI & HUD (single clean initialization pass)
	battle_ui.call("setup_match_ui", p1_resource, p2_resource, local_player_id)
	battle_ui.call("setup_toggles", is_player_1_human, is_player_2_human)
	if TrialManager.is_trial_active:
		battle_ui.call("setup_trial_ui")
	_update_visuals()
	if not GameManager.snapshot_applied.is_connected(_update_visuals):
		GameManager.snapshot_applied.connect(_update_visuals)

	# 7. Network Readiness Barrier
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		if multiplayer.is_server():
			NetworkManager.notify_server_arena_ready()
		else:
			print("Waiting for opponent to load the arena...")
			NetworkManager.rpc_id(1, "client_finished_loading")
	else:
		GameManager.change_state(GameManager.State.SELECTION)

	# 8. Difficulty Suffix for AI Fighters
	var diff_suffix: String = ""
	match GameManager.ai_difficulty:
		GameManager.Difficulty.VERY_EASY: diff_suffix = " (V)"
		GameManager.Difficulty.EASY: diff_suffix = " (E)"
		GameManager.Difficulty.MEDIUM: diff_suffix = " (M)"
		GameManager.Difficulty.HARD: diff_suffix = " (H)"

	if not is_player_1_human:
		var p1_hud: Node = battle_ui.get("p1_hud") as Node
		if p1_hud and p1_hud.get("name_label") != null:
			(p1_hud.get("name_label") as Label).text += diff_suffix

	if not is_player_2_human:
		var p2_hud: Node = battle_ui.get("p2_hud") as Node
		if p2_hud and p2_hud.get("name_label") != null:
			(p2_hud.get("name_label") as Label).text += diff_suffix


func _update_visuals() -> void:
	battle_ui.call("update_all_visuals", p1_resource, p2_resource, GameManager.state.momentum)


#region Debug Human/AI Toggle Logic

func _on_p1_mode_toggled(is_human: bool) -> void:
	is_player_1_human = is_human
	print("[DEBUG] P1 Human Mode: " + str(is_human))
	_check_mid_turn_state_change(1, is_human)


func _on_p2_mode_toggled(is_human: bool) -> void:
	is_player_2_human = is_human
	print("[DEBUG] P2 Human Mode: " + str(is_human))
	_check_mid_turn_state_change(2, is_human)


func _check_mid_turn_state_change(player_id: int, is_human: bool) -> void:
	if _current_input_player != player_id:
		return
	if GameManager.current_state != GameManager.State.SELECTION and GameManager.current_state != GameManager.State.FEINT_CHECK:
		return

	if not is_human:
		print(">>> TAKEOVER: Bot taking control of P" + str(player_id))
		battle_ui.call("lock_ui")
		_run_bot_turn(player_id)
	else:
		print(">>> TAKEOVER: Human taking control of P" + str(player_id))
		_prepare_human_turn(player_id)

#endregion

#region Game Loop & Input Funnel

func _on_state_changed(new_state: GameManager.State) -> void:
	if not _simulation_active:
		return

	match new_state:
		GameManager.State.SELECTION:
			await get_tree().create_timer(0.5).timeout
			if GameManager.current_state != GameManager.State.SELECTION:
				return
			_start_turn_sequence()
			if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
				_check_server_funnel()

		GameManager.State.FEINT_CHECK:
			await get_tree().create_timer(0.3).timeout
			if GameManager.current_state != GameManager.State.FEINT_CHECK:
				return
			print("| --- FEINT PHASE --- |")
			_start_feint_input()
			if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
				_check_server_funnel()

		GameManager.State.POST_CLASH:
			if TrialManager.is_trial_active:
				var outcome: Dictionary = TrialManager.evaluate_trial_outcome(false, 0)
				if str(outcome.get("status", "CONTINUE")) != "CONTINUE":
					_simulation_active = false
					battle_ui.call("lock_ui")
					battle_ui.call("show_trial_result", outcome)
					return
			if TutorialManager.is_tutorial_active:
				var tutorial_finished: bool = TutorialManager.advance_step()
				if tutorial_finished:
					_simulation_active = false
					battle_ui.call("lock_ui")
					_finish_tutorial_sequence()
					return
			_print_status_report()


func _finish_tutorial_sequence() -> void:
	await get_tree().create_timer(0.35).timeout
	var outro: Dictionary = TutorialManager.get_outro_data()
	tutorial_layer.call("show_message", str(outro.get("text", "Tutorial complete!")), null, str(outro.get("button", "Continue")), false)
	await tutorial_layer.tutorial_message_closed
	TutorialManager.end_tutorial()


func _start_turn_sequence() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		if local_player_id == 1 or local_player_id == 2:
			_prepare_human_turn(local_player_id)
	else:
		if is_player_1_human:
			_prepare_human_turn(1)
		else:
			print("\n| --- NEW TURN: AI P1 --- |")
			_run_bot_turn(1)


func _start_feint_input() -> void:
	if _is_online_match():
		if local_player_id == 1 and GameManager.state.p1_pending_feint:
			print("| --- WAITING FOR P1 FEINT SELECTION --- |")
			_prepare_human_turn(1)
		elif local_player_id == 2 and GameManager.state.p2_pending_feint:
			print("| --- WAITING FOR P2 FEINT SELECTION --- |")
			_prepare_human_turn(2)
		return

	if GameManager.state.p1_pending_feint:
		print("| --- WAITING FOR P1 FEINT SELECTION --- |")
		if is_player_1_human:
			_prepare_human_turn(1)
		else:
			_run_bot_turn(1)
	elif GameManager.state.p2_pending_feint:
		print("| --- WAITING FOR P2 FEINT SELECTION --- |")
		if is_player_2_human:
			_prepare_human_turn(2)
		else:
			_run_bot_turn(2)


func _get_player_constraints(player_id: int) -> Dictionary:
	return CombatRulesScript.get_player_constraints(player_id)


func _is_online_match() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0


func _is_local_hotseat() -> bool:
	return not _is_online_match() and is_player_1_human and is_player_2_human


func _prepare_human_turn(player_id: int) -> void:
	_current_input_player = player_id
	var character: CharacterData = p1_resource if player_id == 1 else p2_resource

	battle_ui.call("set_active_input_player", player_id, _is_local_hotseat())
	battle_ui.call("setup_passive_toggles", character)
	battle_ui.call("load_deck", character.deck)

	var locked_card: ActionData = GameManager.state.p1_locked_card if player_id == 1 else GameManager.state.p2_locked_card
	if locked_card and GameManager.current_state == GameManager.State.SELECTION:
		print(">>> P" + str(player_id) + " LOCKED into: " + locked_card.display_name)
		_on_human_input_received(locked_card)
		return

	var c: Dictionary = _get_player_constraints(player_id)
	var is_feinting: bool = (GameManager.current_state == GameManager.State.FEINT_CHECK)

	if is_feinting:
		print("[GUIDE P" + str(player_id) + "] Feint! Choose a card to combine, or 'SKIP FEINT'.")
	else:
		if c["required_tab"] == ActionData.Type.OFFENCE:
			print("[GUIDE P" + str(player_id) + "] Attack!")
		elif c["required_tab"] == ActionData.Type.DEFENCE:
			print("[GUIDE P" + str(player_id) + "] Defend!")
		else:
			print("[GUIDE P" + str(player_id) + "] Neutral.")

	_update_visuals()
	print("| --- WAITING FOR P" + str(player_id) + " INPUT --- |")

	var can_control_locally: bool = (player_id == local_player_id) if _is_online_match() else true
	if can_control_locally:
		battle_ui.call(
			"unlock_for_input",
			c["required_tab"],
			character.current_sp,
			character.current_hp,
			bool(c["needs_opener"]),
			int(c["max_cost"]),
			int(c["opening_stat"]),
			bool(c["can_use_super"]),
			int(c["opportunity_stat"]),
			is_feinting
		)

		await get_tree().process_frame
		await get_tree().process_frame

		if TrialManager.is_trial_active and player_id == 1:
			battle_ui.call("refresh_trial_banner")
			if TrialManager.current_turn == 0 and GameManager.current_state == GameManager.State.SELECTION:
				battle_ui.set("is_locked", true)
				await battle_ui.call("show_trial_briefing_and_wait")
				battle_ui.set("is_locked", false)

		if TutorialManager.is_tutorial_active and player_id == 1:
			battle_ui.set("is_locked", true)
			if TutorialManager.current_step == 0:
				await get_tree().create_timer(1.0).timeout
				await get_tree().process_frame
				await get_tree().process_frame

			var tut_data: Dictionary = TutorialManager.get_current_data()
			if tut_data.has("sensei_text"):
				var highlight_str: String = str(tut_data.get("highlight", ""))
				var highlight_node: Control = null

				if highlight_str == "hand":
					highlight_node = battle_ui.get("button_grid") as Control
				elif highlight_str == "momentum" or highlight_str == "wall":
					highlight_node = battle_ui.get("momentum_tracker") as Control
				elif highlight_str.begins_with("card:"):
					var target_card_name: String = highlight_str.replace("card:", "")
					highlight_node = _get_button_for_card(target_card_name)

				tutorial_layer.call("show_message", tut_data["sensei_text"], highlight_node)
				await tutorial_layer.tutorial_message_closed

			battle_ui.set("is_locked", false)
	else:
		battle_ui.call("lock_ui")
		print("Waiting for Opponent to choose...")


func _on_human_input_received(card: ActionData, extra_data: Dictionary = {}) -> void:
	var card_name: String = card.display_name if card != null else ""

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		server_receive_input.rpc_id(1, _current_input_player, card_name, extra_data)
	else:
		server_receive_input(_current_input_player, card_name, extra_data)


@rpc("any_peer", "call_local", "reliable")
func server_receive_input(player_id: int, card_name: String, extra_data: Dictionary) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# In online multiplayer, derive authoritative player_id from the RPC sender so peers cannot spoof inputs
	var auth_player_id: int = player_id
	if _is_online_match():
		var sender_id: int = multiplayer.get_remote_sender_id()
		if sender_id == GameManager.p1_network_id:
			auth_player_id = 1
		elif sender_id == GameManager.p2_network_id:
			auth_player_id = 2
		elif sender_id != 0:
			printerr("🚨 [SERVER FUNNEL] Rejected spoofed input from unknown peer ", sender_id)
			return

	if GameManager.current_state != GameManager.State.SELECTION and GameManager.current_state != GameManager.State.FEINT_CHECK:
		print("⚠️ [SERVER FUNNEL] Ignored out-of-phase input from P", auth_player_id, " during ", GameManager.State.keys()[GameManager.current_state])
		return

	var str_id: String = str(auth_player_id)
	server_received_inputs[str_id] = { "card": card_name, "extra": extra_data }
	print("📥 [SERVER FUNNEL] Received P", auth_player_id)

	_check_server_funnel()

	if not _is_online_match() and auth_player_id == 1:
		var needs_p2_selection: bool = (
			GameManager.current_state == GameManager.State.SELECTION
			and GameManager.state.p2_locked_card == null
			and not server_received_inputs.has("2")
		)
		var needs_p2_feint: bool = (
			GameManager.current_state == GameManager.State.FEINT_CHECK
			and GameManager.state.p2_pending_feint
			and not server_received_inputs.has("2")
		)
		if needs_p2_selection or needs_p2_feint:
			if is_player_2_human:
				await get_tree().create_timer(0.2).timeout
				if GameManager.current_state != GameManager.State.SELECTION and GameManager.current_state != GameManager.State.FEINT_CHECK:
					return
				_prepare_human_turn(2)
			else:
				_run_bot_turn(2)


func _check_server_funnel() -> void:
	var inputs_ready: bool = false
	var match_state: MatchState = GameManager.state

	if GameManager.current_state == GameManager.State.SELECTION:
		var p1_ready: bool = server_received_inputs.has("1") or match_state.p1_locked_card != null
		var p2_ready: bool = server_received_inputs.has("2") or match_state.p2_locked_card != null
		if p1_ready and p2_ready:
			inputs_ready = true
	elif GameManager.current_state == GameManager.State.FEINT_CHECK:
		var p1_ready: bool = (not match_state.p1_pending_feint) or server_received_inputs.has("1")
		var p2_ready: bool = (not match_state.p2_pending_feint) or server_received_inputs.has("2")
		if p1_ready and p2_ready:
			inputs_ready = true

	if inputs_ready:
		print("🚀 [SERVER FUNNEL] Ready! Blasting to clients...")
		if match_state.p1_locked_card != null and not server_received_inputs.has("1"):
			server_received_inputs["1"] = { "card": "__LOCKED__", "extra": {} }
		if match_state.p2_locked_card != null and not server_received_inputs.has("2"):
			server_received_inputs["2"] = { "card": "__LOCKED__", "extra": {} }

		client_execute_turn.rpc(server_received_inputs.duplicate())
		server_received_inputs.clear()


@rpc("authority", "call_local", "reliable")
func client_execute_turn(inputs: Dictionary) -> void:
	print(">>> NETWORK SYNC: Executing Turn Data Deterministically!")
	for p_id: int in [1, 2]:
		var str_id: String = str(p_id)
		if inputs.has(str_id):
			var data: Dictionary = inputs[str_id]
			var card_name: String = str(data.get("card", ""))
			var extra: Dictionary = data.get("extra", {})
			var action: ActionData = _get_action_to_submit(p_id, card_name)
			GameManager.player_select_action(p_id, action, extra)


func _get_action_to_submit(player_id: int, card_name: String) -> ActionData:
	if card_name == "SKIP FEINT" or card_name == "":
		return null

	var locked_card: ActionData = GameManager.state.p1_locked_card if player_id == 1 else GameManager.state.p2_locked_card
	if locked_card != null and GameManager.current_state == GameManager.State.SELECTION:
		if card_name == "__LOCKED__" or card_name == locked_card.display_name:
			return locked_card

	var character: CharacterData = p1_resource if player_id == 1 else p2_resource
	if card_name == "Struggle":
		var is_offence: bool = (GameManager.get_attacker() == player_id)
		var type: ActionData.Type = ActionData.Type.OFFENCE if is_offence else ActionData.Type.DEFENCE
		return GameManager.get_struggle_action(type)
	return _find_card_by_name(character, card_name)

#endregion

#region Bot Decision Making

func _run_bot_turn(player_id: int) -> void:
	_current_input_player = player_id
	var character: CharacterData = p1_resource if player_id == 1 else p2_resource

	var locked_card: ActionData = GameManager.state.p1_locked_card if player_id == 1 else GameManager.state.p2_locked_card
	if locked_card != null and GameManager.current_state == GameManager.State.SELECTION:
		print(">>> BOT P" + str(player_id) + " LOCKED INTO: " + locked_card.display_name)
		server_receive_input(player_id, "__LOCKED__", {})
		return

	var c: Dictionary = _get_player_constraints(player_id)
	var is_feinting: bool = (GameManager.current_state == GameManager.State.FEINT_CHECK)
	var base_feint_card: ActionData = (GameManager.state.p1_action_queue if player_id == 1 else GameManager.state.p2_action_queue) if is_feinting else null
	var base_feint_cost: int = base_feint_card.cost if base_feint_card != null else 0

	var card: ActionData
	var extra_data: Dictionary = {}

	if TrialManager.is_trial_active and player_id == 2:
		card = TrialManager.get_bot_card_for_turn(character) if not is_feinting else null
	elif TutorialManager.is_tutorial_active and player_id == 2:
		if is_feinting:
			card = null
		else:
			var target_card_name: String = str(TutorialManager.get_current_data().get("bot_card", ""))
			card = _find_card_by_name(character, target_card_name)
			if card == null:
				printerr("TUTORIAL ERROR: Bot missing card " + target_card_name)
				card = GameManager.get_struggle_action(ActionData.Type.OFFENCE)
	else:
		var opponent: CharacterData = p2_resource if player_id == 1 else p1_resource
		var choice: Dictionary = BotDecisionMakerScript.choose_action(
			character,
			opponent,
			player_id,
			c["filter"],
			bool(c["needs_opener"]),
			int(c["max_cost"]),
			int(c["opening_stat"]),
			bool(c["can_use_super"]),
			int(c["opportunity_stat"]),
			is_feinting,
			base_feint_cost
		)
		card = choice["card"] as ActionData
		extra_data = choice["extra"] as Dictionary

	if card == null:
		print(">>> BOT P" + str(player_id) + " SKIPS FEINT")
		server_receive_input(player_id, "SKIP FEINT", {})
		return

	print(">>> BOT P" + str(player_id) + " COMMITTED: " + card.display_name)
	server_receive_input(player_id, card.display_name, extra_data)

#endregion

#region Logging & Lookup Helpers

func _on_clash_resolved(winner_id: int, _p1_card: ActionData, _p2_card: ActionData, _results: Dictionary) -> void:
	print("\n>>> Clash Winner: P" + str(winner_id))
	_update_visuals()


func _on_log_updated(text: String) -> void:
	print("   > " + text)


func _print_status_report() -> void:
	var p1: CharacterData = p1_resource
	var p2: CharacterData = p2_resource
	var visual: String = "[ "
	for i: int in range(1, 5):
		visual += ("P1 " if GameManager.state.momentum == i else str(i) + " ")
	visual += "| "
	for i: int in range(5, 9):
		visual += ("P2 " if GameManager.state.momentum == i else str(i) + " ")
	visual += "]"
	print("\n[STATUS] P1: " + str(p1.current_hp) + "HP/" + str(p1.current_sp) + "SP  vs  P2: " + str(p2.current_hp) + "HP/" + str(p2.current_sp) + "SP")
	print("[MOMENTUM] " + visual)


func _find_card_by_name(character: CharacterData, card_name: String) -> ActionData:
	for card: ActionData in character.deck:
		if card.display_name == card_name:
			return card
	return null


func _get_button_for_card(card_name: String) -> Control:
	var grid: Node = battle_ui.get("button_grid") as Node
	if not grid:
		return null
	for btn: Node in grid.get_children():
		var action: ActionData = btn.get("my_action") as ActionData
		if action != null and action.display_name == card_name:
			return btn as Control
	return null

#endregion
