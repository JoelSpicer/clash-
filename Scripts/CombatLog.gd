extends PanelContainer

# --- VISUAL REFERENCES ---
var scroll_container: ScrollContainer
var log_list: VBoxContainer
var tooltip_popup: PanelContainer
var left_card_preview
var right_card_preview

# Colors
const P1_COLOR = "#ff9999" 
const P2_COLOR = "#99ccff"
const HOVER_COLOR = Color(0.2, 0.2, 0.2, 0.8) 
const NORMAL_COLOR = Color(0, 0, 0, 0)        

var card_scene = preload("res://Scenes/CardDisplay.tscn")

func _ready():
	# 1. CLEANUP
	for child in get_children():
		child.queue_free()
	$".".print_tree_pretty()
	# 2. CREATE SCROLL LIST
	scroll_container = ScrollContainer.new()
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll_container)
	
	log_list = VBoxContainer.new()
	log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_list.add_theme_constant_override("separation", 2) 
	scroll_container.add_child(log_list)
	
	# 3. CREATE TOOLTIP POPUP
	_create_tooltip_popup()
	
	# --- FIX: Listen for when the player opens the log ---
	visibility_changed.connect(_on_visibility_changed)

func _create_tooltip_popup():
	tooltip_popup = PanelContainer.new()
	tooltip_popup.visible = false
	tooltip_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	# CRITICAL FIX: Break out of the ScrollContainer's bounds
	tooltip_popup.set_as_top_level(true)
	tooltip_popup.z_index = 100 
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	tooltip_popup.add_child(hbox)
	
	left_card_preview = card_scene.instantiate()
	left_card_preview.custom_minimum_size = Vector2(150, 210)
	left_card_preview.scale = Vector2(0.6, 0.6)
	hbox.add_child(left_card_preview)
	
	var vs_lbl = Label.new()
	vs_lbl.text = "VS"
	hbox.add_child(vs_lbl)
	
	right_card_preview = card_scene.instantiate()
	right_card_preview.custom_minimum_size = Vector2(150, 210)
	right_card_preview.scale = Vector2(0.6, 0.6)
	hbox.add_child(right_card_preview)
	
	# Add to self (CombatLog), but 'set_as_top_level' makes it float globally
	add_child(tooltip_popup)

# --- PUBLIC FUNCTIONS ---

func add_log(text: String):
	var row = MarginContainer.new()
	row.add_theme_constant_override("margin_left", 5)
	
	var label = _create_rich_label(text)
	row.add_child(label)
	
	log_list.add_child(row)
	_auto_scroll()

func add_clash_log(winner_id: int, p1_card: ActionData, p2_card: ActionData):
	# 1. ROOT CONTAINER (MarginContainer)
	# Handles layout so rows don't crush each other
	var row = MarginContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	# 2. TEXT CONTENT
	var win_text = "COMPLETE"
	var color = "#24ab4a"
	if winner_id == 1: pass
		#win_text = "P1 WON"
		#color = P1_COLOR
	elif winner_id == 2: pass
		#win_text = "P2 WON"
		#color = P2_COLOR
		
	var txt = "[color=%s]>>> CLASH!: %s (Hover to view)[/color]" % [color, win_text]
	var label = _create_rich_label(txt)
	
	var text_margin = MarginContainer.new()
	text_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_margin.add_theme_constant_override("margin_left", 5)
	text_margin.add_theme_constant_override("margin_top", 2)
	text_margin.add_theme_constant_override("margin_bottom", 2)
	text_margin.add_child(label)
	
	row.add_child(text_margin)
	
	# 3. BUTTON OVERLAY
	# Handles Interaction
	var btn = Button.new()
	
	btn.mouse_entered.connect(func(): AudioManager.play_sfx("ui_hover", 0.2))
	btn.pressed.connect(func(): AudioManager.play_sfx("ui_click"))
	
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.flat = true 
	
	# Styles
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = HOVER_COLOR
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	# Signals
	btn.mouse_entered.connect(func(): _on_row_hovered(btn, p1_card, p2_card))
	btn.mouse_exited.connect(func(): _on_row_exited())
	
	row.add_child(btn)
	log_list.add_child(row)
	_auto_scroll()

func clear_log():
	for child in log_list.get_children():
		child.queue_free()

# --- HELPERS ---

func _create_rich_label(text: String) -> RichTextLabel:
	var l = RichTextLabel.new()
	l.bbcode_enabled = true
	l.text = _format_text(text)
	l.fit_content = true 
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	return l

func _format_text(raw: String) -> String:
	var txt = raw.replace("P1", "[color=" + P1_COLOR + "]P1[/color]")
	txt = txt.replace("P2", "[color=" + P2_COLOR + "]P2[/color]")
	if ">>" in txt: txt = "[color=#aaaaaa][i]" + txt + "[/i][/color]"
	return txt

