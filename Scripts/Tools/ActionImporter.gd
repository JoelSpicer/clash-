@tool
extends EditorScript

const CSV_PATH = "res://Data/ALLACTIONS.csv"
const SAVE_DIR = "res://Data/Actions/"

func _run():
	if not FileAccess.file_exists(CSV_PATH):
		print("Error: Could not find " + CSV_PATH)
		return

	var file = FileAccess.open(CSV_PATH, FileAccess.READ)
	
	# Create the directory if it doesn't exist
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(SAVE_DIR):
		dir.make_dir_recursive(SAVE_DIR)
		
	print("--- Starting Import from ALLACTIONS.csv ---")
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 27: continue # Skip empty lines
		
		# 1. Create the Resource Instance
		var action = ActionData.new()
		
		# 2. Map Columns (0-27)
		action.display_name = line[0]
		action.description = line[1]
		
		action.block_value = int(line[2])
		action.cost = int(line[3])
		action.counter_value = int(line[4])
		action.create_opening = int(line[5])
		action.damage = int(line[6])
		
		# Type Logic: Offence column (16) takes priority, otherwise Defence (7)
		var is_offence = (line[16].to_lower() == "true")
		if is_offence:
			action.type = ActionData.Type.OFFENCE
		else:
			action.type = ActionData.Type.DEFENCE
			
		action.feint = (line[8].to_lower() == "true") # Column 8 is "Ditto" (Feint)
		action.dodge_value = int(line[9])
		action.fall_back_value = int(line[10])
		action.guard_break = (line[11].to_lower() == "true")
		action.heal_value = int(line[12])
		action.injure = (line[13].to_lower() == "true")
		action.momentum_gain = int(line[14])
		action.multi_limit = int(line[15])
		action.is_opener = (line[17].to_lower() == "true")
		action.opportunity = int(line[18])
		action.is_parry = (line[19].to_lower() == "true")
		action.recover_value = int(line[20])
		action.repeat_count = int(line[21])
		action.retaliate = (line[22].to_lower() == "true")
		action.reversal = (line[23].to_lower() == "true")
		action.is_super = (line[24].to_lower() == "true")
		action.sweep = (line[25].to_lower() == "true")
		action.tiring_value = int(line[26])
		
		# 3. Apply Hard-Coded Fixes (The "Harsh" Audit)
		if action.display_name == "Vital Point Assault" and action.repeat_count == 3:
			print("Applying v0.3 Fix: Vital Point Assault Repeat 3 -> 2")
			action.repeat_count = 2
			
		# 4. Generate Filename (snake_case)
		# "Basic Light" -> "basic_light.tres"
		var filename = action.display_name.to_lower().replace(" ", "_").replace("'", "") + ".tres"
		action.id = filename.replace(".tres", "") # internal ID matches filename
		
		# 5. Save
		var err = ResourceSaver.save(action, SAVE_DIR + filename)
		if err == OK:
			print("Saved: " + filename)
		else:
			print("Failed to save: " + filename)

	print("--- Import Complete ---")
	# Refresh Editor
	var editor = EditorInterface.get_resource_filesystem()
	editor.scan()
