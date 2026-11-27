extends Control

@onready var background: TextureRect = $Background
@onready var content: Control = $Content

@onready var flash_overlay: ColorRect = $FlashOverlay
@onready var top_bar: Control = $TopLetterbox
@onready var bottom_bar: Control = $BottomLetterbox

@onready var p1_container: Control = $Content/P1_Container
@onready var p1_portrait: TextureRect = $Content/P1_Container/Portrait
@onready var p1_name: Label = $Content/P1_Container/InfoBox/VBoxContainer/NameLabel
@onready var p1_class: Label = $Content/P1_Container/InfoBox/VBoxContainer/ClassLabel
@onready var p1_hp: Label = $Content/P1_Container/InfoBox/VBoxContainer/StatsRow/HPLabel
@onready var p1_sp: Label = $Content/P1_Container/InfoBox/VBoxContainer/StatsRow/SPLabel
@onready var p1_bubble: Label = $Content/P1_Container/PanelContainer/SpeechBubble

@onready var p2_container: Control = $Content/P2_Container
@onready var p2_portrait: TextureRect = $Content/P2_Container/Portrait
@onready var p2_name: Label = $Content/P2_Container/InfoBox/VBoxContainer/NameLabel
@onready var p2_class: Label = $Content/P2_Container/InfoBox/VBoxContainer/ClassLabel
@onready var p2_hp: Label = $Content/P2_Container/InfoBox/VBoxContainer/StatsRow/HPLabel
@onready var p2_sp: Label = $Content/P2_Container/InfoBox/VBoxContainer/StatsRow/SPLabel
@onready var p2_bubble: Label = $Content/P2_Container/PanelContainer/SpeechBubble

@onready var vs_label: Control = $Content/VsLabel
@onready var arena_label: Label = $ArenaLabel

var max_parallax: float = 20.0
var parallax_smoothness: float = 4.0
var base_bg_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	# 1. Hide things before setup
	p1_bubble.visible_ratio = 0.0 # Typewriter reset
	p2_bubble.visible_ratio = 0.0
	p1_bubble.get_parent().modulate.a = 0.0 # Reserve space, but make invisible
	p2_bubble.get_parent().modulate.a = 0.0
	flash_overlay.modulate.a = 0.0
	
	_setup_visuals()
	
	if has_node("P1_Name_Label"):
		$P1_Name_Label.text = GameManager.next_match_p1_data.character_name
		
	if has_node("P2_Name_Label"):
		$P2_Name_Label.text = GameManager.next_match_p2_data.character_name
	
	# Wait a frame to let Godot calculate the new Anchors
	await get_tree().process_frame
	
	# --- SETUP PARALLAX VISUALS ---
	if background:
		var screen_size = get_viewport_rect().size
		background.pivot_offset = screen_size / 2.0
		background.scale = Vector2(1.05, 1.05)
		base_bg_pos = background.position
	# ------------------------------
	
	_play_intro_animation()
	
	# The intro takes about 4 seconds total, load fight after 5
	await get_tree().create_timer(7.0).timeout
	SceneLoader.change_scene("res://Scenes/CombatArena.tscn")

