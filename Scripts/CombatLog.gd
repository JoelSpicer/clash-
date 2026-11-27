extends PanelContainer

# --- VISUAL REFERENCES ---
var scroll_container: ScrollContainer
var log_list: VBoxContainer
var tooltip_popup: PanelContainer
var left_card_preview: Control
var right_card_preview: Control

# Colors
const P1_COLOR: String = "#ff9999" 
const P2_COLOR: String = "#99ccff"
const HOVER_COLOR: Color = Color(0.2, 0.2, 0.2, 0.8) 
const NORMAL_COLOR: Color = Color(0, 0, 0, 0)        
const MAX_ACTIVE_ROWS: int = 30
var archive_label: RichTextLabel
var card_scene: PackedScene = preload("res://Scenes/CardDisplay.tscn")

func _ready() -> void:
	# 1. CLEANUP
	for child in get_children():
		child.queue_free()
		
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
	
	# --- NEW: CREATE ARCHIVE LABEL ---
	archive_label = RichTextLabel.new()
	archive_label.bbcode_enabled = true
	archive_label.fit_content = true
	archive_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archive_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_list.add_child(archive_label)
	# ---------------------------------
	
	# 3. CREATE TOOLTIP POPUP
	_create_tooltip_popup()
	
	visibility_changed.connect(_on_visibility_changed)

func _create_tooltip_popup() -> void:
	tooltip_popup = PanelContainer.new()
	tooltip_popup.visible = false
	tooltip_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	# CRITICAL FIX: Break out of the ScrollContainer's bounds
	tooltip_popup.set_as_top_level(true)
	tooltip_popup.z_index = 100 
	
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	tooltip_popup.add_child(hbox)
	
	left_card_preview = card_scene.instantiate() as Control
	left_card_preview.custom_minimum_size = Vector2(150, 210)
	left_card_preview.scale = Vector2(0.6, 0.6)
	hbox.add_child(left_card_preview)
	
	var vs_lbl: Label = Label.new()
	vs_lbl.text = "VS"
	hbox.add_child(vs_lbl)
	
	right_card_preview = card_scene.instantiate() as Control
	right_card_preview.custom_minimum_size = Vector2(150, 210)
	right_card_preview.scale = Vector2(0.6, 0.6)
	hbox.add_child(right_card_preview)
	
	# Add to self (CombatLog), but 'set_as_top_level' makes it float globally
	add_child(tooltip_popup)

# --- PUBLIC FUNCTIONS ---

func add_log(text: String) -> void:
	var row: MarginContainer = MarginContainer.new()
	row.add_theme_constant_override("margin_left", 5)
	
	var label: RichTextLabel = _create_rich_label(text)
	row.add_child(label)
	
	log_list.add_child(row)
	_archive_old_logs()
	_auto_scroll()

func add_clash_log(winner_id: int, p1_card: ActionData, p2_card: ActionData) -> void:
	# 1. ROOT CONTAINER (MarginContainer)
	var row: MarginContainer = MarginContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	# 2. TEXT CONTENT
	var win_text: String = "COMPLETE"
	var color: String = "#24ab4a"
	if winner_id == 1: pass
	elif winner_id == 2: pass
		
	var txt: String = "[color=%s]>>> CLASH!: %s (Hover to view)[/color]" % [color, win_text]
	var label: RichTextLabel = _create_rich_label(txt)
	
	var text_margin: MarginContainer = MarginContainer.new()
	text_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_margin.add_theme_constant_override("margin_left", 5)
	text_margin.add_theme_constant_override("margin_top", 2)
	text_margin.add_theme_constant_override("margin_bottom", 2)
	text_margin.add_child(label)
	
	row.add_child(text_margin)
	
	# 3. BUTTON OVERLAY
	var btn: Button = Button.new()
	
	btn.mouse_entered.connect(func() -> void: AudioManager.play_sfx("ui_hover", 0.2))
	btn.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.flat = true 
	
	# Styles
	var style_hover: StyleBoxFlat = StyleBoxFlat.new()
	style_hover.bg_color = HOVER_COLOR
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	# Signals
	btn.mouse_entered.connect(func() -> void: _on_row_hovered(btn, p1_card, p2_card))
	btn.mouse_exited.connect(func() -> void: _on_row_exited())
	
	row.add_child(btn)
	log_list.add_child(row)
	_archive_old_logs()
	_auto_scroll()

func clear_log() -> void:
	for child in log_list.get_children():
		if child != archive_label:
			child.queue_free()
			
	if archive_label:
		archive_label.text = ""

# --- HELPERS ---

func _create_rich_label(text: String) -> RichTextLabel:
	var l: RichTextLabel = RichTextLabel.new()
	l.bbcode_enabled = true
	l.text = _format_text(text)
	l.fit_content = true 
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	return l

func _format_text(raw: String) -> String:
	var txt: String = raw.replace("P1", "[color=" + P1_COLOR + "]P1[/color]")
	txt = txt.replace("P2", "[color=" + P2_COLOR + "]P2[/color]")
	if ">>" in txt: txt = "[color=#aaaaaa][i]" + txt + "[/i][/color]"
	return txt

