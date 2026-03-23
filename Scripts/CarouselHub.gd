extends Control

# --- CONFIGURATION ---
var slides: Array = []
var current_index: int = 0
var is_transitioning: bool = false

# --- TUTORIAL DATA ---
const TUTORIAL_TEXTS = [
	{
		"title": "WELCOME TO THE CIRCUIT",
		"text": "This is the main roguelike mode. Choose your fighter's class, set your difficulty, optionally select a sponsor to alter your stats and gameplay, and battle your way through a gauntlet of opponents. Draft new Actions, Equipment and Buffs as you climb the ranks, gaining circuit tokens to unlock more classes and sponsors!"
	},
	{
		"title": "NETWORK TERMINAL",
		"text": "Spend the Circuit Tokens you earn from your runs here. You can unlock new Sponsors, Classes, and powerful permanent upgrades to aid you in future runs."
	},
	{
		"title": "GAME SETTINGS",
		"text": "Adjust your Audio and Visual preferences here. You can also access Debug tools if you need to reset your save data or grant yourself tokens."
	},
	{
		"title": "COMPENDIUM",
		"text": "Your ultimate knowledge base. Review the core rules of combat, look up what specific traits do, and browse the entire library of available Action cards."
	}
]

# --- NODES ---
@onready var bg_current = $Background
@onready var bg_fader = $BackgroundFader
@onready var content_container = $ContentContainer
@onready var title_label = $UI_Layer/TitleLabel
@onready var btn_left = $UI_Layer/LeftArrow
@onready var btn_right = $UI_Layer/RightArrow
@onready var btn_back = $UI_Layer/BackButton

# --- PARALLAX SETTINGS ---
var max_parallax: float = 25.0        # How many pixels it can move in any direction
var parallax_smoothness: float = 4.0  # How "heavy/smooth" the movement feels
var base_bg_pos: Vector2 = Vector2.ZERO

# Tutorial Dynamic Nodes
var tut_layer: CanvasLayer
var tut_overlay: ColorRect
var tut_title: Label
var tut_panel: PanelContainer
var tut_desc: RichTextLabel
var help_btn: Button

func _ready():
	slides = [
		{
			"title": "THE CIRCUIT",
			"scene_path": "res://Scenes/MenuArcade.tscn",
			"bg_path": "res://Art/Background/LockerRoom.png"
		},
		{
			"title": "NETWORK TERMINAL",
			"scene_path": "res://Scenes/ShopTerminal.tscn",
			"bg_path": "res://Art/Background/Library.png"
		},
		{
			"title": "GAME SETTINGS",
			"scene_path": "res://Scenes/MenuSettings.tscn",
			"bg_path": "res://Art/Background/Dojo.png"
		},
		{
			"title": "COMPENDIUM",
			"scene_path": "res://Scenes/compendium.tscn", 
			"bg_path": "res://Art/Background/Street.png"
		}
	]
	
	btn_left.pressed.connect(func(): _change_slide(-1))
	btn_right.pressed.connect(func(): _change_slide(1))
	btn_back.pressed.connect(_on_back_pressed)
	
	# --- SETUP PARALLAX VISUALS ---
	# Wait one frame to ensure Godot has calculated the screen size
	await get_tree().process_frame 
	var screen_size = get_viewport_rect().size
	
	# Set the pivot to the center so it scales outward uniformly
	bg_current.pivot_offset = screen_size / 2.0
	bg_fader.pivot_offset = screen_size / 2.0
	
	# Scale it up slightly so when it moves, we don't see the edges!
	bg_current.scale = Vector2(1.05, 1.05)
	bg_fader.scale = Vector2(1.05, 1.05)
	
	# Store the baseline position (usually 0,0)
	base_bg_pos = bg_current.position
	# ------------------------------
	
	
	_setup_tutorial_ui()
	
	_load_slide_content(0)
	_snap_background(0)
	
	# Check for tutorial on the very first screen load
	_check_and_show_tutorial(0)

func _process(delta):
	# 1. Get current screen size and mouse position
	var screen_size = get_viewport_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	var center = screen_size / 2.0
	
	# 2. Calculate offset (Returns a value between -1.0 and 1.0)
	var offset_x = (mouse_pos.x - center.x) / center.x
	var offset_y = (mouse_pos.y - center.y) / center.y
	var mouse_offset = Vector2(offset_x, offset_y)
	
	# 3. Multiply by max distance and invert it (Negative moves OPPOSITE the mouse)
	var target_pos = base_bg_pos - (mouse_offset * max_parallax)
	
	# 4. Smoothly interpolate (lerp) to the target position
	bg_current.position = bg_current.position.lerp(target_pos, delta * parallax_smoothness)
	bg_fader.position = bg_fader.position.lerp(target_pos, delta * parallax_smoothness)

