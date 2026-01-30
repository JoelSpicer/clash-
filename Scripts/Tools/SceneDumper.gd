@tool
extends EditorScript

# Folders to ignore to keep the dump clean
const IGNORE_DIRS = [".", "..", ".godot", "addons", "android", "ios", ".import"]

# The output file name
const OUTPUT_FILE = "res://FullProjectScenes.txt"

func _run():
	print("--- STARTING SCENE DUMP ---")
	
	var all_text = "--- GODOT PROJECT SCENE DUMP ---\n"
	all_text += "Generated: " + Time.get_datetime_string_from_system() + "\n\n"
	
	all_text += _scan_directory("res://")
	
	var file = FileAccess.open(OUTPUT_FILE, FileAccess.WRITE)
	if file:
		file.store_string(all_text)
		file.close()
		print("SUCCESS! Scene data dumped to: " + OUTPUT_FILE)
		print("You can now upload 'FullProjectScenes.txt'.")
		
		# Refresh the FileSystem so the new file appears immediately
		EditorInterface.get_resource_filesystem().scan()
	else:
		printerr("Failed to write output file.")

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
				# We look specifically for Text Scenes (.tscn)
				# We ignore .scn because those are binary and unreadable
				if file_name.ends_with(".tscn"):
					output += _read_file_content(path + file_name)
					
			file_name = dir.get_next()
	else:
		printerr("Failed to open directory: " + path)
		
	return output

func _read_file_content(file_path: String) -> String:
	var content = ""
	
	# Header for readability
	content += "========================================\n"
	content += "FILE PATH: " + file_path + "\n"
	content += "========================================\n"
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		content += file.get_as_text()
		file.close()
	else:
		content += "[ERROR READING FILE]\n"
		
	content += "\n\n"
	return content
