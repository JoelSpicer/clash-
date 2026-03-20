extends Control

@onready var token_label = $MarginContainer/HBoxContainer/LeftPanel/TokenBankLabel
@onready var inventory_list = $MarginContainer/HBoxContainer/LeftPanel/ItemList/InventoryList
@onready var item_icon = $MarginContainer/HBoxContainer/RightPanel/ItemIcon
@onready var item_name = $MarginContainer/HBoxContainer/RightPanel/ItemName
@onready var item_desc = $MarginContainer/HBoxContainer/RightPanel/ItemDesc
@onready var buy_btn = $MarginContainer/HBoxContainer/RightPanel/BuyButton

# THE CATALOG: Define what is for sale here!
var catalog = [
	{
		"id": "Aegis Industrial", # Must match SponsorName / ClassName exactly
		"type": "sponsor",
		"cost": 10,
		"desc": "A corporate sponsor offering solid defensive tech.\n\n+1 Global Block.",
		"icon_path": "res://Art/Icons/icon_Opening.png" # Temporary placeholder
	},
	{
		"id": "Technical", 
		"type": "class",
		"cost": 30,
		"desc": "Unlock the Technical fighter class. Use custom moves to confuse your opponent.",
		"icon_path": "res://Art/Portraits/Technical.png"
	},
	{
		"id": "Quick", 
		"type": "class",
		"cost": 10,
		"desc": "Unlock the Quick fighter class. High combo potential.",
		"icon_path": "res://Art/Portraits/Quick.png"
	},
	{
		"id": "Patient", 
		"type": "class",
		"cost": 20,
		"desc": "Unlock the Patient fighter class. Bide your time before unleasing on your opponent.",
		"icon_path": "res://Art/Portraits/Patient.png"
	}
]

var selected_item_index: int = -1

func _ready():
	_refresh_ui()

func _refresh_ui():
	# 1. Update Tokens
	token_label.text = "CIRCUIT TOKENS: " + str(RunManager.meta_data.circuit_tokens)
	token_label.add_theme_color_override("font_color", Color.GREEN)
	
	# 2. Clear List
	for child in inventory_list.get_children():
		child.queue_free()
		
	# 3. Populate List
	for i in range(catalog.size()):
		var item = catalog[i]
		var is_owned = _check_if_owned(item)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 50)
		btn.text = item.id + (" [OWNED]" if is_owned else " [" + str(item.cost) + "T]")
		btn.disabled = is_owned # Can't buy it twice
		
		btn.pressed.connect(func(): _select_item(i))
		inventory_list.add_child(btn)
		
	# Hide right panel if nothing is selected
	if selected_item_index == -1:
		item_name.text = "SELECT DATA PACKET"
		item_desc.text = ""
		buy_btn.disabled = true
		buy_btn.text = "AWAITING SELECTION"
		if buy_btn.pressed.is_connected(_on_buy_pressed):
			buy_btn.pressed.disconnect(_on_buy_pressed)

func _check_if_owned(item: Dictionary) -> bool:
	if item.type == "sponsor" and item.id in RunManager.meta_data.unlocked_sponsors:
		return true
	if item.type == "class" and item.id in RunManager.meta_data.unlocked_classes:
		return true
	return false

func _select_item(index: int):
	AudioManager.play_sfx("ui_click")
	selected_item_index = index
	var item = catalog[index]
	
	item_name.text = item.id
	item_desc.text = item.desc
	if item.has("icon_path") and ResourceLoader.exists(item.icon_path):
		item_icon.texture = load(item.icon_path)
	
	# Check affordability
	if RunManager.meta_data.circuit_tokens >= item.cost:
		buy_btn.disabled = false
		buy_btn.text = "AUTHORIZE TRANSFER (" + str(item.cost) + "T)"
		# Connect the buy button dynamically
		if buy_btn.pressed.is_connected(_on_buy_pressed):
			buy_btn.pressed.disconnect(_on_buy_pressed)
		buy_btn.pressed.connect(_on_buy_pressed)
	else:
		buy_btn.disabled = true
		buy_btn.text = "INSUFFICIENT FUNDS"

func _on_buy_pressed():
	if selected_item_index == -1: return
	
	var item = catalog[selected_item_index]
	
	# Double check cost just in case
	if RunManager.meta_data.circuit_tokens >= item.cost:
		AudioManager.play_sfx("ui_confirm")
		
		# 1. Deduct Money
		RunManager.meta_data.circuit_tokens -= item.cost
		
		# 2. Grant Item
		if item.type == "sponsor":
			RunManager.meta_data.unlocked_sponsors.append(item.id)
		elif item.type == "class":
			RunManager.meta_data.unlocked_classes.append(item.id)
			
		# 3. Save to Hard Drive!
		RunManager._save_global_data()
		
		# 4. Refresh the UI
		selected_item_index = -1
		_refresh_ui()