func _auto_scroll() -> void:
	# Only scroll if we are actually visible to avoid errors
	if not visible: return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if scroll_container and scroll_container.get_v_scroll_bar():
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

# --- INTERACTIVITY ---

func _on_row_hovered(_btn: Button, c1: ActionData, c2: ActionData) -> void:
	# 1. Update Content
	if left_card_preview.has_method("set_card_data"):
		left_card_preview.call("set_card_data", c1)
		right_card_preview.call("set_card_data", c2)
	
	# 2. Position Popup
	tooltip_popup.visible = true
	tooltip_popup.reset_size() 
	tooltip_popup.global_position = get_viewport().get_mouse_position()

	
func _on_row_exited() -> void:
	tooltip_popup.visible = false

func add_round_summary(p1_diff: Dictionary, p2_diff: Dictionary, mom_val: int) -> void:
	# Create a simple row container
	var row: MarginContainer = MarginContainer.new()
	row.add_theme_constant_override("margin_left", 20) # Indent slightly
	row.add_theme_constant_override("margin_bottom", 5)
	
	# Format the text
	var p1_text: String = _format_diff("P1", p1_diff, P1_COLOR)
	var p2_text: String = _format_diff("P2", p2_diff, P2_COLOR)
	var mom_text: String = " | Mom: [color=yellow]" + str(mom_val) + "[/color]"
	
	# --- NEW: COMBO COUNTER ---
	var combo_text: String = ""
	var attacker: int = GameManager.get_attacker()
	
	# Check if P1 is comboing
	if attacker == 1 and GameManager.p1_data.combo_action_count > 1:
		combo_text = " | [color=#ff9999][b]P1 COMBO: " + str(GameManager.p1_data.combo_action_count) + " HITS![/b][/color]"
	# Check if P2 is comboing
	elif attacker == 2 and GameManager.p2_data.combo_action_count > 1:
		combo_text = " | [color=#99ccff][b]P2 COMBO: " + str(GameManager.p2_data.combo_action_count) + " HITS![/b][/color]"
	# --------------------------
	
	var final_bbcode: String = p1_text + "   " + p2_text + mom_text + combo_text + "\n [b]----------- NEW CLASH -----------[/b]"
	
	var label: RichTextLabel = _create_rich_label(final_bbcode)
	row.add_child(label)
	
	log_list.add_child(row)
	_archive_old_logs()
	_auto_scroll()

# Helper to format changes (e.g., "-5 HP" in red, "+2 SP" in green)
func _format_diff(player_label: String, diff: Dictionary, name_color: String) -> String:
	var s: String = "[color=" + name_color + "]" + player_label + ":[/color] "
	var changes: Array[String] = []
	
	var hp_delta: int = int(diff.get("hp", 0))
	var sp_delta: int = int(diff.get("sp", 0))
	
	# HP Change
	if hp_delta != 0:
		var c: String = "red" if hp_delta < 0 else "green"
		var sign_str: String = "+" if hp_delta > 0 else ""
		changes.append("[color=" + c + "]" + sign_str + str(hp_delta) + " HP[/color]")
		
	# SP Change
	if sp_delta != 0:
		var c: String = "red" if sp_delta < 0 else "green"
		var sign_str: String = "+" if sp_delta > 0 else ""
		changes.append("[color=" + c + "]" + sign_str + str(sp_delta) + " SP[/color]")
		
	if changes.is_empty():
		return s + "[color=#888888]No Change[/color]"
		
	return s + ", ".join(changes)

func _on_visibility_changed() -> void:
	# If we just opened the window, wait for it to draw, then scroll to bottom.
	if visible:
		_auto_scroll()

# --- NEW FUNCTION: This is what CombatArena calls to get the text ---
func get_log_text() -> String:
	var full_log_string: String = ""
	
	# Iterate through every row in the log list
	for child in log_list.get_children():
		var label: RichTextLabel = _find_richtext_recursive(child)
		if label:
			full_log_string += label.text + "\n"
			
	return full_log_string

func _find_richtext_recursive(node: Node) -> RichTextLabel:
	if node is RichTextLabel:
		return node as RichTextLabel
	
	for child in node.get_children():
		var found: RichTextLabel = _find_richtext_recursive(child)
		if found:
			return found
			
	return null

func _archive_old_logs() -> void:
	# We check for MAX + 1 because the archive_label itself is at index 0
	while log_list.get_child_count() > MAX_ACTIVE_ROWS + 1:
		var oldest_row: Node = log_list.get_child(1) # Index 1 is the oldest interactive log
		
		# Find its text and append to archive
		var label: RichTextLabel = _find_richtext_recursive(oldest_row)
		if label:
			archive_label.text += label.text + "\n"
			
		# Delete the heavy UI row
		log_list.remove_child(oldest_row)
		oldest_row.queue_free()
