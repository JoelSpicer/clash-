extends Control

#region vars
# --- DATA ---
var action_tree_dict = {}     
var id_to_name = {}
var name_to_id = {}

const NODE_QUICK = 73
const NODE_TECHNICAL = 74
const NODE_PATIENT = 75
const NODE_HEAVY = 76

# --- SCENE REFS ---
@onready var nodes_layer = %NodesLayer
@onready var lines_layer = %LinesLayer

# --- STATE ---
var unlocked_ids: Array[int] = []
var owned_ids: Array[int] = []
var selected_class_id: int = 0
var is_class_locked: bool = false
var pending_unlock_id: int = 0 

# --- STATS TRACKING ---
var current_max_hp: int = 10
var current_max_sp: int = 3

# --- UI REFS ---
var ui_layer: CanvasLayer
var stats_label: Label 
var popup_card: Control
var card_scene = preload("res://Scenes/CardDisplay.tscn")

# Loadout Manager Refs
var loadout_panel: PanelContainer
var active_container: HBoxContainer
var reserve_container: HFlowContainer 
var toggle_btn: Button
#endregion

func _ready():
	action_tree_dict = ClassFactory.TREE_CONNECTIONS
	id_to_name = ClassFactory.ID_TO_NAME_MAP
	
	# Reverse lookup
	name_to_id.clear()
	for id in id_to_name:
		name_to_id[id_to_name[id]] = id
	
	# 1. SETUP NODES
	for child in nodes_layer.get_children():
		if child.has_method("setup"):
			var id = int(str(child.name)) 
			var a_name = id_to_name.get(id, "Unknown")
			child.setup(id, a_name)
			
			# Connect Signals
			if not child.action_clicked.is_connected(_on_node_clicked):
				child.action_clicked.connect(_on_node_clicked)
			if not child.hovered.is_connected(_on_node_hovered):
				child.hovered.connect(_on_node_hovered)
			if not child.exited.is_connected(_on_node_exited):
				child.exited.connect(_on_node_exited)

	# 2. CREATE UI LAYER (Draws on top of Tree)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10 
	add_child(ui_layer)

	# 3. BUILD UI ELEMENTS
	_build_ui_overlay()
	_setup_popup()
	
	if RunManager.is_arcade_mode:
		print("ActionTree: Loading Arcade Run Data...")
		owned_ids = RunManager.player_owned_tree_ids.duplicate()
		if owned_ids.size() > 0: selected_class_id = owned_ids[0] 
		
		# Hide unnecessary buttons
		var btn_back = $TreeContainer/BackButton
		if btn_back: 
			if RunManager.current_level == 1:
				btn_back.visible = true
				btn_back.pressed.connect(_on_back_button_pressed)
			else:
				btn_back.visible = false # Hide for levels 2+ (No escaping!)
		
		# Update Confirm Button text
		var btn_confirm = $TreeContainer/ConfirmButton 
		if btn_confirm:
			if RunManager.free_unlocks_remaining > 0:
				btn_confirm.text = "PICK (" + str(RunManager.free_unlocks_remaining) + " LEFT)"
			else:
				btn_confirm.text = "UNLOCK & FIGHT"
		
		# Recalculate unlocks
		_unlock_neighbors(selected_class_id)
		for oid in owned_ids: 
			_unlock_neighbors(oid)
			
	else:
		_setup_for_current_player()
		var btn_back = $TreeContainer/BackButton
		if btn_back: btn_back.pressed.connect(_on_back_button_pressed)
	
	_refresh_loadout_manager()
	_update_tree_visuals()
	_recalculate_stats()
	lines_layer.queue_redraw()

# ==============================================================================
# UI CONSTRUCTION
# ==============================================================================

