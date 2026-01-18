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
func configure_visuals(is_player_2: bool):
	# 1. Reset any previous scaling on the root to fix the text
	scale = Vector2(1, 1)
	
	if hp_bar: hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sp_bar: sp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Force the VBox to calculate its size so we can position things accurately
	#$VBoxContainer.reset_size()
	var vbox_width = $VBoxContainer.size.x
	#var gap = 15 # Space between bars and portrait
	
	if is_player_2:
		# --- PLAYER 2 (Right Side) ---
		# Align Text to the Right
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		# PORTRAIT: Place to the LEFT of the bars (Towards Center)
		if portrait:
			# Flip the FACE only, not the text
			portrait.scale.x = -1
			portrait.pivot_offset = portrait.size / 2
			
			# Position: To the Left of the VBox (Negative X)
			portrait.position.x = $VBoxContainer.position.x - portrait.size.x - 20
			
	else:
		# --- PLAYER 1 (Left Side) ---
		# Align Text to the Left
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# PORTRAIT: Place to the RIGHT of the bars (Towards Center)
		if portrait:
			portrait.scale.x = 1
			portrait.pivot_offset = portrait.size / 2
			
			# Position: To the Right of the VBox
			portrait.position.x = $VBoxContainer.position.x + vbox_width + 10

	# Update original position for animations
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
