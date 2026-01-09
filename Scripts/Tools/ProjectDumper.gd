@tool
extends EditorScript

# Files to ignore (e.g. addons usually don't need reviewing)
const IGNORE_DIRS = [".", "..", ".godot", "addons", "android", "ios"]

func _run():
	var all_code = "--- START OF PROJECT DUMP ---\n"
	all_code += _scan_directory("res://")
	
	# Save to the root of your project
	var save_path = "res://FullProjectCode.txt"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(all_code)
		file.close()
		print("SUCCESS! All scripts dumped to: " + save_path)
		print("You can now upload 'FullProjectCode.txt' to the chat.")
	else:
		printerr("Failed to save dump file.")

func _scan_directory(path: String) -> String:
	var output = ""
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if dir.current_is_dir():
				if not file_name in IGNORE_DIRS:
					output += _scan_directory(path + file_name + "/")
			else:
				# We only care about scripts (.gd) and maybe headers (.tscn if you want structure)
				# For code cleanup, .gd is usually enough.
				if file_name.ends_with(".gd"):
					output += "\n\n========================================\n"
					output += "FILE PATH: " + path + file_name + "\n"
					output += "========================================\n"
					
					var f = FileAccess.open(path + file_name, FileAccess.READ)
					if f:
						output += f.get_as_text()
						f.close()
			
			file_name = dir.get_next()
	return output
