extends Node

# --- FUNCTIONS ---

# CHANGED: Now accepts CharacterData objects instead of just the ClassType enums
func get_intro_banter(p1_data: CharacterData, p2_data: CharacterData) -> Dictionary:
	# Extract the class types for the lookup logic
	var p1_type = p1_data.class_type
	var p2_type = p2_data.class_type
	
	# 1. Generate the "Context Keys" for specific matchups
	var p1_context = "INTRO_VS_" + ClassFactory.class_enum_to_string(p2_type).to_upper()
	var p2_context = "INTRO_VS_" + ClassFactory.class_enum_to_string(p1_type).to_upper()
	
	# 2. Fetch raw lines (Try specific context first, fallback to generic)
	var raw_p1_line = _get_line(p1_type, [p1_context, "INTRO_GENERIC"])
	var raw_p2_line = _get_line(p2_type, [p2_context, "INTRO_GENERIC"])
	
	# --- 3. THE MAGIC TRICK (FORMATTING) ---
	# Replace {me} and {enemy} with the actual custom run names
	var final_p1_line = raw_p1_line.format({
		"me": p1_data.character_name,
		"enemy": p2_data.character_name
	})
	
	var final_p2_line = raw_p2_line.format({
		"me": p2_data.character_name,
		"enemy": p1_data.character_name
	})
	
	# Return with your single quotes wrapped around them
	return { "p1": "'" + final_p1_line + "'", "p2": "'" + final_p2_line + "'" }

# Wrapper for reaction barks (Hurt, Win, etc)
func get_reaction(class_type: CharacterData.ClassType, context: String) -> String:
	return _get_line(class_type, [context])

# --- INTERNAL HELPER ---
func _get_line(class_type: CharacterData.ClassType, valid_keys: Array) -> String:
	# 1. Fetch the Resource from the Factory
	if not ClassFactory.class_registry.has(class_type): 
		return "..."
		
	var def = ClassFactory.class_registry[class_type]
	
	# 2. Search for the best matching key
	# We loop through keys so we can try "INTRO_VS_QUICK" first, then "INTRO_GENERIC"
	for key in valid_keys:
		if def.barks.has(key):
			var lines_array = def.barks[key]
			if lines_array.size() > 0:
				return lines_array.pick_random()
	
	# 3. Fallback if nothing found
	return "..."
