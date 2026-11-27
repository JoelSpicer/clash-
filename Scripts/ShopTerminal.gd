extends Control

@onready var token_label: Label = $MarginContainer/HBoxContainer/LeftPanel/TokenBankLabel
@onready var inventory_list: VBoxContainer = $MarginContainer/HBoxContainer/LeftPanel/ItemList/InventoryList
@onready var item_icon: TextureRect = $MarginContainer/HBoxContainer/RightPanel/ItemIcon
@onready var item_name_label: Label = $MarginContainer/HBoxContainer/RightPanel/ItemName
@onready var item_desc_label: RichTextLabel = $MarginContainer/HBoxContainer/RightPanel/ItemDesc
@onready var buy_btn: Button = $MarginContainer/HBoxContainer/RightPanel/BuyButton

@export var resource_catalog: Array[Resource] = []

var selected_index: int = -1
var _item_buttons: Array[Button] = []


func _ready() -> void:
	if buy_btn and not buy_btn.pressed.is_connected(_on_buy_pressed):
		buy_btn.pressed.connect(_on_buy_pressed)
	_refresh_ui()


func _refresh_ui() -> void:
	if RunManager.meta_data == null:
		return
	token_label.text = "CIRCUIT TOKENS: " + str(RunManager.meta_data.circuit_tokens)

	for child: Node in inventory_list.get_children():
		inventory_list.remove_child(child)
		child.queue_free()
	_item_buttons.clear()

	var first_unowned_idx: int = -1
	for i: int in range(resource_catalog.size()):
		var res: Resource = resource_catalog[i]
		if not res:
			continue

		var display_name: String = _get_res_name(res)
		var cost: int = int(res.get("shop_cost")) if "shop_cost" in res else 0
		var is_owned: bool = _check_if_owned(res)
		if not is_owned and first_unowned_idx == -1:
			first_unowned_idx = i

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 50)
		btn.text = display_name + (" [OWNED]" if is_owned else " [" + str(cost) + "T]")
		btn.modulate = Color(0.65, 0.85, 0.65, 0.85) if is_owned else Color.WHITE
		btn.focus_mode = Control.FOCUS_ALL

		var item_idx: int = i
		btn.pressed.connect(func() -> void: _select_item(item_idx, true))
		btn.focus_entered.connect(func() -> void: _select_item(item_idx, false))
		inventory_list.add_child(btn)
		_item_buttons.append(btn)

	for j: int in range(_item_buttons.size()):
		var b: Button = _item_buttons[j]
		if j > 0:
			b.focus_neighbor_top = b.get_path_to(_item_buttons[j - 1])
		if j + 1 < _item_buttons.size():
			b.focus_neighbor_bottom = b.get_path_to(_item_buttons[j + 1])
		if buy_btn:
			b.focus_neighbor_right = b.get_path_to(buy_btn)

	if selected_index == -1:
		var auto_idx: int = first_unowned_idx if first_unowned_idx != -1 else (0 if not resource_catalog.is_empty() else -1)
		if auto_idx != -1:
			_select_item(auto_idx, false)
		else:
			_clear_preview()


func _unhandled_input(event: InputEvent) -> void:
	if Pausemenu.visible or not is_visible_in_tree():
		return
	if event is InputEventJoypadButton:
		var joy: InputEventJoypadButton = event as InputEventJoypadButton
		if joy.pressed and joy.button_index == JOY_BUTTON_X and buy_btn and not buy_btn.disabled:
			_on_buy_pressed()
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_B and buy_btn and not buy_btn.disabled:
		_on_buy_pressed()
		get_viewport().set_input_as_handled()
	elif (key_event.keycode == KEY_UP or key_event.keycode == KEY_DOWN) and get_viewport().gui_get_focus_owner() == null and not _item_buttons.is_empty():
		_item_buttons[0].grab_focus()
		get_viewport().set_input_as_handled()


func _get_res_name(res: Resource) -> String:
	if "item_name" in res:
		return str(res.get("item_name"))
	if "class_type" in res:
		var ctype: int = int(res.get("class_type"))
		return str(CharacterData.ClassType.keys()[ctype]).capitalize()
	return "Unknown Item"


func _check_if_owned(res: Resource) -> bool:
	if RunManager.meta_data == null:
		return false
	var id: String = _get_res_name(res)
	if res is SponsorData:
		return id in RunManager.meta_data.unlocked_sponsors
	if "class_type" in res:
		return id in RunManager.meta_data.unlocked_classes
	return false


func _select_item(index: int, play_sfx: bool = true) -> void:
	if index < 0 or index >= resource_catalog.size() or RunManager.meta_data == null:
		return
	if play_sfx:
		AudioManager.play_sfx("ui_click")
	selected_index = index
	if buy_btn and index >= 0 and index < _item_buttons.size():
		buy_btn.focus_neighbor_left = buy_btn.get_path_to(_item_buttons[index])
	var res: Resource = resource_catalog[index]

	item_name_label.text = _get_res_name(res)

	if "description" in res:
		item_desc_label.text = str(res.get("description"))
	elif "passive_description" in res:
		item_desc_label.text = str(res.get("passive_description"))
	else:
		item_desc_label.text = ""

	if "icon" in res:
		item_icon.texture = res.get("icon") as Texture2D
	elif "portrait" in res:
		item_icon.texture = res.get("portrait") as Texture2D
	else:
		item_icon.texture = null

	var cost: int = int(res.get("shop_cost")) if "shop_cost" in res else 0

	if _check_if_owned(res):
		buy_btn.disabled = true
		buy_btn.text = "ALREADY OWNED"
	elif RunManager.meta_data.circuit_tokens >= cost:
		buy_btn.disabled = false
		buy_btn.text = "AUTHORIZE TRANSFER (" + str(cost) + "T)"
	else:
		buy_btn.disabled = true
		buy_btn.text = "INSUFFICIENT FUNDS"


func _on_buy_pressed() -> void:
	if selected_index < 0 or selected_index >= resource_catalog.size() or RunManager.meta_data == null:
		return
	var res: Resource = resource_catalog[selected_index]
	if _check_if_owned(res):
		return
	var cost: int = int(res.get("shop_cost")) if "shop_cost" in res else 0
	var id: String = _get_res_name(res)

	if RunManager.meta_data.circuit_tokens >= cost:
		AudioManager.play_sfx("ui_confirm")
		RunManager.meta_data.circuit_tokens -= cost

		if res is SponsorData:
			RunManager.meta_data.unlocked_sponsors.append(id)
		else:
			RunManager.meta_data.unlocked_classes.append(id)

		RunManager._save_global_data()
		RunManager.check_achievements()
		selected_index = -1
		_refresh_ui()


func _clear_preview() -> void:
	item_name_label.text = "SELECT DATA PACKET"
	item_desc_label.text = ""
	item_icon.texture = null
	buy_btn.disabled = true
	buy_btn.text = "AWAITING SELECTION"
