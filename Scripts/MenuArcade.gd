extends Control

# --- UI REFERENCES ---
@onready var class_grid = $MarginContainer/VBoxContainer/HBoxContainer/ClassScroll/ClassList
@onready var info_label = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/InfoLabel
@onready var portrait_rect = $MarginContainer/VBoxContainer/HBoxContainer/P1_Column/P1_Portrait

# Settings
@onready var difficulty_option = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/DifficultyOption
@onready var maintain_hp_toggle = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/MaintainHPToggle
@onready var start_btn = $MarginContainer/VBoxContainer/HBoxContainer/Settings_Column/StartButton

# --- DATA ---
@export var base_classes: Array[ClassDefinition]

# --- STATE ---
var selected_index: int = 0
var buttons: Array[Button] = []

func _ready():
	_setup_difficulty()
	_generate_class_grid()
	
	# Connect Start
	start_btn.pressed.connect(_on_start_pressed)
	
	# Select first class by default
	_select_class(0)

# --- NEW: GRID GENERATION ---
func _generate_class_grid():
	# Clear old children
	for child in class_grid.get_children():
		child.queue_free()
	buttons.clear()
	
	for i in range(base_classes.size()):
		var def = base_classes[i]
		_create_grid_button(i, def)

func _create_grid_button(index: int, def: ClassDefinition):
	var btn = Button.new()
	
	# 1. VISUAL SETUP (The Fighting Game Look)
	btn.text = def.class_named
	btn.icon = def.portrait
	btn.expand_icon = true
	
	# Layout: Icon on Top, Text on Bottom
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	
	# Size: A nice square/rectangle card
	btn.custom_minimum_size = Vector2(140, 160)
	
	# Clip text if it's too long
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.clip_text = true
	
	# 2. SIGNALS
	btn.mouse_entered.connect(func(): _on_class_hover(index))
	btn.pressed.connect(func(): _select_class(index))
	
	class_grid.add_child(btn)
	buttons.append(btn)

# --- INTERACTION ---
func _on_class_hover(index: int):
	AudioManager.play_sfx("ui_hover", 0.1)
	_update_preview_panel(index)

func _select_class(index: int):
	AudioManager.play_sfx("ui_click")
	selected_index = index
	
	# Visual Feedback: Highlight the border/text of the selected character
	for i in range(buttons.size()):
		var btn = buttons[i]
		if i == index:
			# Selected Style: Green Text, maybe Modulate slightly?
			btn.add_theme_color_override("font_color", Color.GREEN)
			btn.modulate = Color(1.2, 1.2, 1.2) # Brighten
		else:
			# Normal Style
			btn.remove_theme_color_override("font_color")
			btn.modulate = Color.WHITE
			
	_update_preview_panel(index)

func _update_preview_panel(index: int):
	if index >= base_classes.size(): return
	var data = base_classes[index]
	
	# --- MIDDLE COLUMN: DESCRIPTION ONLY ---
	# (As requested, this focuses on the description/stats)
	
	var txt = "[center][b][font_size=28]" + data.class_named + "[/font_size][/b][/center]\n"
	
	# Playstyle Summary
	if data.playstyle_summary != "":
		txt += "[center][i][color=light_gray]" + data.playstyle_summary + "[/color][/i][/center]\n\n"
	
	# Stats Block
	txt += "[b]HP:[/b] " + str(data.base_hp) + "   [b]SP:[/b] " + str(data.base_sp) + "\n"
	txt += "[b]Speed:[/b] " + str(data.base_speed) + "\n"
	txt += "----------------\n"
	
	# Passive
	txt += "[color=yellow]" + data.passive_description + "[/color]"
	
	info_label.text = txt
	
	# Big Portrait (Optional: You can hide this if you ONLY want text in the middle)
	if portrait_rect:
		portrait_rect.texture = data.portrait

# --- START RUN ---
func _on_start_pressed():
	AudioManager.play_sfx("ui_confirm")
	
	RunManager.maintain_hp_enabled = maintain_hp_toggle.button_pressed
	
	if selected_index < base_classes.size():
		RunManager.start_new_run(base_classes[selected_index])

# --- SETTINGS HELPERS ---
func _setup_difficulty():
	difficulty_option.clear()
	difficulty_option.add_item("Very Easy")
	difficulty_option.add_item("Easy")
	difficulty_option.add_item("Medium")
	difficulty_option.add_item("Hard")
	difficulty_option.selected = 2 # Medium
	
	if not difficulty_option.item_selected.is_connected(_on_difficulty_changed):
		difficulty_option.item_selected.connect(_on_difficulty_changed)

func _on_difficulty_changed(index: int):
	GameManager.ai_difficulty = index as GameManager.Difficulty