func _build_ui_overlay():
	

	# 2. Loadout Manager Panel (Bottom Center, Initially Hidden)
	# Created BEFORE the button so it renders BEHIND it
	loadout_panel = PanelContainer.new()
	loadout_panel.visible = false 
	
	# Anchor to Bottom Full Width
	loadout_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	loadout_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	loadout_panel.custom_minimum_size.y = 300 
	
	# Add a background style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95) 
	loadout_panel.add_theme_stylebox_override("panel", style)
	
	ui_layer.add_child(loadout_panel)
	
	# Layout
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	loadout_panel.add_child(main_vbox)
	
	# --- ROW 1: ACTIVE HAND ---
	var lbl_active = Label.new()
	lbl_active.text = "ACTIVE HAND (Max 8)"
	lbl_active.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(lbl_active)
	
	active_container = HBoxContainer.new()
	active_container.alignment = BoxContainer.ALIGNMENT_CENTER
	active_container.custom_minimum_size.y = 80
	active_container.add_theme_constant_override("separation", 10)
	main_vbox.add_child(active_container)
	
	# Separator
	var sep = HSeparator.new()
	main_vbox.add_child(sep)
	
	# --- ROW 2: RESERVES ---
	var lbl_reserve = Label.new()
	lbl_reserve.text = "RESERVE LIBRARY (Click to Equip)"
	lbl_reserve.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(lbl_reserve)
	
	# ScrollContainer
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 150
	main_vbox.add_child(scroll)
	
	reserve_container = HFlowContainer.new() 
	reserve_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reserve_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reserve_container.alignment = FlowContainer.ALIGNMENT_CENTER
	scroll.add_child(reserve_container)

	# 3. Toggle Button (Bottom Right)
	# Created LAST so it renders ON TOP
	toggle_btn = Button.new()
	toggle_btn.text = "EDIT LOADOUT"
	toggle_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	toggle_btn.position -= Vector2(20, 20) # Padding
	toggle_btn.custom_minimum_size = Vector2(150, 50)
	toggle_btn.pressed.connect(_on_toggle_loadout_pressed)
	ui_layer.add_child(toggle_btn)

func _setup_popup():
	popup_card = card_scene.instantiate()
	popup_card.visible = false
	popup_card.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	# FIX 1: Break existing layout constraints (The Warning Fix)
	# This ensures the card doesn't try to stretch to the full screen size
	popup_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	
	# Ensure it is on top of the UI layer
	popup_card.set_as_top_level(true) 
	popup_card.z_index = 4096 
	
	# FIX 2: Explicit Dimensions (Portrait Mode)
	popup_card.size = Vector2(250, 350)
	
	# FIX 3: Scale
	popup_card.scale = Vector2(0.6, 0.6) 
	
	ui_layer.add_child(popup_card)

# ==============================================================================
# LOGIC
# ==============================================================================

func _on_toggle_loadout_pressed():
	loadout_panel.visible = !loadout_panel.visible
	if loadout_panel.visible:
		toggle_btn.text = "CLOSE LOADOUT"
		_refresh_loadout_manager()
	else:
		toggle_btn.text = "EDIT LOADOUT"

func _refresh_loadout_manager():
	if not loadout_panel.visible: return
	
	# 1. Clear old buttons
	for c in active_container.get_children(): c.queue_free()
	for c in reserve_container.get_children(): c.queue_free()
	
	var active_deck: Array[ActionData] = []
	var library: Array[ActionData] = []
	
	# 2. Get Data
	if RunManager.is_arcade_mode:
		active_deck = RunManager.player_run_data.deck
		library = RunManager.player_run_data.unlocked_actions
	else:
		# Custom Mode Logic
		if selected_class_id == 0: return
		var class_enum = _get_class_enum_from_id(selected_class_id)
		
		# Starter cards
		var starters = ClassFactory.get_starting_deck(class_enum)
		library.append_array(starters)
		
		# Tree cards
		for id in owned_ids:
			if id >= 73: continue
			var c = ClassFactory.find_action_resource(id_to_name.get(id))
			if c: library.append(c)
			
		# Temporary: Custom Mode just fills active with everything.
		active_deck = library.duplicate()
		library = [] 

	# 3. Populate Active Row
	for card in active_deck:
		var btn = _create_card_button(card, true)
		active_container.add_child(btn)
		
	# 4. Populate Reserve Row
	# Logic: Show cards in 'library' that are NOT in 'active_deck'
	for card in library:
		if not _is_card_in_list(card, active_deck):
			var btn = _create_card_button(card, false)
			reserve_container.add_child(btn)

