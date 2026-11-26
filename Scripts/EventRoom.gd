extends Control

const EVENT_IDS: Array[String] = [
	"medic",
	"bookie",
	"sensei",
	"scrap_dealer",
	"rival_locker",
]

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var desc_label: RichTextLabel = $VBoxContainer/DescriptionLabel
@onready var btn_a: Button = $VBoxContainer/OptionA
@onready var btn_b: Button = $VBoxContainer/OptionB
@onready var btn_c: Button = $VBoxContainer/OptionC

var current_event_id: String = ""
var _event_resolved: bool = false


func _ready() -> void:
	current_event_id = EVENT_IDS.pick_random()
	_load_event(current_event_id)

	btn_a.pressed.connect(func() -> void: _on_option_selected(1))
	btn_b.pressed.connect(func() -> void: _on_option_selected(2))
	btn_c.pressed.connect(func() -> void: _on_option_selected(3))

	for btn: Button in [btn_a, btn_b, btn_c]:
		btn.mouse_entered.connect(func() -> void: AudioManager.play_sfx("ui_hover", 0.2))


func _load_event(id: String) -> void:
	match id:
		"medic":
			title_label.text = "THE BACK-ALLEY MEDIC"
			desc_label.text = "A shady doctor leans out of a doorway. [i]'Rough fight, champ? I can patch you up. Or, if you're feeling brave, I have some experimental supplements you can try.'[/i]"
			btn_a.text = "PATCH UP (Heal 3 HP)"
			btn_b.text = "TAKE SUPPLEMENTS (+1 Max SP, start next fight Injured)"
			btn_c.text = "WALK AWAY (Nothing happens)"

		"bookie":
			title_label.text = "THE UNDERGROUND BOOKIE"
			desc_label.text = "A slick promoter flashes a stack of Circuit chips behind the arena bleachers. [i]'Odds are against you next round. Want to bet on yourself — or buy a look at the bracket?'[/i]"
			btn_a.text = "BET ON YOURSELF (+3 Circuit Tokens, start next fight Injured)"
			btn_b.text = "BUY BRACKET INTEL (+1 Reward Reroll for this run)"
			btn_c.text = "PASS (Walk away cleanly)"

		"sensei":
			title_label.text = "THE WANDERING SENSEI"
			desc_label.text = "An old martial artist watches you warm up in silence. [i]'Your stance has potential, fighter. Sweat now, or breathe — choose your discipline.'[/i]"
			btn_a.text = "SPARRING DRILL (+1 Max HP, lose 2 current HP)"
			btn_b.text = "BREATHING MEDITATION (+1 Max SP, lose 1 current HP)"
			btn_c.text = "BOW & REST (Heal 2 HP)"

		"scrap_dealer":
			title_label.text = "THE SCRAP DEALER"
			desc_label.text = "A hooded tinkerer pops open a crate of battle-worn gear. [i]'No refunds. Pay in blood for a mystery piece of kit, or trade a bruise for Circuit Tokens.'[/i]"
			btn_a.text = "MYSTERY GEAR (Random unowned Equipment, lose 3 current HP)"
			btn_b.text = "QUICK TRADE (+2 Circuit Tokens, lose 1 current HP)"
			btn_c.text = "LEAVE (Keep your health)"

		"rival_locker":
			title_label.text = "THE RIVAL'S LOCKER"
			desc_label.text = "You spot an unlocked locker packed with high-grade training supplies — nobody's around."
			btn_a.text = "GRAB STAMINA SERUM (+1 Max SP if HP > 2, else Heal 2 HP)"
			btn_b.text = "GRAB IRON SUPPLEMENTS (+1 Max HP)"
			btn_c.text = "LEAVE IT ALONE (+1 Circuit Token for sportsmanship)"


