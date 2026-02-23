@tool
extends EditorScript

# --- CONFIGURATION ---
# This dictionary maps the Output Filename to the list of scripts you want inside it.
# You can add or remove paths here as your project grows.
var chunks = {
	"Core_Managers.txt": [
		"res://Scripts/Resources/GameManager.gd",
		"res://Scripts/RunManager.gd",
		"res://Scripts/ClassFactory.gd",
		"res://Scripts/AudioManager.gd",
		"res://Scripts/Resources/ClassDefinition.gd",
		"res://Scripts/Resources/CharacterData.gd",
		"res://Scripts/Resources/ActionData.gd",
		"res://Scripts/Resources/DialogueManager.gd"
	],
	
	"UI_Systems.txt": [
		"res://Scripts/BattleUI.gd",
		"res://Scripts/MenuArcade.gd",
		"res://Scripts/MenuQuick.gd",
		"res://Scripts/CardDisplay.gd",
		"res://Scripts/DeckEditScreen.gd",
		"res://Scripts/TournamentMap.gd", # If you have this
		"res://Scripts/RewardScreen.gd"    # If you have this
	],
	
	"Gameplay_Logic.txt": [
		"res://Scripts/ActionTree.gd",
		"res://Scripts/ActionNode.gd",
		"res://Scripts/EventRoom.gd",
		"res://Scripts/TestArena.gd",
		"res://Scripts/SoundButton.gd",
		"res://Scripts/EquipmentDraft.gd"  # If you have this
	]
}

func _run():
	print("--- STARTING PROJECT EXPORT ---")
	
	# Loop through each category in the dictionary
	for output_filename in chunks.keys():
		var file_list = chunks[output_filename]
		export_chunk(output_filename, file_list)
		
	print("--- EXPORT COMPLETE ---")
	print("Check your project folder for the .txt files!")

func export_chunk(filename: String, file_paths: Array):
	# Create/Overwrite the output file in the project root
	var save_path = "res://" + filename
	var out_file = FileAccess.open(save_path, FileAccess.WRITE)
	
	if not out_file:
		print("ERROR: Could not create file: " + save_path)
		return

	print("Writing " + filename + "...")
	
	for path in file_paths:
		if FileAccess.file_exists(path):
			var content = FileAccess.get_file_as_string(path)
			
			# Write a clean header so I (the AI) know which file this is
			out_file.store_string("\n")
			out_file.store_string("========================================\n")
			out_file.store_string("FILE PATH: " + path + "\n")
			out_file.store_string("========================================\n")
			out_file.store_string(content)
			out_file.store_string("\n\n")
		else:
			print("   [WARNING] File not found (Skipped): " + path)
			
	out_file.close()
