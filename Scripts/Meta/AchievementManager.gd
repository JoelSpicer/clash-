class_name AchievementManager
extends RefCounted
## Evaluates achievements against GlobalSaveData, awards Circuit Tokens & Titles,
## and renders non-blocking Achievement Unlocked toasts.

const AchievementCatalogScript = preload("res://Scripts/Data/AchievementCatalog.gd")
const RunSaveManagerScript = preload("res://Scripts/RunSaveManager.gd")

static var _toast_queue: Array[Dictionary] = []
static var _toast_active: bool = false


static func get_progress(ach: Dictionary, meta: GlobalSaveData, custom_fighter_count: int = -1) -> Dictionary:
	var ach_id: String = str(ach.get("id", ""))
	var target: int = maxi(1, int(ach.get("target", 1)))
	if meta == null:
		return { "current": 0, "target": target, "unlocked": false }

	var already: bool = ach_id in meta.unlocked_achievements
	var cur: int = 0
	var eval_type: String = str(ach.get("type", "career_stat"))
	var key: String = str(ach.get("stat_key", ""))

	match eval_type:
		"career_stat":
			cur = int(meta.career_stats.get(key, 0))
		"class_leagues":
			var by_class: Variant = meta.career_stats.get(key, {})
			if by_class is Dictionary:
				var count: int = 0
				for cname: Variant in (by_class as Dictionary).keys():
					if int((by_class as Dictionary)[cname]) > 0:
						count += 1
				cur = count
		"trials_count":
			cur = meta.completed_trials.size()
		"custom_fighters_count":
			if custom_fighter_count >= 0:
				cur = custom_fighter_count
			else:
				cur = _count_custom_fighters_on_disk()

	if already:
		cur = maxi(cur, target)
	return { "current": mini(cur, target), "target": target, "unlocked": already }


## Checks all locked achievements, awards tokens + persists GlobalSaveData, and returns newly unlocked entries.
static func evaluate(host: Node, meta: GlobalSaveData, custom_fighter_count: int = -1, show_toasts: bool = true) -> Array[Dictionary]:
	var newly_unlocked: Array[Dictionary] = []
	if meta == null:
		return newly_unlocked

	var cf_count: int = custom_fighter_count if custom_fighter_count >= 0 else _count_custom_fighters_on_disk()
	var total_tokens: int = 0

	for ach: Dictionary in AchievementCatalogScript.get_all():
		var ach_id: String = str(ach.get("id", ""))
		if ach_id == "" or ach_id in meta.unlocked_achievements:
			continue
		var prog: Dictionary = get_progress(ach, meta, cf_count)
		if int(prog["current"]) >= int(prog["target"]):
			meta.unlocked_achievements.append(ach_id)
			var reward_t: int = int(ach.get("token_reward", 0))
			total_tokens += reward_t
			newly_unlocked.append(ach)

	if not newly_unlocked.is_empty():
		meta.circuit_tokens += total_tokens
		RunSaveManagerScript.save_global_save(meta)
		if show_toasts and host != null and host.is_inside_tree() and DisplayServer.get_name() != "headless":
			for ach_entry: Dictionary in newly_unlocked:
				_enqueue_toast(host, ach_entry)

	return newly_unlocked


static func _count_custom_fighters_on_disk() -> int:
	var dir: DirAccess = DirAccess.open("user://custom_fighters/")
	if dir == null:
		return 0
	var count: int = 0
	dir.list_dir_begin()
	var fn: String = dir.get_next()
	while fn != "":
		if not dir.current_is_dir() and fn.ends_with(".json"):
			count += 1
		fn = dir.get_next()
	dir.list_dir_end()
	return count


static func _enqueue_toast(host: Node, ach: Dictionary) -> void:
	_toast_queue.append(ach)
	if not _toast_active:
		_show_next_toast(host)


static func _show_next_toast(host: Node) -> void:
	if _toast_queue.is_empty() or host == null or not host.is_inside_tree():
		_toast_active = false
		return

	_toast_active = true
	var ach: Dictionary = _toast_queue.pop_front() as Dictionary

	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 120
	host.add_child(layer)

	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -390.0
	panel.offset_right = -20.0
	panel.offset_top = 20.0
	panel.offset_bottom = 104.0

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.14, 0.94)
	style.border_color = Color(1.0, 0.85, 0.25)
	style.border_width_left = 5
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var hdr: Label = Label.new()
	hdr.text = "★ ACHIEVEMENT UNLOCKED!"
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.86, 0.3))
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hdr)

	var title_lbl: Label = Label.new()
	var reward_parts: Array[String] = ["+%dT" % int(ach.get("token_reward", 0))]
	var t_rew: String = str(ach.get("title_reward", ""))
	if t_rew != "":
		reward_parts.append("Title: «%s»" % t_rew)
	title_lbl.text = "%s  (%s)" % [str(ach.get("name", "")), " · ".join(reward_parts)]
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = str(ach.get("description", ""))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	AudioManager.play_sfx("ui_confirm")
	panel.modulate.a = 0.0
	var tw: Tween = host.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(panel, "modulate:a", 1.0, 0.22)
	tw.tween_interval(2.6)
	tw.tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
		_show_next_toast(host)
	)