func _create_card_button(card: ActionData, is_active: bool) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(60, 80)
	btn.tooltip_text = card.display_name + "\n" + card.description
	
	if card.icon:
		btn.icon = card.icon
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true
	else:
		btn.text = card.display_name.left(3)
		
	if card.type == ActionData.Type.OFFENCE:
		btn.modulate = Color(1.0, 0.6, 0.6)
	else:
		btn.modulate = Color(0.6, 0.8, 1.0)
		
	# LOGIC:
	if is_active:
		# Click to UNEQUIP
		btn.pressed.connect(func(): _on_unequip_card(card))
	else:
		# Click to EQUIP
		btn.pressed.connect(func(): _on_equip_card(card))
		
	return btn

func _on_unequip_card(card: ActionData):
	if not RunManager.is_arcade_mode: return
	var player = RunManager.player_run_data
	
	if player.deck.size() <= 1:
		print("Cannot have empty deck.")
		return
		
	_remove_from_deck(player, card)
	_refresh_loadout_manager()
	_update_tree_visuals()
	_recalculate_stats()

func _on_equip_card(card: ActionData):
	if not RunManager.is_arcade_mode: return
	var player = RunManager.player_run_data
	
	if player.deck.size() >= ClassFactory.HAND_LIMIT:
		print("Hand Full! Remove a card first.")
		return
		
	player.deck.append(card)
	_refresh_loadout_manager()
	_update_tree_visuals()
	_recalculate_stats()

# --- TOOLTIP LOGIC ---
func _on_node_hovered(id, a_name):
	# CLASS NODES
	if id >= 73 and id <= 76:
		var class_info = _get_class_display_data(id)
		popup_card.set_card_data(class_info)
		popup_card.visible = true
		_update_popup_position()
		return

	# ACTION NODES
	var res = ClassFactory.find_action_resource(a_name)
	if res == null:
		res = ActionData.new()
		res.display_name = a_name
		res.description = "(File not created yet)"
		res.cost = 0
	
	if popup_card.has_method("set_card_data"):
		popup_card.set_card_data(res, res.cost)
	
	popup_card.visible = true
	_update_popup_position()

func _on_node_exited():
	popup_card.visible = false

func _process(_delta):
	if popup_card.visible:
		_update_popup_position()

func _update_popup_position():
	var m_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport_rect().size
	var card_size = popup_card.size * popup_card.scale
	var offset = Vector2(30, 30)
	
	var final_pos = m_pos + offset
	
	# Keep on screen
	if final_pos.x + card_size.x > screen_size.x:
		final_pos.x = m_pos.x - card_size.x - offset.x
	if final_pos.y + card_size.y > screen_size.y:
		final_pos.y = m_pos.y - card_size.y - offset.y
	
	popup_card.position = final_pos

# --- INTERACTION LOGIC (Tree) ---
func _on_node_clicked(id: int, _name: String):
	if RunManager.is_arcade_mode:
		
		# A. Clicking Owned Node -> Just Highlight
		if id in owned_ids:
			if id >= 73: return
			return
			
		# B. Drafting (Buying new)
		if id not in unlocked_ids: return 
		
		# --- FIX: PREVENT SELECTION IF NO UNLOCKS LEFT ---
		if RunManager.free_unlocks_remaining <= 0:
			# Optional: Visual feedback like a sound or shake
			print("No unlocks remaining! Click START FIGHT.")
			return
		# -------------------------------------------------
		
		pending_unlock_id = id
		
		_update_tree_visuals()
		
		# FIX: Force recalculate so the UI updates IMMEDIATELY with the new card preview
		_recalculate_stats()
		return
	
	# === CUSTOM DECK LOGIC ===
	if id >= 73: 
		if is_class_locked: return
		_select_class(id)
	elif id in owned_ids: 
		_try_deselect_action(id)
	elif id in unlocked_ids:
		owned_ids.append(id)
		_unlock_neighbors(id)
		_update_tree_visuals()
		_recalculate_stats()
	else:
		print("Locked!")

# --- HELPERS ---
func _is_card_in_list(card: ActionData, list: Array[ActionData]) -> bool:
	for c in list:
		if c.display_name == card.display_name: return true
	return false

func _select_class(class_id: int):
	selected_class_id = class_id
	owned_ids.clear()
	unlocked_ids.clear()
	owned_ids.append(class_id)
	_unlock_neighbors(class_id)
	_update_tree_visuals()
	_recalculate_stats()
	_refresh_loadout_manager()