func _on_option_selected(choice: int) -> void:
	AudioManager.play_sfx("ui_click")

	if _event_resolved:
		_finish_event()
		return

	var p1: CharacterData = RunManager.player_run_data
	if p1 == null:
		_show_outcome("No active run data found.")
		return

	var outcome: String = ""

	match current_event_id:
		"medic":
			match choice:
				1:
					var before: int = p1.current_hp
					p1.current_hp = mini(p1.current_hp + 3, p1.max_hp)
					outcome = "The medic patches your bruises. Restored [color=#66ff99]+%d HP[/color] (%d/%d)." % [p1.current_hp - before, p1.current_hp, p1.max_hp]
				2:
					var drugs: EquipmentData = EquipmentData.new()
					drugs.item_name = "Experimental Supplements"
					drugs.description = "+1 Max SP. Side effects include sweating and tunnel vision."
					drugs.bonus_max_sp = 1
					p1.equipment.append(drugs)
					p1.max_sp += 1
					p1.current_sp = p1.max_sp
					RunManager.next_fight_statuses.append("Injured")
					outcome = "Your pulse spikes! Gained [color=#66ccff]+1 Max SP[/color] (now %d), but you'll start your next fight [color=#ff7777]Injured[/color]." % p1.max_sp
				3:
					outcome = "You keep walking and save your luck for the ring."

		"bookie":
			match choice:
				1:
					RunManager.add_circuit_tokens(3)
					RunManager.next_fight_statuses.append("Injured")
					outcome = "The bookie pays out upfront! Gained [color=#ffcc44]+3 Circuit Tokens[/color], but the pressure leaves you [color=#ff7777]Injured[/color] next fight."
				2:
					RunManager.current_rerolls += 1
					outcome = "You study the scouting sheets. Gained [color=#66ccff]+1 Reward Reroll[/color] (total: %d)." % RunManager.current_rerolls
				3:
					outcome = "You wave the bookie off and head back to the bracket."

		"sensei":
			match choice:
				1:
					p1.max_hp += 1
					p1.current_hp = maxi(1, p1.current_hp - 2)
					outcome = "Brutal sparring pays off! Gained [color=#66ff99]+1 Max HP[/color] (now %d/%d)." % [p1.current_hp, p1.max_hp]
				2:
					p1.max_sp += 1
					p1.current_sp = p1.max_sp
					p1.current_hp = maxi(1, p1.current_hp - 1)
					outcome = "Your focus sharpens. Gained [color=#66ccff]+1 Max SP[/color] (now %d) at the cost of 1 HP (%d/%d)." % [p1.max_sp, p1.current_hp, p1.max_hp]
				3:
					var before: int = p1.current_hp
					p1.current_hp = mini(p1.current_hp + 2, p1.max_hp)
					outcome = "You share a quiet moment of recovery. Restored [color=#66ff99]+%d HP[/color] (%d/%d)." % [p1.current_hp - before, p1.current_hp, p1.max_hp]

		"scrap_dealer":
			match choice:
				1:
					p1.current_hp = maxi(1, p1.current_hp - 3)
					var reward_eq: EquipmentData = _pick_unowned_equipment(p1)
					if reward_eq != null:
						p1.equipment.append(reward_eq)
						p1.max_hp = maxi(1, p1.max_hp + reward_eq.bonus_max_hp)
						p1.max_sp = maxi(1, p1.max_sp + reward_eq.bonus_max_sp)
						p1.current_hp = mini(p1.current_hp, p1.max_hp)
						p1.current_sp = p1.max_sp
						outcome = "You dig out [color=#ffcc44]%s[/color] (%s)! Current HP: %d/%d." % [reward_eq.item_name, reward_eq.description, p1.current_hp, p1.max_hp]
					else:
						RunManager.add_circuit_tokens(4)
						outcome = "You already own everything in the crate! The dealer hands you [color=#ffcc44]+4 Circuit Tokens[/color] instead."
				2:
					p1.current_hp = maxi(1, p1.current_hp - 1)
					RunManager.add_circuit_tokens(2)
					outcome = "Deal struck. Gained [color=#ffcc44]+2 Circuit Tokens[/color] (HP: %d/%d)." % [p1.current_hp, p1.max_hp]
				3:
					outcome = "You pass on the shady crate and keep moving."

		"rival_locker":
			match choice:
				1:
					if p1.current_hp > 2:
						p1.max_sp += 1
						p1.current_sp = p1.max_sp
						outcome = "You pocket the stamina serum. Gained [color=#66ccff]+1 Max SP[/color] (now %d)!" % p1.max_sp
					else:
						var before: int = p1.current_hp
						p1.current_hp = mini(p1.current_hp + 2, p1.max_hp)
						outcome = "Running low on health, you grab the medkit instead. Restored [color=#66ff99]+%d HP[/color] (%d/%d)." % [p1.current_hp - before, p1.current_hp, p1.max_hp]
				2:
					p1.max_hp += 1
					p1.current_hp = mini(p1.current_hp + 1, p1.max_hp)
					outcome = "Solid iron supplements! Gained [color=#66ff99]+1 Max HP[/color] (%d/%d)." % [p1.current_hp, p1.max_hp]
				3:
					RunManager.add_circuit_tokens(1)
					outcome = "You shut the locker cleanly. A passing official nods and tosses you [color=#ffcc44]+1 Circuit Token[/color]."

	RunManager.check_danger_state()
	RunManager.save_run()
	_show_outcome(outcome)


func _show_outcome(text: String) -> void:
	_event_resolved = true
	desc_label.text = text
	btn_a.text = "CONTINUE TO MAP"
	btn_b.visible = false
	btn_c.visible = false


func _finish_event() -> void:
	if RunManager.tournament_map.size() > 0:
		RunManager.advance_map()
	else:
		SceneLoader.change_scene("res://Scenes/TournamentMap.tscn")


func _pick_unowned_equipment(p1: CharacterData) -> EquipmentData:
	var all_items: Array[EquipmentData] = RunManager.get_all_equipment()
	var owned_names: Array[String] = []
	for eq: EquipmentData in p1.equipment:
		if eq:
			owned_names.append(eq.item_name)
	var unowned: Array[EquipmentData] = []
	for item: EquipmentData in all_items:
		if item and item.item_name not in owned_names:
			unowned.append(item)
	if unowned.is_empty():
		return null
	return unowned.pick_random()
