extends Control

# References to UI nodes
@onready var master_slider = $CenterContainer/VBoxContainer/MasterSlider
@onready var music_slider = $CenterContainer/VBoxContainer/MusicSlider
# We use get_node_or_null for SFX just in case you haven't added it to the scene yet
@onready var sfx_slider = $CenterContainer/VBoxContainer/SFXSlider 

func _ready():
	# Use the Manager to initialize sliders
	_setup_slider(master_slider, "Master")
	_setup_slider(music_slider, "Music")
	
	if sfx_slider:
		_setup_slider(sfx_slider, "SFX")

func _setup_slider(slider: HSlider, bus_name: String):
	# 1. Visual Configuration
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	
	# 2. Get Initial Value from Manager (Correctly synced with save file)
	slider.value = SettingsManager.get_saved_volume(bus_name)
	
	# 3. Connect Signal
	# When slider moves -> Tell Manager to Update & Save
	slider.value_changed.connect(func(val): 
		SettingsManager.update_volume(bus_name, val)
	)

func _on_volume_changed(bus_index: int, value: float):
	# Convert slider (0-1) back to Decibels
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
	
	# Quality of Life: If volume is very low, actually 'Mute' it to save performance
	AudioServer.set_bus_mute(bus_index, value < 0.05)
