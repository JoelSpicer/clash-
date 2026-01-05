@tool
extends EditorScript

# --- CONFIGURATION ---
const ACTIONS_FOLDER = "res://Data/Actions/"

# REPLACE THESE WITH YOUR ACTUAL ICON PATHS
const OFFENCE_ICON_PATH = "res://Art/OffenceBasic.jpg"
const DEFENCE_ICON_PATH = "res://Art/DefenceBasic.jpg"

func _run():
	# 1. Load the icons
	var off_icon = load(OFFENCE_ICON_PATH)
	var def_icon = load(DEFENCE_ICON_PATH)

	# Safety Check
	if not off_icon or not def_icon:
		printerr("Error: Could not load one or both icons. Check the paths!")
		return

	print("--- STARTING SMART BULK UPDATE ---")
	
	# 2. Start scanning
	_scan_directory(ACTIONS_FOLDER, off_icon, def_icon)
	
	print("--- COMPLETE! ---")

func _scan_directory(path: String, off_icon: Texture2D, def_icon: Texture2D):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					_scan_directory(path + file_name + "/", off_icon, def_icon)
			else:
				if file_name.ends_with(".tres"):
					_apply_icon_to_file(path + file_name, off_icon, def_icon)
			
			file_name = dir.get_next()

func _apply_icon_to_file(file_path: String, off_icon: Texture2D, def_icon: Texture2D):
	var resource = ResourceLoader.load(file_path)
	
	if resource is ActionData:
		var target_icon = null
		
		# --- LOGIC: CHOOSE ICON BASED ON TYPE ---
		if resource.type == ActionData.Type.OFFENCE:
			target_icon = off_icon
		elif resource.type == ActionData.Type.DEFENCE:
			target_icon = def_icon
			
		# Apply if we found a valid type
		if target_icon:
			# OPTIONAL: Check 'if resource.icon == null:' if you only want to fill empty ones.
			# Currently, this overwrites everything so you can fix incorrect icons.
			if resource.icon != target_icon:
				resource.icon = target_icon
				ResourceSaver.save(resource, file_path)
				print("Updated: " + file_path + " -> " + ("Offence" if resource.type == 0 else "Defence"))
