extends Control

@onready var token_label = $MarginContainer/HBoxContainer/LeftPanel/TokenBankLabel
@onready var inventory_list = $MarginContainer/HBoxContainer/LeftPanel/ItemList/InventoryList
@onready var item_icon = $MarginContainer/HBoxContainer/RightPanel/ItemIcon
@onready var item_name_label = $MarginContainer/HBoxContainer/RightPanel/ItemName
@onready var item_desc_label = $MarginContainer/HBoxContainer/RightPanel/ItemDesc
@onready var buy_btn = $MarginContainer/HBoxContainer/RightPanel/BuyButton

# --- NEW AUTOMATED CATALOG ---
# Drag and drop your .tres files here in the Godot Inspector!
@export var resource_catalog: Array[Resource] = []

var selected_index: int = -1

func _ready():
	_refresh_ui()

func _refresh_ui():
	token_label.text = "CIRCUIT TOKENS: " + str(RunManager.meta_data.circuit_tokens)
	
	for child in inventory_list.get_children():
		child.queue_free()
		
	for i in range(resource_catalog.size()):
		var res = resource_catalog[i]
		if not res: continue
		
		# Extract data regardless of resource type
		var display_name = _get_res_name(res)
		var cost = res.get("shop_cost") if "shop_cost" in res else 0
		var is_owned = _check_if_owned(res)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 50)
		btn.text = display_name + (" [OWNED]" if is_owned else " [" + str(cost) + "T]")
		btn.disabled = is_owned
		
		btn.pressed.connect(func(): _select_item(i))
		inventory_list.add_child(btn)
		
	if selected_index == -1:
		_clear_preview()

func _get_res_name(res: Resource) -> String:
	if "item_name" in res: return res.item_name # For Sponsors/Equipment
	if "class_type" in res: # For Classes
		return CharacterData.ClassType.keys()[res.class_type].capitalize()
	return "Unknown Item"

func _check_if_owned(res: Resource) -> bool:
	var id = _get_res_name(res)
	if res is SponsorData:
		return id in RunManager.meta_data.unlocked_sponsors
	# Using 'is' check or duck-typing for ClassDefinition
	if "class_type" in res:
		return id in RunManager.meta_data.unlocked_classes
	return false

func _select_item(index: int):
	AudioManager.play_sfx("ui_click")
	selected_index = index
	var res = resource_catalog[index]
	
	item_name_label.text = _get_res_name(res)
	
	# Handle description differences
	if "description" in res: item_desc_label.text = res.description
	elif "passive_description" in res: item_desc_label.text = res.passive_description
	
	# Handle icon differences
	if "icon" in res: item_icon.texture = res.icon
	elif "portrait" in res: item_icon.texture = res.portrait
	
	var cost = res.get("shop_cost") if "shop_cost" in res else 0
	
	if RunManager.meta_data.circuit_tokens >= cost:
		buy_btn.disabled = false
		buy_btn.text = "AUTHORIZE TRANSFER (" + str(cost) + "T)"
		if buy_btn.pressed.is_connected(_on_buy_pressed):
			buy_btn.pressed.disconnect(_on_buy_pressed)
		buy_btn.pressed.connect(_on_buy_pressed)
	else:
		buy_btn.disabled = true
		buy_btn.text = "INSUFFICIENT FUNDS"

func _on_buy_pressed():
	if selected_index == -1: return
	var res = resource_catalog[selected_index]
	var cost = res.get("shop_cost") if "shop_cost" in res else 0
	var id = _get_res_name(res)
	
	if RunManager.meta_data.circuit_tokens >= cost:
		AudioManager.play_sfx("ui_confirm")
		RunManager.meta_data.circuit_tokens -= cost
		
		if res is SponsorData:
			RunManager.meta_data.unlocked_sponsors.append(id)
		else: # Assume Class
			RunManager.meta_data.unlocked_classes.append(id)
			
		RunManager._save_global_data()
		selected_index = -1
		_refresh_ui()

func _clear_preview():
	item_name_label.text = "SELECT DATA PACKET"
	item_desc_label.text = ""
	buy_btn.disabled = true
	buy_btn.text = "AWAITING SELECTION"
