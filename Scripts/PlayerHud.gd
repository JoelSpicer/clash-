extends Control

# UPDATED PATHS: We now go through Background/MarginContainer
@onready var background = $Background
@onready var vbox = $Background/MarginContainer/VBoxContainer

@onready var name_label = $Background/MarginContainer/VBoxContainer/NameLabel

# HP References
@onready var hp_bar = $Background/MarginContainer/VBoxContainer/HPBarHolder/HPBar
@onready var hp_ghost = $Background/MarginContainer/VBoxContainer/HPBarHolder/HPGhost
@onready var hp_text = $Background/MarginContainer/VBoxContainer/HPBarHolder/HPBar/HPLabel

# SP References
@onready var sp_bar = $Background/MarginContainer/VBoxContainer/SPBarHolder/SPBar
@onready var sp_ghost = $Background/MarginContainer/VBoxContainer/SPBarHolder/SPGhost
@onready var sp_text = $Background/MarginContainer/VBoxContainer/SPBarHolder/SPBar/SPLabel

@onready var status_container = $Background/MarginContainer/VBoxContainer/StatusContainer
@onready var portrait = get_node_or_null("Portrait")

var original_pos: Vector2 = Vector2.ZERO

func _ready():
	if portrait: original_pos = portrait.position
	
	if hp_ghost:
		hp_ghost.max_value = hp_bar.max_value
		hp_ghost.value = hp_bar.value
	if sp_ghost:
		sp_ghost.max_value = sp_bar.max_value
		sp_ghost.value = sp_bar.value

func setup(character: CharacterData):
	name_label.text = character.character_name
	
	hp_bar.max_value = character.max_hp
	hp_bar.value = character.current_hp
	if hp_ghost:
		hp_ghost.max_value = character.max_hp
		hp_ghost.value = character.current_hp
	hp_text.text = str(character.current_hp) + "/" + str(character.max_hp)
	
	sp_bar.max_value = character.max_sp
	sp_bar.value = character.current_sp
	if sp_ghost:
		sp_ghost.max_value = character.max_sp
		sp_ghost.value = character.current_sp
	sp_text.text = str(character.current_sp) + "/" + str(character.max_sp)
	
	if portrait and character.portrait:
		portrait.texture = character.portrait

func configure_visuals(is_player_2: bool):
	scale = Vector2(1, 1)
	var hud_width = 300 
	var screen_margin = 20
	var gap = 15
	var offset = 150
	
	# We size the Content Wrapper (Background), not the VBox directly
	# The VBox will conform to this size minus margins
	background.custom_minimum_size.x = hud_width
	background.size.x = hud_width 
	
	if is_player_2:
		# Anchor the BACKGROUND, not the VBox
		background.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		background.position.x = + screen_margin - hud_width
		background.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_container.alignment = BoxContainer.ALIGNMENT_END
		
		if hp_bar: hp_bar.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
		if hp_ghost: hp_ghost.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
		if sp_bar: sp_bar.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
		if sp_ghost: sp_ghost.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
		
		if portrait:
			portrait.scale.x = -1
			portrait.pivot_offset = portrait.size / 2
			# Calculate portrait pos relative to the BACKGROUND
			portrait.position.x = background.position.x - portrait.size.x - gap + offset
	else:
		background.set_anchors_preset(Control.PRESET_TOP_LEFT)
		background.position.x = screen_margin
		background.grow_horizontal = Control.GROW_DIRECTION_END
		
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		status_container.alignment = BoxContainer.ALIGNMENT_BEGIN
		
		if hp_bar: hp_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		if hp_ghost: hp_ghost.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		if sp_bar: sp_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		if sp_ghost: sp_ghost.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
		
		if portrait:
			portrait.scale.x = 1
			portrait.pivot_offset = portrait.size / 2
			portrait.position.x = background.position.x + hud_width + gap - offset

	if portrait: original_pos = portrait.position

# ... (Keep update_stats, _update_status_icons, animations as they were) ...
func update_stats(character: CharacterData, opportunity: int, opening: int, bide_active: bool):
	hp_text.text = str(character.current_hp) + "/" + str(character.max_hp)
	sp_text.text = str(character.current_sp) + "/" + str(character.max_sp)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(hp_bar, "value", character.current_hp, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	
	if hp_ghost:
		if character.current_hp < hp_ghost.value:
			var t = create_tween()
			t.tween_interval(0.4)
			t.tween_property(hp_ghost, "value", character.current_hp, 0.6).set_trans(Tween.TRANS_SINE)
		else:
			hp_ghost.value = character.current_hp

	tween.tween_property(sp_bar, "value", character.current_sp, 0.2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	
	if sp_ghost:
		if character.current_sp < sp_ghost.value:
			var t = create_tween()
			t.tween_interval(0.4)
			t.tween_property(sp_ghost, "value", character.current_sp, 0.6).set_trans(Tween.TRANS_SINE)
		else:
			sp_ghost.value = character.current_sp

	_update_status_icons(character, opportunity, opening, bide_active)

func _update_status_icons(character, opportunity, opening, bide_active):
	for child in status_container.get_children():
		child.queue_free()
		
	if bide_active: 
		_add_icon("Bide", "Bide: +1 Damage on next hit", Color(0.3, 1.0, 1.0))
	if opportunity > 0:
		_add_icon("Opportunity", "Opportunity: Next attack costs " + str(opportunity) + " less SP", Color.YELLOW)
	if opening > 0:
		_add_icon("Opening", "Opening Lvl " + str(opening) + ": Vulnerable to Counters", Color.ORANGE)

	for s_name in character.statuses:
		_add_icon(s_name, s_name, Color.WHITE)

func _add_icon(icon_name: String, tooltip: String, tint: Color):
	var icon = TextureRect.new()
	var path = "res://Art/Icons/icon_" + icon_name + ".png"
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	else:
		var placeholder = GradientTexture2D.new()
		placeholder.width = 24
		placeholder.height = 24
		placeholder.fill_from = Vector2(0,0)
		placeholder.fill_to = Vector2(1,1)
		icon.texture = placeholder
		icon.modulate = tint
	
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.tooltip_text = tooltip
	status_container.add_child(icon)

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
