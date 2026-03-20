extends Control

@onready var container = $RewardContainer
@onready var title_label = $TitleLabel 

# Preload your existing displays
var card_display_scene = preload("res://Scenes/CardDisplay.tscn")
var overlay_scene = preload("res://Scenes/RunStatusOverlay.tscn")

func _ready():
	AudioManager.play_music("menu_theme")
	
	# 1. Add Overlay
	var overlay = overlay_scene.instantiate()
	add_child(overlay)
	
	# --- AWARD META CURRENCY ---
	var tokens_earned = 1 
	
	if RunManager.is_rival_match and RunManager.active_sponsor:
		tokens_earned += RunManager.active_sponsor.rival_reward_currency_bonus
		# Note: We do NOT reset is_rival_match yet so the item can spawn below!
	
	RunManager.add_circuit_tokens(tokens_earned)
	
	# 2. Generate Rewards
	_generate_rewards()

func _generate_rewards():
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
	
	# SLOT 1: ACTION (Standard Random - No weighting needed)
	if valid_actions.size() > 0: 
		choices.append(valid_actions.pick_random())
	else: 
		choices.append(stat_upgrades.pick_random())
		
	# SLOT 2: UPGRADE/ITEM (Weighted for Synergy!)
	if valid_items.size() > 0 and randf() > 0.5: 
		choices.append(_get_weighted_random(valid_items))
	else: 
		choices.append(stat_upgrades.pick_random())
		
	# SLOT 3: WILDCARD
	var roll = randf()
	if roll < 0.4 and valid_actions.size() > 0: 
		choices.append(valid_actions.pick_random())
	elif roll < 0.7 and valid_items.size() > 0: 
		choices.append(_get_weighted_random(valid_items))
	else: 
		choices.append(stat_upgrades.pick_random())
		
	# --- SPONSOR EXTRA OPTIONS ---
	if RunManager.active_sponsor and RunManager.active_sponsor.extra_draft_options > 0:
		for i in range(RunManager.active_sponsor.extra_draft_options):
			if valid_actions.size() > 0 and randf() > 0.5:
				choices.append(valid_actions.pick_random())
			else:
				choices.append(stat_upgrades.pick_random())
	
	# --- GRUDGE MATCH PAYOUT ---
	if RunManager.is_rival_match and RunManager.active_sponsor:
		if RunManager.active_sponsor.rival_reward_item != null:
			choices.insert(0, RunManager.active_sponsor.rival_reward_item)
		
		# NOW we reset the flag
		RunManager.is_rival_match = false
	
	# 4. Render Options
	for reward in choices:
		_create_reward_card(reward)
		
	# --- SPONSOR REROLLS ---
	if RunManager.get("current_rerolls") != null and RunManager.current_rerolls > 0:
		var reroll_btn = Button.new()
		reroll_btn.text = "Reroll Options (" + str(RunManager.current_rerolls) + " left)"
		reroll_btn.custom_minimum_size = Vector2(200, 50)
		add_child(reroll_btn)
		reroll_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		reroll_btn.position.y -= 50
		
		reroll_btn.pressed.connect(func():
			AudioManager.play_sfx("ui_click")
			RunManager.current_rerolls -= 1
			reroll_btn.queue_free()
			_generate_rewards()
		)

func _create_reward_card(reward):
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(220, 320)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.add_child(btn)
	
	# Card Styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.3)
	btn.add_theme_stylebox_override("normal", style)
	
	if reward is ActionData:
		var disp = card_display_scene.instantiate()
		disp.set_card_data(reward)
		disp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		btn.add_child(disp)
		
		# 1. Set to full rectangle first
		disp.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		# 2. Add a 5-pixel margin on all sides to shrink it slightly
		disp.offset_left = 5
		disp.offset_top = 5
		disp.offset_right = -5   # Negative to pull it inward from the right
		disp.offset_bottom = -5  # Negative to pull it inward from the bottom
	
	elif reward is EquipmentData:
		# FIX: item_name instead of display_name
		_build_info_card(btn, reward.item_name, reward.description, Color(0.4, 0.6, 1.0), "EQUIPMENT")
		
	elif reward is Dictionary:
		_build_info_card(btn, reward.text, reward.desc, Color(1.0, 0.5, 0.5), "UPGRADE")

	btn.pressed.connect(func(): _on_selected(reward))

func _on_selected(reward):
	AudioManager.play_sfx("ui_click")
	RunManager.apply_reward(reward)

func _player_has_item(item_data):
	var p = RunManager.player_run_data
	for i in p.equipment:
		# FIX: item_name check
		if i.item_name == item_data.item_name: return true
	return false

# --- WEIGHTED RANDOM (Only for Equipment) ---
func _get_weighted_random(pool: Array):
	if pool.is_empty(): return null
	
	var active_synergies = []
	if RunManager.has_method("get_active_synergies"):
		active_synergies = RunManager.get_active_synergies()
		
	var weighted_pool = []
	for item in pool:
		var weight = 1
		# Only weight items that have synergy_keywords (Sponsors/Equipment)
		if item is BaseModifierData:
			for keyword in active_synergies:
				if keyword in item.synergy_keywords:
					weight += 2
					
		for i in range(weight):
			weighted_pool.append(item)
			
	return weighted_pool.pick_random()

func _build_info_card(parent, title, desc, color, category):
	# 1. Title
	var t = Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.modulate = color
	t.position = Vector2(10, 40)
	t.size = Vector2(200, 60)
	parent.add_child(t)
	
	# --- FIX: Re-added the Category Header! ---
	var cat = Label.new()
	cat.text = category
	cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat.modulate = Color(0.5, 0.5, 0.5)
	cat.position = Vector2(0, 10)
	cat.size.x = 220
	parent.add_child(cat)
	# ------------------------------------------
	
	# 3. Description
	var d = RichTextLabel.new()
	d.text = "[center]" + desc + "[/center]"
	d.bbcode_enabled = true
	d.position = Vector2(10, 120)
	d.size = Vector2(200, 150)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)