func _auto_scroll():
	# Only scroll if we are actually visible to avoid errors
	if not visible: return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if scroll_container and scroll_container.get_v_scroll_bar():
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

# --- INTERACTIVITY ---

func _on_row_hovered(_btn: Button, c1: ActionData, c2: ActionData):
	# 1. Update Content
	if left_card_preview.has_method("set_card_data"):
		left_card_preview.set_card_data(c1)
		right_card_preview.set_card_data(c2)
	
	# 2. Position Popup
	tooltip_popup.visible = true
	tooltip_popup.reset_size() 
	
	## 3. Calculate Global Position
	## 'set_as_top_level' means we use screen coordinates.
	## 'btn.global_position' gives us the button's exact screen location.
	#var popup_height = 250
	#var target_y = btn.global_position.y - popup_height - 70
	#
	## Logic: If row is too high (near top of screen), show BELOW the row instead
	#if target_y < 0:
		#target_y = btn.global_position.y + btn.size.y + 20
		#
	#var target_x = global_position.x + 200
	#
	#tooltip_popup.global_position = Vector2(target_x, target_y)
	tooltip_popup.global_position = get_viewport().get_mouse_position()

	
func _on_row_exited():
	tooltip_popup.visible = false

func add_round_summary(p1_diff: Dictionary, p2_diff: Dictionary, mom_val: int):
	# Create a simple row container
	var row = MarginContainer.new()
	row.add_theme_constant_override("margin_left", 20) # Indent slightly
	row.add_theme_constant_override("margin_bottom", 5)
	
	# Format the text
	var p1_text = _format_diff("P1", p1_diff, P1_COLOR)
	var p2_text = _format_diff("P2", p2_diff, P2_COLOR)
	var mom_text = " | Mom: [color=yellow]" + str(mom_val) + "[/color]"
	
	# --- NEW: COMBO COUNTER ---
	var combo_text = ""
	var attacker = GameManager.get_attacker()
	
	# Check if P1 is comboing
	if attacker == 1 and GameManager.p1_data.combo_action_count > 1:
		combo_text = " | [color=#ff9999][b]P1 COMBO: " + str(GameManager.p1_data.combo_action_count) + " HITS![/b][/color]"
	# Check if P2 is comboing
	elif attacker == 2 and GameManager.p2_data.combo_action_count > 1:
		combo_text = " | [color=#99ccff][b]P2 COMBO: " + str(GameManager.p2_data.combo_action_count) + " HITS![/b][/color]"
	# --------------------------
	
	var final_bbcode = p1_text + "   " + p2_text + mom_text + combo_text + "\n [b]----------- NEW CLASH -----------[/b]"
	
	var label = _create_rich_label(final_bbcode)
	row.add_child(label)
	
	log_list.add_child(row)
	_auto_scroll()

# Helper to format changes (e.g., "-5 HP" in red, "+2 SP" in green)
func _format_diff(player_label: String, diff: Dictionary, name_color: String) -> String:
	var s = "[color=" + name_color + "]" + player_label + ":[/color] "
	var changes = []
	
	# HP Change
	if diff.hp != 0:
		var c = "red" if diff.hp < 0 else "green"
		# RENAMED VARIABLE: 'sign' -> 'sign_str'
		var sign_str = "+" if diff.hp > 0 else ""
		changes.append("[color=" + c + "]" + sign_str + str(diff.hp) + " HP[/color]")
		
	# SP Change
	if diff.sp != 0:
		var c = "red" if diff.sp < 0 else "green"
		# RENAMED VARIABLE: 'sign' -> 'sign_str'
		var sign_str = "+" if diff.sp > 0 else ""
		changes.append("[color=" + c + "]" + sign_str + str(diff.sp) + " SP[/color]")
		
	if changes.is_empty():
		return s + "[color=#888888]No Change[/color]"
		
	return s + ", ".join(changes)

func _on_visibility_changed():
	# If we just opened the window, wait for it to draw, then scroll to bottom.
	if visible:
		_auto_scroll()

# --- NEW FUNCTION: This is what TestArena calls to get the text ---
func get_log_text() -> String:
	var full_log_string = ""
	
	# Iterate through every row in the log list
	for child in log_list.get_children():
		# We need a helper to find the label, because sometimes it's nested
		# inside MarginContainers or other layout nodes.
		var label = _find_richtext_recursive(child)
		
		if label:
			# We use .text (includes BBCode) so the Game Over screen keeps the colors.
			# If you want plain text, use label.get_parsed_text()
			full_log_string += label.text + "\n"
			
	return full_log_string
# -----------------------------------------------------------------

func _find_richtext_recursive(node: Node) -> RichTextLabel:
	if node is RichTextLabel:
		return node
	
	for child in node.get_children():
		var found = _find_richtext_recursive(child)
		if found:
			return found
			
	return null