func _recalculate_stats():
	var stats = { "hp": 10, "sp": 3 }
	
	if RunManager.is_arcade_mode:
		var p = RunManager.player_run_data
		
		# FIX: CALCULATE WITH PREVIEW
		# Create a temporary list of what we own + what we are about to buy
		var cards_to_count = p.unlocked_actions.duplicate()
		
		if pending_unlock_id != 0:
			var card_name = id_to_name.get(pending_unlock_id)
			var pending_card = ClassFactory.find_action_resource(card_name)
			if pending_card:
				cards_to_count.append(pending_card)
		
		stats = ClassFactory.calculate_stats_for_deck(p.class_type, cards_to_count)
		
	else:
		if selected_class_id == 0: return
		var class_enum = _get_class_enum_from_id(selected_class_id)
		var temp_deck = ClassFactory.get_starting_deck(class_enum)
		for id in owned_ids:
			if id >= 73: continue
			var card = ClassFactory.find_action_resource(id_to_name.get(id))
			if card: temp_deck.append(card)
		stats = ClassFactory.calculate_stats_for_deck(class_enum, temp_deck)
	
	current_max_hp = stats["hp"]
	current_max_sp = stats["sp"]

func _unlock_neighbors(node_id: int):
	if node_id in action_tree_dict:
		for neighbor_id in action_tree_dict[node_id]:
			if neighbor_id not in unlocked_ids and neighbor_id not in owned_ids:
				unlocked_ids.append(neighbor_id)

func _update_tree_visuals():
	for child in nodes_layer.get_children():
		var id = int(str(child.name))
		
		if id == pending_unlock_id:
			child.set_status(1) # Available (Selected)
			child.modulate = Color(1.5, 1.5, 1.5)
		else:
			child.modulate = Color.WHITE
			
			if id in owned_ids:
				# FIX: Force ALL owned nodes (including Class Node) to Green (Status 3)
				# We no longer distinguish between 'Equipped' and 'Reserve' on the tree visual itself.
				child.set_status(3) 
			elif id in unlocked_ids:
				child.set_status(1) # AVAILABLE (Yellow)
			else:
				child.set_status(0) # LOCKED

