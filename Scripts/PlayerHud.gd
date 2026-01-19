extends Control

@onready var name_label = $VBoxContainer/NameLabel
@onready var hp_bar = $VBoxContainer/HPBar
@onready var hp_text = $VBoxContainer/HPBar/HPLabel
@onready var sp_bar = $VBoxContainer/SPBar
@onready var sp_text = $VBoxContainer/SPBar/SPLabel
@onready var status_label = $VBoxContainer/StatusLabel
@onready var portrait = get_node_or_null("Portrait")

var original_pos: Vector2 = Vector2.ZERO

func _ready():
	if portrait: original_pos = portrait.position

func setup(character: CharacterData):
	name_label.text = character.character_name
	hp_bar.max_value = character.max_hp
	hp_bar.value = character.current_hp
	hp_text.text = str(character.current_hp) + "/" + str(character.max_hp)
	
	sp_bar.max_value = character.max_sp
	sp_bar.value = character.current_sp
	sp_text.text = str(character.current_sp) + "/" + str(character.max_sp)
	
	if portrait and character.portrait:
		portrait.texture = character.portrait

# --- NEW LAYOUT SYSTEM ---
# Scripts/PlayerHud.gd

func configure_visuals(is_player_2: bool):
	scale = Vector2(1, 1)
	
	# 1. SETUP DIMENSIONS
	var hud_width = 300 
	var screen_margin = 20 # <--- NEW: Margin from the side of the screen
	var gap = 15           # Gap between bars and portrait
	var offset = 150
	# Force the VBox to be the right width
	$VBoxContainer.custom_minimum_size.x = hud_width
	$VBoxContainer.size.x = hud_width 
	
	# Find the background node
	var bg = get_node_or_null("Panel") 
	if not bg: bg = get_node_or_null("Background")
	
	# Force bars to expand
	if hp_bar: hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sp_bar: sp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if is_player_2:
		# --- PLAYER 2 (Right Side) ---
		
		# 1. Anchor VBox to Top-Right
		$VBoxContainer.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		
		# 2. Position it inwards (Negative X)
		# Logic: -300 (Width) - 20 (Margin) = -320 from the right edge
		$VBoxContainer.position.x = + screen_margin  - hud_width
		$VBoxContainer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		
		# 3. Snap Background to match VBox
		if bg:
			bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			bg.position = $VBoxContainer.position
			bg.size = $VBoxContainer.size
			bg.grow_horizontal = Control.GROW_DIRECTION_BEGIN

		# 4. Align Text & Bars
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		if hp_bar: hp_bar.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
		if sp_bar: sp_bar.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
		
		# 5. Position Portrait (To the LEFT of the VBox)
		if portrait:
			portrait.scale.x = -1
			portrait.pivot_offset = portrait.size / 2
			portrait.position.x = $VBoxContainer.position.x - portrait.size.x - gap + offset
			
	else:
		# --- PLAYER 1 (Left Side) ---
		
		# 1. Anchor VBox to Top-Left
		$VBoxContainer.set_anchors_preset(Control.PRESET_TOP_LEFT)
		
		# 2. Position it inwards (Positive X)
		# Logic: 0 + 20 (Margin) = 20 from the left edge
		$VBoxContainer.position.x = screen_margin
		$VBoxContainer.grow_horizontal = Control.GROW_DIRECTION_END
		
		# 3. Snap Background to match VBox
		if bg:
			bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
			bg.position = $VBoxContainer.position
			bg.size = $VBoxContainer.size
			bg.grow_horizontal = Control.GROW_DIRECTION_END
			
		# 4. Align Text & Bars
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		if hp_bar: hp_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		if sp_bar: sp_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		
		# 5. Position Portrait (To the RIGHT of the VBox)
		if portrait:
			portrait.scale.x = 1
			portrait.pivot_offset = portrait.size / 2
			portrait.position.x = $VBoxContainer.position.x + hud_width + gap - offset

	# Save position for animations
	if portrait: original_pos = portrait.position

func update_stats(character: CharacterData, is_injured: bool, opportunity: int, opening: int):
	var tween = create_tween()
	tween.tween_property(hp_bar, "value", character.current_hp, 0.3).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(sp_bar, "value", character.current_sp, 0.3)
	
	hp_text.text = str(character.current_hp) + "/" + str(character.max_hp)
	sp_text.text = str(character.current_sp) + "/" + str(character.max_sp)
	
	var status_txt = ""
	if is_injured: status_txt += "[INJURED] "
	if opportunity > 0: status_txt += "[OPPORTUNITY] "
	if opening > 0: status_txt += "[OPENING: " + str(opening) + "]"
	
	status_label.text = status_txt
	if is_injured: status_label.modulate = Color.ORANGE_RED
	elif opportunity > 0: status_label.modulate = Color.YELLOW
	else: status_label.modulate = Color.WHITE

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
