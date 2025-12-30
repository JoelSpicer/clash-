extends PanelContainer

@onready var log_label = $MarginContainer/LogLabel

# Colors for formatting
const P1_COLOR = "#ff9999" # Red-ish
const P2_COLOR = "#99ccff" # Blue-ish
const DMG_COLOR = "#ff4444" # Bright Red
const WIN_COLOR = "#ffd700" # Gold
const SUB_COLOR = "#aaaaaa" # Gray for detailed logs (>>)

func add_log(text: String):
	var formatted_text = _format_text(text)
	
	# Append text with a newline
	if log_label.text != "":
		log_label.text += "\n"
	
	log_label.text += formatted_text
	
	# Auto-scroll to bottom
	# We wait a frame for the UI to update the text size
	await get_tree().process_frame 
	log_label.scroll_to_line(log_label.get_line_count() - 1)

func _format_text(raw: String) -> String:
	var txt = raw
	
	# 1. Color Player Names
	txt = txt.replace("P1", "[color=" + P1_COLOR + "]P1[/color]")
	txt = txt.replace("P2", "[color=" + P2_COLOR + "]P2[/color]")
	
	# 2. Highlight Winners
	if "Winner" in txt or "VICTORY" in txt:
		txt = "[color=" + WIN_COLOR + "][b]" + txt + "[/b][/color]"
		
	# 3. Dim Sub-events (starting with >> or >)
	elif txt.begins_with("   >") or txt.begins_with(">>"):
		txt = "[color=" + SUB_COLOR + "][i]" + txt + "[/i][/color]"
		
	# 4. Highlight specific keywords
	txt = txt.replace("Damage", "[color=" + DMG_COLOR + "]Damage[/color]")
	txt = txt.replace("HP", "[color=" + DMG_COLOR + "]HP[/color]")
	txt = txt.replace("hits", "[color=" + DMG_COLOR + "]hits[/color]")
	
	# 5. Highlight Phase headers
	if txt.begins_with("| ---"):
		txt = "[center][b]" + txt + "[/b][/center]"
		
	return txt

func clear_log():
	log_label.text = ""