func _setup_visuals() -> void:
	var env_name: String = GameManager.current_environment_name
	if GameManager.environment_backgrounds.has(env_name):
		background.texture = GameManager.environment_backgrounds[env_name]
	arena_label.text = "- " + env_name.to_upper() + " -"

	var p1 = GameManager.next_match_p1_data
	var p2 = GameManager.next_match_p2_data
	
	if RunManager.is_arcade_mode and RunManager.player_run_data:
		p1 = RunManager.player_run_data

	# -- Player 1 Data --
	if p1:
		if p1.portrait: p1_portrait.texture = p1.portrait
		p1_name.text = p1.character_name
		p1_class.text = CharacterData.ClassType.keys()[p1.class_type] if p1.class_type >= 0 else "UNKNOWN"
		p1_hp.text = "HP: " + str(p1.max_hp)
		p1_sp.text = "SP: " + str(p1.max_sp)

	# Show equipped player Title on local player's VS card across all game modes
	var equipped_title: String = RunManager.get_active_title()
	if equipped_title != "":
		var local_is_p2: bool = (
			multiplayer.has_multiplayer_peer()
			and not multiplayer.get_peers().is_empty()
			and multiplayer.get_unique_id() == GameManager.p2_network_id
		)
		var target_name_label: Label = p2_name if local_is_p2 else p1_name
		_set_player_title_banner(target_name_label, equipped_title)

	# -- Player 2 Data --
	if p2:
		if p2.portrait:
			p2_portrait.texture = p2.portrait
			p2_portrait.flip_h = true
		p2_name.text = p2.character_name
		
		var base_class_name: String = CharacterData.ClassType.keys()[p2.class_type] if p2.class_type >= 0 else "UNKNOWN"
		var boss_epithets: Array[String] = []
		var trait_lines: Array[String] = []
		for eq in p2.equipment:
			if eq == null:
				continue
			var epithet: Variant = eq.get("boss_epithet")
			if epithet != null and str(epithet) != "":
				boss_epithets.append(str(epithet))
			if eq.description != "":
				trait_lines.append("%s: %s" % [eq.item_name, eq.description])
			else:
				trait_lines.append(eq.item_name)
		
		if not boss_epithets.is_empty():
			p2_class.text = "BOSS — " + " / ".join(boss_epithets)
			p2_class.modulate = Color(1.0, 0.35, 0.35)
		elif p2.character_name == "THE JUGGERNAUT":
			p2_class.text = "BOSS"
			p2_class.modulate = Color.RED
		else:
			p2_class.text = base_class_name
			p2_class.modulate = Color.WHITE
		
		_set_p2_traits_banner(base_class_name, trait_lines, not boss_epithets.is_empty())
		
		p2_hp.text = "HP: " + str(p2.max_hp)
		p2_sp.text = "SP: " + str(p2.max_sp)

func _set_player_title_banner(name_lbl: Label, title_text: String) -> void:
	var info_vbox: Node = name_lbl.get_parent()
	if info_vbox == null:
		return
	var existing: Label = info_vbox.get_node_or_null("EquippedTitleLabel") as Label
	if existing == null:
		existing = Label.new()
		existing.name = "EquippedTitleLabel"
		existing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		existing.add_theme_font_size_override("font_size", 17)
		existing.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))
		existing.add_theme_color_override("font_outline_color", Color.BLACK)
		existing.add_theme_constant_override("outline_size", 3)
		info_vbox.add_child(existing)
		info_vbox.move_child(existing, name_lbl.get_index())
	existing.text = "« %s »" % title_text.to_upper()


func _set_p2_traits_banner(base_class_name: String, trait_lines: Array[String], is_boss: bool) -> void:
	var info_vbox: Node = p2_class.get_parent()
	if info_vbox == null:
		return
	var existing: Node = info_vbox.get_node_or_null("BossTraitsLabel")
	if trait_lines.is_empty():
		if existing:
			existing.queue_free()
		return
	var traits_label: Label = existing as Label
	if traits_label == null:
		traits_label = Label.new()
		traits_label.name = "BossTraitsLabel"
		traits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		traits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		traits_label.add_theme_font_size_override("font_size", 15)
		traits_label.add_theme_color_override("font_outline_color", Color.BLACK)
		traits_label.add_theme_constant_override("outline_size", 2)
		info_vbox.add_child(traits_label)
	var prefix: String = "[%s] " % base_class_name if is_boss else ""
	traits_label.text = prefix + " | ".join(trait_lines)
	traits_label.modulate = Color(1.0, 0.85, 0.45) if is_boss else Color(0.75, 0.9, 1.0)