func _on_confirm_button_pressed():
	if RunManager.is_arcade_mode:
		
		# --- CASE 1: START FIGHT (Ready to go) ---
		if RunManager.free_unlocks_remaining <= 0 and pending_unlock_id == 0:
			
			# --- NEW: LOADOUT VALIDATION ---
			var has_offence = false
			var has_defence = false
			
			for card in RunManager.player_run_data.deck:
				if card.type == ActionData.Type.OFFENCE: has_offence = true
				if card.type == ActionData.Type.DEFENCE: has_defence = true
				
			if not has_offence or not has_defence:
				print("Cannot Start: Invalid Loadout.")
				# Visual Feedback using the Stats Label
				stats_label.text = "REQ: 1 OFFENCE & 1 DEFENCE!"
				stats_label.modulate = Color(1, 0.3, 0.3) # Red Warning
				
				# Reset the label after 2 seconds
				await get_tree().create_timer(2.0).timeout
				_recalculate_stats()
				return
			# -------------------------------
			
			RunManager.start_next_fight()
			return

		# --- CASE 2: DRAFTING (Spending Free Unlocks) ---
		# This now handles BOTH the initial draft AND level-up rewards
		if RunManager.free_unlocks_remaining > 0:
			if pending_unlock_id == 0: return 
			
			# 1. Commit
			RunManager.player_owned_tree_ids.append(pending_unlock_id)
			owned_ids.append(pending_unlock_id)
			
			var card_name = id_to_name.get(pending_unlock_id)
			var new_card = ClassFactory.find_action_resource(card_name)
			if new_card:
				RunManager.player_run_data.unlocked_actions.append(new_card)
				if RunManager.player_run_data.deck.size() < ClassFactory.HAND_LIMIT:
					RunManager.player_run_data.deck.append(new_card)
			
			# 2. Update
			_unlock_neighbors(pending_unlock_id)
			RunManager.free_unlocks_remaining -= 1
			pending_unlock_id = 0
			
			_refresh_loadout_manager()
			_update_tree_visuals()
			
			# 3. Heal & Stats (This covers the "Full Heal on Level Up" requirement)
			ClassFactory._recalculate_stats(RunManager.player_run_data)
			_recalculate_stats() # Update UI
			
			# 4. Check Status
			var btn = $TreeContainer/ConfirmButton
			if RunManager.free_unlocks_remaining <= 0:
				btn.text = "START FIGHT"
				#var btn_back = $TreeContainer/BackButton
				var btn_reset = $TreeContainer/ResetButton
				#if btn_back: btn_back.visible = false
				if btn_reset: btn_reset.visible = false
			else:
				btn.text = "PICK (" + str(RunManager.free_unlocks_remaining) + " LEFT)"
			return

		# --- CASE 3: FALLBACK ---
		if pending_unlock_id != 0:
			print("Warning: Unsanctioned purchase attempt blocked.")
			pending_unlock_id = 0
			_update_tree_visuals()
			return
			
	else:
		# --- CUSTOM DECK LAUNCH ---
		if selected_class_id == 0: return
		var final_character = CharacterData.new()
		match selected_class_id:
			73: final_character.class_type = CharacterData.ClassType.QUICK
			74: final_character.class_type = CharacterData.ClassType.TECHNICAL
			75: final_character.class_type = CharacterData.ClassType.PATIENT
			76: final_character.class_type = CharacterData.ClassType.HEAVY

		var base_deck = ClassFactory.get_starting_deck(final_character.class_type)
		var final_deck: Array[ActionData] = []
		final_deck.append_array(base_deck)
		
		for id in owned_ids:
			if id >= 73: continue 
			var a_name = id_to_name.get(id)
			var card_resource = ClassFactory.find_action_resource(a_name)
			if card_resource: final_deck.append(card_resource)
				
		final_character.deck = final_deck
		final_character.max_hp = current_max_hp
		final_character.max_sp = current_max_sp
		final_character.reset_stats()
		
		if GameManager.editing_player_index == 1:
			var p1_name = GameManager.get("temp_p1_name")
			final_character.character_name = p1_name if p1_name != "" else "Player 1"
			GameManager.next_match_p1_data = final_character
			
			if GameManager.p2_is_custom:
				GameManager.editing_player_index = 2
				_setup_for_current_player()
				return 
		else:
			var p2_name = GameManager.get("temp_p2_name")
			final_character.character_name = p2_name if p2_name != "" else "Player 2"
			GameManager.next_match_p2_data = final_character

		if GameManager.next_match_p2_data == null:
			GameManager.next_match_p2_data = ClassFactory.create_character(CharacterData.ClassType.HEAVY, "Bot")
			
		SceneLoader.change_scene("res://Scenes/MainScene.tscn")

func _on_back_button_pressed():
	# --- NEW: Arcade Mode Cancel ---
	if RunManager.is_arcade_mode:
		print("Canceling Arcade Run...")
		RunManager.handle_loss() # Cleans up the arcade state variables
		SceneLoader.change_scene("res://Scenes/CharacterSelect.tscn")
		return
	# -------------------------------
	print("Canceling customization...")
	GameManager.next_match_p1_data = null
	GameManager.next_match_p2_data = null
	GameManager.editing_player_index = 1
	GameManager.p2_is_custom = false
	GameManager.temp_p1_preset = null
	GameManager.temp_p2_preset = null
	GameManager.temp_p1_name = ""
	GameManager.temp_p2_name = ""
	SceneLoader.change_scene("res://Scenes/MainMenu.tscn")

func _try_deselect_action(id_to_remove: int):
	var remaining_ids = owned_ids.duplicate()
	remaining_ids.erase(id_to_remove)
	
	# Flood fill check
	var reachable_count = 0
	var queue: Array[int] = [selected_class_id]
	var visited = {selected_class_id: true}
	
	while queue.size() > 0:
		var current = queue.pop_front()
		if current in remaining_ids: reachable_count += 1
		if current in action_tree_dict:
			for neighbor in action_tree_dict[current]:
				if neighbor in remaining_ids and not neighbor in visited:
					visited[neighbor] = true
					queue.append(neighbor)
	
	if reachable_count < remaining_ids.size():
		print("Cannot deselect: Disconnects tree!")
		return

	owned_ids.erase(id_to_remove)
	unlocked_ids.clear()
	for owner_id in owned_ids:
		_unlock_neighbors(owner_id)
		
	_update_tree_visuals()
	_recalculate_stats()
	_refresh_loadout_manager()

