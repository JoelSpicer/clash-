extends Node

# Folders we don't need to see
const IGNORED_DIRS = [".godot", ".git", "export", "builds"]

# File extensions that just clutter the list
const IGNORED_EXTENSIONS = [".import", ".uid", ".translation"]

func _ready():
	print("Scanning project structure...")
	
	var output = "=== GODOT PROJECT STRUCTURE ===\n"
	output += "Generated: " + Time.get_datetime_string_from_system() + "\n\n"
	output += "res://\n"
	
	# Start the recursive scan
	output += _scan_directory("res://", "    ")
	
	# Save to a text file
	var save_path = "res://ProjectStructure.txt"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	
	if file:
		file.store_string(output)
		file.close()
		print("SUCCESS! Saved to: ", save_path)
	else:
		print("ERROR: Could not save the file.")
		
	# Automatically close the game window when done
	get_tree().quit()

func _scan_directory(path: String, indent: String) -> String:
	var result = ""
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		var directories = []
		var files = []
		
		# Sort files and folders into lists
		while file_name != "":
			if file_name != "." and file_name != "..":
				if dir.current_is_dir():
					if not file_name in IGNORED_DIRS:
						directories.append(file_name)
				else:
					# Check if we should ignore this file type
					var is_ignored = false
					for ext in IGNORED_EXTENSIONS:
						if file_name.ends_with(ext):
							is_ignored = true
							break
					
					if not is_ignored:
						files.append(file_name)
			
			file_name = dir.get_next()
		
		# Alphabetize for readability
		directories.sort()
		files.sort()
		
		# Print Directories first (and scan inside them)
		for d in directories:
			result += indent + "[+] " + d + "/\n"
			result += _scan_directory(path + d + "/", indent + "    ")
			
		# Then print Files
		for f in files:
			result += indent + " -  " + f + "\n"
			
	return result
