extends Control

# References to UI nodes
@onready var master_slider = $CenterContainer/VBoxContainer/MasterSlider
@onready var music_slider = $CenterContainer/VBoxContainer/MusicSlider
# We use get_node_or_null for SFX just in case you haven't added it to the scene yet
@onready var sfx_slider = $CenterContainer/VBoxContainer/SFXSlider 

func _ready():
	# 1. Setup Master Slider
	_connect_slider(master_slider, "Master")
	
	# 2. Setup Music Slider
	_connect_slider(music_slider, "Music")
	
	# 3. Setup SFX Slider (Only if it exists in the scene)
	if sfx_slider:
		_connect_slider(sfx_slider, "SFX")

func _connect_slider(slider: HSlider, bus_name: String):
	# Find the index of the bus (e.g., "Music" -> 1 or 2)
	var bus_index = AudioServer.get_bus_index(bus_name)
	
	if bus_index == -1:
		print("Audio Bus not found: " + bus_name)
		return
	
	# --- FIX: FORCE SLIDER SCALE TO 0.0 - 1.0 ---
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	# --------------------------------------------
	
	# Set slider position to match current volume
	# db_to_linear converts decibels (-80 to 0) to a slider friendly 0.0 to 1.0
	slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_index))
	
	# Connect the signal
	# When slider moves, update the actual volume
	slider.value_changed.connect(func(value): 
		_on_volume_changed(bus_index, value)
	)

func _on_volume_changed(bus_index: int, value: float):
	# Convert slider (0-1) back to Decibels
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
	
	# Quality of Life: If volume is very low, actually 'Mute' it to save performance
	AudioServer.set_bus_mute(bus_index, value < 0.05)