func _setup_for_current_player():
	var target_selection = 0
	if GameManager.editing_player_index == 1:
		target_selection = GameManager.get("temp_p1_class_selection")
	else:
		target_selection = GameManager.get("temp_p2_class_selection")
		
	owned_ids.clear()
	unlocked_ids.clear()
	is_class_locked = false
	
	if target_selection != null:
		var node_id = 0
		match target_selection:
			0: node_id = 76 
			1: node_id = 75 
			2: node_id = 73 
			3: node_id = 74 
			
		if node_id != 0:
			_select_class(node_id)
			is_class_locked = true 
			
	_refresh_loadout_manager()
	_update_tree_visuals()
	_recalculate_stats()
	lines_layer.queue_redraw()

func _get_class_display_data(id: int) -> ActionData:
	var data = ActionData.new()
	data.cost = 0 
	match id:
		76: 
			data.display_name = "CLASS: HEAVY"
			data.type = ActionData.Type.OFFENCE 
			data.description = "[b]Action: Haymaker[/b]\nOpener, Cost 3, Dmg 2, Mom 3\n[b]Action: Elbow Block[/b]\nBlock 1, Cost 2, Dmg 1\n[b]Passive: Rage[/b]\nPay HP instead of SP when low.\n[b]Growth:[/b]\n[color=#ff9999]Offence:[/color] +1 SP, [color=#99ccff]Defence:[/color] +2 HP\n[b]Speed:[/b] 1"
		75: 
			data.display_name = "CLASS: PATIENT"
			data.type = ActionData.Type.DEFENCE 
			data.description = "[b]Action: Preparation[/b]\nFall Back 2, Opp 1, Reco 1\n[b]Action: Counter Strike[/b]\nDmg 2, Fall Back 2, Parry\n[b]Passive: Keep-up[/b]\nSpend SP to prevent Fall Back.\n[b]Growth:[/b]\n[color=#ff9999]Offence:[/color] +1 HP, [color=#99ccff]Defence:[/color] +1 HP/SP\n[b]Speed:[/b] 2"
		73: 
			data.display_name = "CLASS: QUICK"
			data.type = ActionData.Type.OFFENCE
			data.description = "[b]Action: Roll Punch[/b]\nDmg 1, Cost 1, Mom 1, Rep 3\n[b]Action: Weave[/b]\nDodge 1, Fall Back 1\n[b]Passive: Relentless[/b]\nEvery 3rd combo hit gains Reco 1.\n[b]Growth:[/b]\n[color=#ff9999]Offence:[/color] +1 HP, [color=#99ccff]Defence:[/color] +2 SP\n[b]Speed:[/b] 4"
		74: 
			data.display_name = "CLASS: TECHNICAL"
			data.type = ActionData.Type.DEFENCE
			data.description = "[b]Action: Discombobulate[/b]\nCost 1, Dmg 1, Tiring 1\n[b]Action: Hand Catch[/b]\nBlock 1, Cost 1, Reversal\n[b]Passive: Technique[/b]\nSpend 1 SP to add Opener, Tiring, or Momentum to action.\n[b]Growth:[/b]\n[color=#ff9999]Offence:[/color] +1 SP/HP, [color=#99ccff]Defence:[/color] +1 SP\n[b]Speed:[/b] 3"
	return data

func _is_id_equipped(id: int) -> bool:
	if not RunManager.is_arcade_mode: return id in owned_ids
	var player = RunManager.player_run_data
	var c_name = id_to_name.get(id)
	for card in player.deck:
		if card.display_name == c_name: return true
	return false

func _is_card_equipped(player, card_data) -> bool:
	for c in player.deck:
		if c.display_name == card_data.display_name: return true
	return false

func _remove_from_deck(player, card_data):
	for i in range(player.deck.size()):
		if player.deck[i].display_name == card_data.display_name:
			player.deck.remove_at(i)
			return

func _get_class_enum_from_id(id: int) -> int:
	match id:
		73: return CharacterData.ClassType.QUICK
		74: return CharacterData.ClassType.TECHNICAL
		75: return CharacterData.ClassType.PATIENT
		76: return CharacterData.ClassType.HEAVY
	return CharacterData.ClassType.HEAVY

func _get_id_from_card(card: ActionData) -> int:
	if card.display_name in name_to_id:
		return name_to_id[card.display_name]
	return 0