func _change_slide(direction: int):
	if is_transitioning: return
	is_transitioning = true
	AudioManager.play_sfx("ui_hover", 0.5) 
	
	current_index += direction
	if current_index >= slides.size(): current_index = 0
	elif current_index < 0: current_index = slides.size() - 1
	
	var slide_data = slides[current_index]
	title_label.text = slide_data.title
	
	# A. Crossfade Background
	var new_bg = load(slide_data.bg_path)
	if new_bg:
		bg_fader.texture = new_bg
		bg_fader.modulate.a = 0.0
		bg_fader.visible = true 
		var t_bg = create_tween()
		t_bg.tween_property(bg_fader, "modulate:a", 1.0, 0.4)
		await t_bg.finished
		bg_current.texture = new_bg
		bg_fader.modulate.a = 0.0
	
	# B. Slide Content
	var old_content = content_container.get_child(0) if content_container.get_child_count() > 0 else null
	var new_scene = load(slide_data.scene_path).instantiate()
	
	var screen_width = get_viewport_rect().size.x
	var enter_pos = Vector2(screen_width, 0) if direction > 0 else Vector2(-screen_width, 0)
	var exit_pos = Vector2(-screen_width, 0) if direction > 0 else Vector2(screen_width, 0)
	
	new_scene.position = enter_pos
	content_container.add_child(new_scene)
	
	var t_slide = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t_slide.tween_property(new_scene, "position", Vector2.ZERO, 0.4)
	if old_content:
		t_slide.tween_property(old_content, "position", exit_pos, 0.4)
	
	await t_slide.finished
	if old_content: old_content.queue_free()
	is_transitioning = false
	
	# Check for tutorial AFTER the slide finishes moving
	_check_and_show_tutorial(current_index)

func _load_slide_content(idx: int):
	var data = slides[idx]
	title_label.text = data.title
	for child in content_container.get_children():
		child.queue_free()
	var scene = load(data.scene_path).instantiate()
	content_container.add_child(scene)

func _snap_background(idx: int):
	var tex = load(slides[idx].bg_path)
	if tex: bg_current.texture = tex

func _on_back_pressed():
	SceneLoader.change_scene("res://Scenes/MainMenu.tscn")

# =========================================================
# TUTORIAL SYSTEM
# =========================================================

func _setup_tutorial_ui():
	# 1. Add Help Button to UI Layer
	help_btn = Button.new()
	help_btn.text = "?"
	$UI_Layer.add_child(help_btn)
	
	# --- FIX 2: PRECISE BUTTON PLACEMENT ---
	help_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	help_btn.offset_left = -80  # Pull it 80 pixels left from the right edge
	help_btn.offset_top = 20    # Push it 20 pixels down from the top edge
	help_btn.offset_right = -40 # Make it 40 pixels wide
	help_btn.offset_bottom = 60 # Make it 40 pixels tall
	help_btn.pressed.connect(_show_current_tutorial)
	
	# 2. Setup CanvasLayer so Popup is always on top
	tut_layer = CanvasLayer.new()
	tut_layer.layer = 100
	add_child(tut_layer)
	
	# 3. Setup Dimmed Overlay
	tut_overlay = ColorRect.new()
	tut_overlay.color = Color(0, 0, 0, 0.85)
	tut_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	tut_overlay.hide()
	tut_layer.add_child(tut_overlay)
	
	# --- FIX 1: CENTER CONTAINER ---
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	tut_overlay.add_child(center_container)
	
	# 4. Setup Popup Panel
	tut_panel = PanelContainer.new()
	tut_panel.custom_minimum_size = Vector2(500, 300)
	center_container.add_child(tut_panel)
	# -------------------------------
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.6, 1.0)
	style.set_corner_radius_all(8)
	tut_panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	tut_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	tut_title = Label.new()
	tut_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tut_title.add_theme_font_size_override("font_size", 24)
	tut_title.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(tut_title)
	
	tut_desc = RichTextLabel.new()
	tut_desc.bbcode_enabled = true
	tut_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tut_desc)
	
	var close_btn = Button.new()
	close_btn.text = "GOT IT"
	close_btn.custom_minimum_size = Vector2(150, 50)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): 
		AudioManager.play_sfx("ui_click")
		_hide_tutorial() # Call the new hide animation!
	)
	vbox.add_child(close_btn)

func _check_and_show_tutorial(idx: int):
	if not RunManager.meta_data: return
	
	var menu_key = slides[idx].title
	if not RunManager.meta_data.seen_menu_tutorials.has(menu_key):
		RunManager.meta_data.seen_menu_tutorials[menu_key] = true
		RunManager._save_global_data()
		_show_current_tutorial()

func _show_current_tutorial():
	AudioManager.play_sfx("ui_confirm")
	var data = TUTORIAL_TEXTS[current_index]
	
	tut_title.text = data.title
	tut_desc.text = "[center]" + data.text + "[/center]"
	
	# --- FIX 3: POP-IN ANIMATION ---
	tut_overlay.show()
	tut_overlay.modulate.a = 0.0
	
	# Wait 1 frame so the panel can calculate its true size
	await get_tree().process_frame
	
	# Set pivot to the center so it scales outward
	tut_panel.pivot_offset = tut_panel.size / 2
	tut_panel.scale = Vector2(0.5, 0.5)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(tut_overlay, "modulate:a", 1.0, 0.2)
	tween.tween_property(tut_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_tutorial():
	# --- FIX 3: POP-OUT ANIMATION ---
	tut_panel.pivot_offset = tut_panel.size / 2
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(tut_overlay, "modulate:a", 0.0, 0.2)
	tween.tween_property(tut_panel, "scale", Vector2(0.8, 0.8), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Wait for the animation to finish before hiding the node entirely
	tween.chain().tween_callback(tut_overlay.hide)
