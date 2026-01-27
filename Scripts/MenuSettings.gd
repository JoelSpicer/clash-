extends Control

#@onready var master_slider = $CenterContainer/VBoxContainer/MasterSlider
#@onready var music_slider = $CenterContainer/VBoxContainer/MusicSlider
#@onready var sfx_slider = $CenterContainer/VBoxContainer/SFXSlider
#@onready var delete_save_btn = $CenterContainer/VBoxContainer/DeleteSaveButton
#
#func _ready():
	## 1. Set initial slider positions based on current volume
	#master_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	#music_slider.value = db_to_linear(AudioServer.get_bus_volume_db(1))
	#sfx_slider.value = db_to_linear(AudioServer.get_bus_volume_db(2))
	#
	## 2. Connect signals
	#master_slider.value_changed.connect(func(v): _set_volume(0, v))
	#music_slider.value_changed.connect(func(v): _set_volume(1, v))
	#sfx_slider.value_changed.connect(func(v): _set_volume(2, v))
	#
	#if delete_save_btn:
		#delete_save_btn.pressed.connect(_on_delete_save_pressed)
#
#func _set_volume(bus_idx: int, value: float):
	## Convert linear slider value (0-1) to Decibels
	#AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
	#
	## Optional: Mute if slider is at 0
	#AudioServer.set_bus_mute(bus_idx, value < 0.05)
#
#func _on_delete_save_pressed():
	## Simple safety confirmation could be added here later
	#var dir = DirAccess.open("user://")
	#if dir.file_exists("save_game.json"): # Or whatever you name your save
		#dir.remove("save_game.json")
		#print("Save file deleted.")
		#delete_save_btn.text = "DATA DELETED"
		#delete_save_btn.disabled = true
