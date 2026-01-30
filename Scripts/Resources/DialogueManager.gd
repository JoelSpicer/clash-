extends Node

# --- DATA STRUCTURE ---
# Key: ClassType (Who is speaking?)
# Value: Dictionary of Contexts -> Array of Strings
var lines = {
	CharacterData.ClassType.HEAVY: {
		"INTRO_GENERIC": ["I'm gonna break you in half!", "Don't cry when this is over.", "Hmph. Tiny."],
		"INTRO_VS_QUICK": ["Stop hopping around and FIGHT!", "I'll swat you like a fly."],
		"WIN_OFFENCE": ["CRUSHED!", "Too weak!", "Boom!"],
		"WIN_DEFENCE": ["Is that it?", "Tickles.", "My turn."],
		"HURT_HEAVY": ["GAAH!", "You'll pay for that...", "Finally, a challenge!"],
		"USE_SUPER": ["GAME OVER!", "GOODNIGHT!"],
		"LOW_HP": ["I... am not... done...", "Just... a scratch..."]
	},
	CharacterData.ClassType.QUICK: {
		"INTRO_GENERIC": ["Too slow!", "Catch me if you can!", "This will be over in a second."],
		"INTRO_VS_HEAVY": ["Big target. Easy target.", "You'll never hit me, big guy!"],
		"WIN_OFFENCE": ["Too slow!", "Keep up!", "Gotcha!"],
		"WIN_DEFENCE": ["Missed me!", "Too obvious.", "Nope!"],
		"HURT_HEAVY": ["Oof! Okay...", "Hey! Watch the face!", "That... actually hurt."],
		"USE_SUPER": ["MAXIMUM SPEED!", "LIGHTSPEED!"],
		"LOW_HP": ["Running... on fumes...", "Can't... stop..."]
	},
	CharacterData.ClassType.TECHNICAL: {
		"INTRO_GENERIC": ["I've already calculated your defeat.", "Your stance is full of openings.", "Let's test my theory."],
		"INTRO_VS_PATIENT": ["Stalling won't save you.", "I know exactly what you're waiting for."],
		"WIN_OFFENCE": ["Calculated.", "Precision strikes.", "Dissected."],
		"WIN_DEFENCE": ["Predictable.", "As expected.", "Flawed technique."],
		"HURT_HEAVY": ["Miscalculation...", "An error in judgment.", "Critical damage taken."],
		"USE_SUPER": ["CHECKMATE.", "SOLUTION FOUND."],
		"LOW_HP": ["System... failing...", "Impossible..."]
	},
	CharacterData.ClassType.PATIENT: {
		"INTRO_GENERIC": ["Patience is a weapon.", "I can wait all day.", "Your anger makes you sloppy."],
		"INTRO_VS_TECHNICAL": ["Analyze all you want. I'm not moving.", "Overthinking creates doubt."],
		"WIN_OFFENCE": ["An opening.", "Now.", "Exposed."],
		"WIN_DEFENCE": ["Denied.", "Wasted effort.", "Not yet."],
		"HURT_HEAVY": ["A solid hit...", "I underestimated you.", "Focus..."],
		"USE_SUPER": ["THE WAIT IS OVER.", "STRIKE TRUE."],
		"LOW_HP": ["Breathing... difficult...", "Must... stay... calm..."]
	}
}

# --- FUNCTIONS ---

# Returns a dictionary { "p1": "Line", "p2": "Line" }
func get_intro_banter(p1_type, p2_type) -> Dictionary:
	var p1_line = _get_line(p1_type, "INTRO_GENERIC")
	var p2_line = _get_line(p2_type, "INTRO_GENERIC")
	
	# Check for specific match-up lines (P1 vs P2)
	var p1_specific_key = "INTRO_VS_" + ClassFactory.class_enum_to_string(p2_type).to_upper()
	if lines.has(p1_type) and lines[p1_type].has(p1_specific_key):
		p1_line = lines[p1_type][p1_specific_key].pick_random()
		
	# Check for specific match-up lines (P2 vs P1)
	var p2_specific_key = "INTRO_VS_" + ClassFactory.class_enum_to_string(p1_type).to_upper()
	if lines.has(p2_type) and lines[p2_type].has(p2_specific_key):
		p2_line = lines[p2_type][p2_specific_key].pick_random()
		
	return { "p1":"'" +  p1_line + "'", "p2":"'" +  p2_line + "'" }

func get_reaction(class_type, context: String) -> String:
	return _get_line(class_type, context)

func _get_line(class_type, key: String) -> String:
	if not lines.has(class_type): return "..."
	if not lines[class_type].has(key): return "..."
	return lines[class_type][key].pick_random()
