extends Control

@onready var container = $RewardContainer
@onready var title_label = $TitleLabel # Make sure you have this node

# Preload your existing displays
var card_display_scene = preload("res://Scenes/CardDisplay.tscn")
var overlay_scene = preload("res://Scenes/RunStatusOverlay.tscn")

func _ready():
	AudioManager.play_music("menu_theme")
	
	# 1. Add Overlay
	var overlay = overlay_scene.instantiate()
	add_child(overlay)
	
	# --- NEW: AWARD META CURRENCY ---
	var tokens_earned = 1 # Base payout for winning any fight
	
	# Check for massive Grudge Match payout
	if RunManager.is_rival_match and RunManager.active_sponsor:
		tokens_earned += RunManager.active_sponsor.rival_reward_currency_bonus
		
		# Reset the flag so they don't get the boss loot again!
		RunManager.is_rival_match = false 
	
	# Add it to the global bank!
	RunManager.add_circuit_tokens(tokens_earned)
	# --------------------------------
	
	# 2. Generate Rewards
	_generate_rewards()

func _generate_rewards():
	# 1. Clear old rewards
	for c in container.get_children():
		c.queue_free()
		
	var valid_actions = RunManager.get_valid_action_rewards()
	var all_items = RunManager.get_all_equipment()
	var stat_upgrades = RunManager.get_stat_upgrades()
	
	var valid_items = []
	for item in all_items:
		if not _player_has_item(item):
			valid_items.append(item)
	
	var choices = []
	
	# SLOT 1: ACTION
	if valid_actions.size() > 0: choices.append(valid_actions.pick_random())
	else: choices.append(stat_upgrades.pick_random())
		
	# SLOT 2: UPGRADE/ITEM 
	if valid_items.size() > 0 and randf() > 0.5: choices.append(valid_items.pick_random())
	else: choices.append(stat_upgrades.pick_random())
		
	# SLOT 3: WILDCARD
	var roll = randf()
	if roll < 0.4 and valid_actions.size() > 0: choices.append(valid_actions.pick_random())
	elif roll < 0.7 and valid_items.size() > 0: choices.append(valid_items.pick_random())
	else: choices.append(stat_upgrades.pick_random())
		
	# --- NEW: SPONSOR EXTRA OPTIONS ---
	if RunManager.active_sponsor and RunManager.active_sponsor.extra_draft_options > 0:
		for i in range(RunManager.active_sponsor.extra_draft_options):
			if valid_actions.size() > 0 and randf() > 0.5:
				choices.append(valid_actions.pick_random())
			else:
				choices.append(stat_upgrades.pick_random())
	# ----------------------------------
	
	# --- NEW: GRUDGE MATCH PAYOUT ---
	if RunManager.is_rival_match and RunManager.active_sponsor:
		# 1. Give the unique item (if it exists)
		if RunManager.active_sponsor.rival_reward_item != null:
			# We insert it at the front of the array so it's the first card they see
			choices.insert(0, RunManager.active_sponsor.rival_reward_item)
			
		# 2. (Optional) Award Currency
		if RunManager.active_sponsor.rival_reward_currency_bonus > 0:
			print("Awarded " + str(RunManager.active_sponsor.rival_reward_currency_bonus) + " Circuit Tokens!")
			# You will hook this up later when we build the Meta-Save System
			
		# 3. Reset the flag so they don't get the item on the next normal node
		#RunManager.is_rival_match = false
	# ---------------------------------
	
	# 4. Render Options
	for reward in choices:
		_create_reward_card(reward)
		
	# --- NEW: SPONSOR REROLLS ---
	# Dynamically spawn a Reroll Button at the bottom if they have tokens
	if RunManager.get("current_rerolls") != null and RunManager.current_rerolls > 0:
		var reroll_btn = Button.new()
		reroll_btn.text = "Reroll Options (" + str(RunManager.current_rerolls) + " left)"
		reroll_btn.custom_minimum_size = Vector2(200, 50)
		reroll_btn.add_theme_font_size_override("font_size", 20)
		# Add it to the main screen, anchored bottom center
		add_child(reroll_btn)
		reroll_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		reroll_btn.position.y -= 50
		
		reroll_btn.pressed.connect(func():
			AudioManager.play_sfx("ui_click")
			RunManager.current_rerolls -= 1
			reroll_btn.queue_free() # Remove button to refresh
			_generate_rewards()     # Re-run this entire function!
		)

func _create_reward_card(reward):
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(220, 320)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	container.add_child(btn)
	
	# Styling (Dark Card Base)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.3)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover = style.duplicate()
	hover.border_color = Color(1.0, 0.8, 0.2) # Gold Border on Hover
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	
	
	# --- CONTENT GENERATION ---
	
	# A. ACTION CARD
	if reward is ActionData:
		# We reuse your nice CardDisplay, but scale it down slightly
		var disp = card_display_scene.instantiate()
		disp.set_card_data(reward)
		disp.scale = Vector2(0.8, 0.8)
		disp.position = Vector2(10, 10) # Padding
		disp.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let button catch clicks
		btn.add_child(disp)
		
		# Label for "New Action"
		var lbl = Label.new()
		lbl.text = "NEW ACTION"
		lbl.modulate = Color.GREEN
		lbl.position = Vector2(0, -30)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size.x = 220
		btn.add_child(lbl)

	# B. EQUIPMENT
	elif reward is EquipmentData:
		_build_info_card(btn, reward.display_name, reward.description, Color(0.4, 0.6, 1.0), "EQUIPMENT")
		
	# C. STAT UPGRADE
	elif reward is Dictionary:
		_build_info_card(btn, reward.text, reward.desc, Color(1.0, 0.5, 0.5), "UPGRADE")

	# Connection
	btn.pressed.connect(func(): _on_selected(reward))
	btn.mouse_entered.connect(func(): AudioManager.play_sfx("ui_hover", 0.1))

func _build_info_card(parent, title, desc, color, category):
	# Title
	var t = Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", 20)
	t.modulate = color
	t.position = Vector2(10, 40)
	t.size = Vector2(200, 60)
	parent.add_child(t)
	
	# Category Header
	var cat = Label.new()
	cat.text = category
	cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat.modulate = Color(0.5, 0.5, 0.5)
	cat.position = Vector2(0, 10)
	cat.size.x = 220
	parent.add_child(cat)
	
	# Description
	var d = RichTextLabel.new()
	d.text = "[center]" + desc + "[/center]"
	d.bbcode_enabled = true
	d.position = Vector2(10, 120)
	d.size = Vector2(200, 150)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)

func _on_selected(reward):
	AudioManager.play_sfx("ui_click")
	RunManager.apply_reward(reward)

func _player_has_item(item_data):
	var p = RunManager.player_run_data
	for i in p.equipment:
		if i.display_name == item_data.display_name: return true
	return false
