extends Control

@onready var name_label = $VBoxContainer/NameLabel
@onready var hp_bar = $VBoxContainer/HPBar
@onready var hp_text = $VBoxContainer/HPBar/HPLabel
@onready var sp_bar = $VBoxContainer/SPBar
@onready var sp_text = $VBoxContainer/SPBar/SPLabel
@onready var status_label = $VBoxContainer/StatusLabel

func setup(character: CharacterData):
	name_label.text = character.character_name
	hp_bar.max_value = character.max_hp
	hp_bar.value = character.current_hp
	hp_text.text = str(character.current_hp) + "/" + str(character.max_hp)
	
	sp_bar.max_value = character.max_sp
	sp_bar.value = character.current_sp
	sp_text.text = str(character.current_sp) + "/" + str(character.max_sp)

# Call this every time stats change
func update_stats(character: CharacterData, is_injured: bool, opportunity: int, opening: int):
	# Animate bars for "juice"
	var tween = create_tween()
	tween.tween_property(hp_bar, "value", character.current_hp, 0.3).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(sp_bar, "value", character.current_sp, 0.3)
	
	hp_text.text = str(character.current_hp) + "/" + str(character.max_hp)
	sp_text.text = str(character.current_sp) + "/" + str(character.max_sp)
	
	# Status Text
	var status_txt = ""
	if is_injured: status_txt += "[INJURED] "
	if opportunity > 0: status_txt += "[OPPORTUNITY] "
	if opening > 0: status_txt += "[OPENING: " + str(opening) + "]"
	
	status_label.text = status_txt
	# Make status red if injured, yellow if opportunity, etc. (Optional styling)
	if is_injured: status_label.modulate = Color.ORANGE_RED
	elif opportunity > 0: status_label.modulate = Color.YELLOW
	else: status_label.modulate = Color.WHITE
