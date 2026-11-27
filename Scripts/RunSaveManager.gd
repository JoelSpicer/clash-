class_name RunSaveManager
extends RefCounted

const SAVE_DIR: String = "user://saves/"
const GLOBAL_SAVE_PATH: String = "user://global_save.tres"


static func sanitize_save_name(run_name: String) -> String:
	var cleaned: String = run_name.strip_edges().validate_filename()
	if cleaned == "":
		cleaned = "Unnamed_Run"
	return cleaned


static func save_run(run_mgr: Node) -> Error:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

	var save_data: RunSaveData = RunSaveData.new()
	save_data.run_name = str(run_mgr.get("current_run_name"))
	save_data.current_level = int(run_mgr.get("current_level"))
	save_data.current_map_index = int(run_mgr.get("current_map_index"))
	save_data.difficulty = int(GameManager.ai_difficulty)
	save_data.maintain_hp = bool(run_mgr.get("maintain_hp_enabled"))
	save_data.pending_advancement = bool(run_mgr.get("pending_advancement"))
	save_data.pending_reward = bool(run_mgr.get("pending_reward"))
	save_data.pending_league_victory = bool(run_mgr.get("pending_league_victory"))
	save_data.reward_tokens_granted = bool(run_mgr.get("reward_tokens_granted"))
	save_data.tree_ids = (run_mgr.get("player_owned_tree_ids") as Array[int]).duplicate()
	save_data.player_data = run_mgr.get("player_run_data") as CharacterData
	save_data.map_data = (run_mgr.get("tournament_map") as Array[MapNodeData]).duplicate()
	save_data.timestamp = Time.get_datetime_string_from_system()
	save_data.active_sponsor = run_mgr.get("active_sponsor") as SponsorData
	save_data.leagues_completed = int(run_mgr.get("leagues_completed"))
	save_data.current_rerolls = int(run_mgr.get("current_rerolls"))
	save_data.active_gym_buff = str(run_mgr.get("active_gym_buff"))
	save_data.next_fight_statuses = (run_mgr.get("next_fight_statuses") as Array[String]).duplicate()
	save_data.is_boss_match = bool(run_mgr.get("is_boss_match"))
	save_data.is_rival_match = bool(run_mgr.get("is_rival_match"))

	var safe_name: String = sanitize_save_name(save_data.run_name)
	var file_path: String = SAVE_DIR + safe_name + ".tres"
	var err: Error = ResourceSaver.save(save_data, file_path)
	if err != OK:
		printerr("RunSaveManager: Failed to save run to %s (err=%d)" % [file_path, err])
		return err

	show_save_notification(run_mgr)
	print("Run saved to: " + file_path)
	return OK


static func load_run_data(filename: String) -> RunSaveData:
	var path: String = SAVE_DIR + filename
	if not FileAccess.file_exists(path):
		return null
	# CACHE_MODE_IGNORE ensures repeated loads/peeks in the same session always read fresh disk state
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as RunSaveData


static func get_save_files() -> Array[String]:
	var files: Array[String] = []
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	files.sort()
	return files


static func delete_save_file(filename: String) -> void:
	var path: String = SAVE_DIR + filename
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("Deleted save: " + filename)


static func load_global_save() -> GlobalSaveData:
	if FileAccess.file_exists(GLOBAL_SAVE_PATH):
		var loaded: GlobalSaveData = ResourceLoader.load(GLOBAL_SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as GlobalSaveData
		if loaded != null:
			return loaded
		push_warning("RunSaveManager: Corrupted global_save.tres; creating fresh GlobalSaveData.")
	var fresh: GlobalSaveData = GlobalSaveData.new()
	save_global_save(fresh)
	return fresh


static func save_global_save(meta: GlobalSaveData) -> void:
	if meta == null:
		return
	var err: Error = ResourceSaver.save(meta, GLOBAL_SAVE_PATH)
	if err != OK:
		printerr("RunSaveManager: Failed to save global data (err=%d)" % err)


static func show_save_notification(host: Node) -> void:
	if host == null or not host.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	host.add_child(layer)

	var panel: PanelContainer = PanelContainer.new()
	layer.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.offset_left = 20.0
	panel.offset_top = 20.0

	var custom_style: StyleBoxFlat = StyleBoxFlat.new()
	custom_style.bg_color = Color(0, 0, 0, 0.8)
	custom_style.set_corner_radius_all(6)
	custom_style.content_margin_left = 15.0
	custom_style.content_margin_right = 15.0
	custom_style.content_margin_top = 8.0
	custom_style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", custom_style)

	panel.modulate.a = 0.0
	var label: Label = Label.new()
	label.text = " GAME SAVED "
	label.add_theme_font_size_override("font_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)

	var tween: Tween = host.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.5)
	tween.tween_interval(1.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(layer.queue_free)
