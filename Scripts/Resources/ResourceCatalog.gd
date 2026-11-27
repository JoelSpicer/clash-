class_name ResourceCatalog
extends RefCounted

## Export-safe (.pck / .remap / .import) resource directory scanner.
## Centralizes all dynamic folder enumeration so Web and Desktop builds load identically.


static func list_paths(dir_path: String, extensions: PackedStringArray = PackedStringArray([".tres", ".res"]), sort_paths: bool = true) -> Array[String]:
	var normalized_dir: String = dir_path if dir_path.ends_with("/") else dir_path + "/"
	var results: Array[String] = []
	var seen: Dictionary = {}

	var dir: DirAccess = DirAccess.open(normalized_dir)
	if dir == null:
		return results

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean_name: String = file_name.replace(".remap", "").replace(".import", "")
			if not seen.has(clean_name):
				var matched: bool = false
				for ext: String in extensions:
					if clean_name.ends_with(ext):
						matched = true
						break
				if matched:
					seen[clean_name] = true
					results.append(normalized_dir + clean_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if sort_paths:
		results.sort()
	return results


static func load_dir(dir_path: String, sort_paths: bool = true) -> Array[Resource]:
	var loaded: Array[Resource] = []
	for path: String in list_paths(dir_path, PackedStringArray([".tres", ".res"]), sort_paths):
		var res: Resource = load(path)
		if res != null:
			loaded.append(res)
	return loaded
