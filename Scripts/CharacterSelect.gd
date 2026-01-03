extends Control

@onready var p1_option = $HBoxContainer/P1_Column/ClassOption
@onready var p1_info = $HBoxContainer/P1_Column/InfoLabel
@onready var p2_option = $HBoxContainer/P2_Column/ClassOption
@onready var p2_info = $HBoxContainer/P2_Column/InfoLabel

# New Buttons
@onready var btn_quick = $HBoxContainer/Center_Column/QuickFightButton
@onready var btn_custom = $HBoxContainer/Center_Column/CustomDeckButton
@onready var btn_back = $HBoxContainer/Center_Column/BackButton

var classes = ["Heavy", "Patient", "Quick", "Technical"]

func _ready():
	_setup_options(p1_option)
	_setup_options(p2_option)
	
	# Default selections
	p1_option.selected = 0
	p2_option.selected = 1
	_update_info()
	
	p1_option.item_selected.connect(func(_idx): _update_info())
	p2_option.item_selected.connect(func(_idx): _update_info())
	
	# --- BUTTON CONNECTIONS ---
	btn_quick.pressed.connect(_on_quick_fight_pressed)
	btn_custom.pressed.connect(_on_custom_deck_pressed)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn"))

func _setup_options(opt: OptionButton):
	opt.clear()
	for c in classes:
		opt.add_item(c)

func _update_info():
	_display_stats(p1_option.selected, p1_info)
	_display_stats(p2_option.selected, p2_info)

func _display_stats(idx: int, label: RichTextLabel):
	var temp = ClassFactory.create_character(idx, "Temp")
	var txt = "[b]HP:[/b] " + str(temp.max_hp) + "\n"
	txt += "[b]SP:[/b] " + str(temp.max_sp) + "\n"
	txt += "[b]Speed:[/b] " + str(temp.speed) + "\n\n"
	txt += "[color=yellow]" + temp.passive_desc + "[/color]"
	label.text = txt

# --- OPTION 1: QUICK FIGHT (Standard Decks) ---
func _on_quick_fight_pressed():
	# Generate actual data using the Factory defaults
	var p1 = ClassFactory.create_character(p1_option.selected, "Player 1")
	var p2 = ClassFactory.create_character(p2_option.selected, "Player 2")
	
	# Store in Manager
	GameManager.next_match_p1_data = p1
	GameManager.next_match_p2_data = p2
	
	# Go straight to Combat
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")

# --- OPTION 2: CUSTOM DECK (Skill Tree) ---
func _on_custom_deck_pressed():
	# 1. Store the CLASS choice so the Tree knows where to start
	GameManager.temp_p1_class_selection = p1_option.selected
	
	# 2. Pre-generate Player 2 (The Bot) and store it for later
	var p2 = ClassFactory.create_character(p2_option.selected, "Player 2")
	GameManager.next_match_p2_data = p2
	
	# 3. Load the Action Tree
	get_tree().change_scene_to_file("res://Scenes/ActionTree.tscn")
