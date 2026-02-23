extends Node

# --- FUNCTIONS ---

# Returns a dictionary { "p1": "Line", "p2": "Line" }
func get_intro_banter(p1_type: CharacterData.ClassType, p2_type: CharacterData.ClassType) -> Dictionary:
	# 1. Generate the "Context Keys" for specific matchups
	# Example: If P1 is HEAVY and P2 is QUICK, P1 looks for "INTRO_VS_QUICK"
	var p1_context = "INTRO_VS_" + ClassFactory.class_enum_to_string(p2_type).to_upper()
	var p2_context = "INTRO_VS_" + ClassFactory.class_enum_to_string(p1_type).to_upper()
	
	# 2. Fetch lines (Try specific context first, fallback to generic)
	var p1_line = _get_line(p1_type, [p1_context, "INTRO_GENERIC"])
	var p2_line = _get_line(p2_type, [p2_context, "INTRO_GENERIC"])
	
	return { "p1": "'" +  p1_line + "'", "p2": "'" +  p2_line + "'" }

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