func _play_intro_animation() -> void:
	var screen_w: float = get_viewport_rect().size.x
	
	# Reset states
	vs_label.scale = Vector2.ZERO
	p1_container.position.x = - p1_container.size.x
	p2_container.position.x = screen_w
	
	# Push letterboxes offscreen initially
	top_bar.position.y = -100
	bottom_bar.position.y = get_viewport_rect().size.y
	
	# --- PHASE 1: THE CRASH ---
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	# Characters slide in
	tween.tween_property(p1_container, "position:x", 0, 0.8)
	tween.tween_property(p2_container, "position:x", screen_w / 2, 0.8)
	
	# Cinematic bars slide in
	tween.tween_property(top_bar, "position:y", 0, 0.8)
	tween.tween_property(bottom_bar, "position:y", get_viewport_rect().size.y - 100, 0.8)
	
	# --- PHASE 2: IMPACT & FLASH (At 0.8s) ---
	tween.set_parallel(false) # Sequence mode
	tween.tween_interval(0.8)
	
	tween.tween_callback(func():
		AudioManager.play_sfx("hit_heavy")
		_shake_content(15.0, 0.5)
		
		# Flash White
		var flash_tween = create_tween()
		flash_overlay.modulate.a = 1.0
		flash_tween.tween_property(flash_overlay, "modulate:a", 0.0, 0.5)
	)
	
	# Pop the VS Label immediately after impact
	tween.tween_property(vs_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC)
	
	# --- PHASE 3: DIALOGUE FETCH ---
	var p1_data = GameManager.next_match_p1_data
	var p2_data = GameManager.next_match_p2_data
	var banter = DialogueManager.get_intro_banter(p1_data, p2_data)
	
	p1_bubble.text = banter["p1"]
	
	# --- NEW: RIVAL DIALOGUE OVERRIDE ---
	if GameManager.rival_intro_override != "":
		p2_bubble.text = GameManager.rival_intro_override
	else:
		p2_bubble.text = banter["p2"]
	# ------------------------------------
	
	# --- PHASE 4: TYPEWRITER SEQUENCE ---
	
	# Player 1 Speaks
	tween.tween_interval(0.2)
	# Fade in the background panel smoothly
	tween.tween_property(p1_bubble.get_parent(), "modulate:a", 1.0, 0.2)
	tween.tween_callback(func():
		AudioManager.play_sfx("ui_click") # Typewriter sound
	)
	tween.tween_property(p1_bubble, "visible_ratio", 1.0, 0.8).set_trans(Tween.TRANS_LINEAR)
	
	# Player 2 Speaks
	tween.tween_interval(0.5)
	# Fade in the background panel smoothly
	tween.tween_property(p2_bubble.get_parent(), "modulate:a", 1.0, 0.2)
	tween.tween_callback(func():
		AudioManager.play_sfx("ui_click")
	)
	tween.tween_property(p2_bubble, "visible_ratio", 1.0, 0.8).set_trans(Tween.TRANS_LINEAR)

# Camera Shake effect for the Content layer
func _shake_content(intensity: float, duration: float) -> void:
	var original_pos: Vector2 = content.position
	var shake_tween: Tween = create_tween()
	
	shake_tween.tween_method(func(val: float) -> void:
		var offset: Vector2 = Vector2(randf_range(-val, val), randf_range(-val, val))
		content.position = original_pos + offset
	, intensity, 0.0, duration)
	
	shake_tween.tween_callback(func() -> void: content.position = original_pos)


func _process(delta: float) -> void:
	# --- APPLY PARALLAX TO BACKGROUND ---
	if background:
		var screen_size = get_viewport_rect().size
		var mouse_pos = get_viewport().get_mouse_position()
		var center = screen_size / 2.0
		
		# Calculate offset
		var offset_x = (mouse_pos.x - center.x) / center.x
		var offset_y = (mouse_pos.y - center.y) / center.y
		var mouse_offset = Vector2(offset_x, offset_y)
		
		# Apply target position
		var target_pos = base_bg_pos - (mouse_offset * max_parallax)
		background.position = background.position.lerp(target_pos, delta * parallax_smoothness)
