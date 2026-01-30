extends Control

@onready var name_label = $VBoxContainer/NameLabel

# HP References
@onready var hp_bar = $VBoxContainer/HPBarHolder/HPBar
@onready var hp_ghost = $VBoxContainer/HPBarHolder/HPGhost
@onready var hp_text = $VBoxContainer/HPBarHolder/HPBar/HPLabel

# SP References (Updated Paths)
@onready var sp_bar = $VBoxContainer/SPBarHolder/SPBar
@onready var sp_ghost = $VBoxContainer/SPBarHolder/SPGhost # New
@onready var sp_text = $VBoxContainer/SPBarHolder/SPBar/SPLabel

@onready var status_label = $VBoxContainer/StatusLabel
@onready var portrait = get_node_or_null("Portrait")

var original_pos: Vector2 = Vector2.ZERO

func _ready():
	if portrait: original_pos = portrait.position
	
	# Sync Ghosts on load
	if hp_ghost:
		hp_ghost.max_value = hp_bar.max_value
		hp_ghost.value = hp_bar.value
	if sp_ghost:
		sp_ghost.max_value = sp_bar.max_value
		sp_ghost.value = sp_bar.value

func setup(character: CharacterData):
	name_label.text = character.character_name
	
	# HP Setup
	hp_bar.max_value = character.max_hp
	hp_bar.value = character.current_hp
	if hp_ghost:
		hp_ghost.max_value = character.max_hp
		hp_ghost.value = character.current_hp
	hp_text.text = str(character.current_hp) + "/" + str(character.max_hp)
	
	# SP Setup
	sp_bar.max_value = character.max_sp
	sp_bar.value = character.current_sp
	if sp_ghost:
		sp_ghost.max_value = character.max_sp
		sp_ghost.value = character.current_sp
	sp_text.text = str(character.current_sp) + "/" + str(character.max_sp)
	
	if portrait and character.portrait:
		portrait.texture = character.portrait

func configure_visuals(is_player_2: bool):
	# ... (Paste your existing layout code here) ...
	# Just ensuring the fill modes update correctly for the new ghosts
	
	scale = Vector2(1, 1)
	var hud_width = 300 
	var screen_margin = 20
	var gap = 15
	var offset = 150
	$VBoxContainer.custom_minimum_size.x = hud_width
	$VBoxContainer.size.x = hud_width 
	
	var bg = get_node_or_null("Panel") 
	if not bg: bg = get_node_or_null("Background")
	
	# Force Expand
	if hp_bar: hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if hp_ghost: hp_ghost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sp_bar: sp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sp_ghost: sp_ghost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if is_player_2:
		$VBoxContainer.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		$VBoxContainer.position.x = + screen_margin  - hud_width
		$VBoxContainer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		if bg:
			bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			bg.position = $VBoxContainer.position
			bg.size = $VBoxContainer.size
			bg.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		# Set Fill Modes (Right to Left)
		if hp_bar: hp_bar.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
		if hp_ghost: hp_ghost.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
		if sp_bar: sp_bar.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
		if sp_ghost: sp_ghost.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
		
		if portrait:
			portrait.scale.x = -1
			portrait.pivot_offset = portrait.size / 2
			portrait.position.x = $VBoxContainer.position.x - portrait.size.x - gap + offset
	else:
		$VBoxContainer.set_anchors_preset(Control.PRESET_TOP_LEFT)
		$VBoxContainer.position.x = screen_margin
		$VBoxContainer.grow_horizontal = Control.GROW_DIRECTION_END
		if bg:
			bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
			bg.position = $VBoxContainer.position
			bg.size = $VBoxContainer.size
			bg.grow_horizontal = Control.GROW_DIRECTION_END
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Set Fill Modes (Left to Right)
		if hp_bar: hp_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		if hp_ghost: hp_ghost.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		if sp_bar: sp_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		if sp_ghost: sp_ghost.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		
		if portrait:
			portrait.scale.x = 1
			portrait.pivot_offset = portrait.size / 2
			portrait.position.x = $VBoxContainer.position.x + hud_width + gap - offset

	if portrait: original_pos = portrait.position

func update_stats(character: CharacterData, opportunity: int, opening: int, bide_active: bool):
	
	hp_text.text = str(character.current_hp) + "/" + str(character.max_hp)
	sp_text.text = str(character.current_sp) + "/" + str(character.max_sp)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# --- HP ANIMATION ---
	tween.tween_property(hp_bar, "value", character.current_hp, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	
	if hp_ghost:
		if character.current_hp < hp_ghost.value:
			# Taken Damage: Delay then slide
			var t = create_tween()
			t.tween_interval(0.4)
			t.tween_property(hp_ghost, "value", character.current_hp, 0.6).set_trans(Tween.TRANS_SINE)
		else:
			# Healed: Instant catch up
			hp_ghost.value = character.current_hp

	# --- SP ANIMATION ---
	tween.tween_property(sp_bar, "value", character.current_sp, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	
	if sp_ghost:
		if character.current_sp < sp_ghost.value:
			# Spent SP: Delay then slide (Orange Ghost)
			var t = create_tween()
			t.tween_interval(0.4)
			t.tween_property(sp_ghost, "value", character.current_sp, 0.6).set_trans(Tween.TRANS_SINE)
		else:
			# Recovered SP: Instant catch up
			sp_ghost.value = character.current_sp

	# ... (Rest of existing status text logic) ...
	var status_txt = ""
	for s_name in character.statuses:
		status_txt += "[" + s_name.to_upper() + "] "
	
	if opportunity > 0: status_txt += "[OPPORTUNITY] "
	if opening > 0: status_txt += "[OPENING: " + str(opening) + "]"
	if bide_active: status_txt += "[BIDE (+1 DMG)]"
	
	status_label.text = status_txt
	
	if character.statuses.has("Injured"):
		status_label.modulate = Color.ORANGE_RED
	elif bide_active:
		status_label.modulate = Color(0.3, 1.0, 1.0)
	elif opportunity > 0:
		status_label.modulate = Color.YELLOW
	else:
		status_label.modulate = Color.WHITE
		
func play_attack_animation(direction: Vector2):
	if not portrait: return
	var tween = create_tween()
	tween.tween_property(portrait, "position", original_pos - (direction * 0.2), 0.1)
	tween.tween_property(portrait, "position", original_pos + direction, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(portrait, "position", original_pos, 0.2).set_delay(0.1)

func play_hit_animation():
	if not portrait: return
	var tween = create_tween()
	tween.tween_property(portrait, "modulate", Color(3, 0.5, 0.5), 0.05)
	tween.tween_property(portrait, "modulate", Color.WHITE, 0.3)
	
	var shake_offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
	var t_shake = create_tween()
	t_shake.tween_property(portrait, "position", original_pos + shake_offset, 0.05)
	t_shake.tween_property(portrait, "position", original_pos - shake_offset, 0.05)
	t_shake.tween_property(portrait, "position", original_pos, 0.05)
