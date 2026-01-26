extends Control

@onready var title_label = $VBoxContainer/TitleLabel
@onready var desc_label = $VBoxContainer/DescriptionLabel
@onready var btn_a = $VBoxContainer/OptionA
@onready var btn_b = $VBoxContainer/OptionB
@onready var btn_c = $VBoxContainer/OptionC

# The ID of the current event
var current_event_id: String = ""

func _ready():
	# For now we only have the Medic, but later we can do:
	# current_event_id = ["medic", "bookie", "zen"].pick_random()
	current_event_id = "medic" 
	
	_load_event(current_event_id)
	
	# Connect buttons to a single handler
	btn_a.pressed.connect(func(): _on_option_selected(1))
	btn_b.pressed.connect(func(): _on_option_selected(2))
	btn_c.pressed.connect(func(): _on_option_selected(3))
	
	# UI Juice
	for btn in [btn_a, btn_b, btn_c]:
		btn.mouse_entered.connect(func(): AudioManager.play_sfx("ui_hover", 0.2))

# ==============================================================================
# EVENT DEFINITIONS (Easy to expand!)
# ==============================================================================
func _load_event(id: String):
	match id:
		"medic":
			title_label.text = "THE BACK-ALLEY MEDIC"
			desc_label.text = "A shady doctor leans out of a doorway. [i]'Rough fight, champ? I can patch you up. Or, if you're feeling brave, I have some new experimental supplements you can try.'[/i]"
			btn_a.text = "PATCH UP (Heal 3 HP)"
			btn_b.text = "TAKE DRUGS (+1 Max SP, unknown side effects)"
			btn_c.text = "WALK AWAY (Nothing happens)"

# ==============================================================================
# EVENT RESOLUTION LOGIC
# ==============================================================================
func _on_option_selected(choice: int):
	AudioManager.play_sfx("ui_click")
	var p1 = RunManager.player_run_data
	
	# --- 1. RESOLVE THE MEDIC ---
	if current_event_id == "medic":
		match choice:
			1: # PATCH UP
				p1.current_hp = min(p1.current_hp + 3, p1.max_hp)
				print("Event: Healed 3 HP.")
			2: # TAKE DRUGS
				# We create a permanent piece of equipment on the fly!
				var drugs = EquipmentData.new()
				drugs.display_name = "Experimental Drugs"
				drugs.description = "Side effects include sweating and nausea."
				drugs.max_sp_bonus = 1
				p1.equipment.append(drugs)
				
				# Add the penalty for the next fight
				RunManager.next_fight_statuses.append("Injured")
				print("Event: Gained Drugs. Injured next fight.")
			3: # WALK AWAY
				print("Event: Walked away.")

	# --- 2. CLEANUP & LEAVE ---
	# Recalculate stats so the Max SP bonus applies immediately
	ClassFactory._recalculate_stats(p1)
	
	# Proceed to the Action Tree to get your card reward for the level
	SceneLoader.change_scene("res://Scenes/ActionTree.tscn")
