extends SceneTree
## Загружает все скрипты проекта и сообщает об ошибках компиляции (для CI).
func _init() -> void:
	var bad := 0
	var files: Array = []
	_collect("res://scripts", files)
	_collect("res://autoload", files)
	for f in files:
		var s = load(f)
		if s == null or (s is Script and not s.can_instantiate() and not f.ends_with(".gdshader")):
			print("SCRIPT_ERROR: ", f)
			bad += 1
	print("checked %d scripts, errors: %d" % [files.size(), bad])
	quit(1 if bad > 0 else 0)
func _collect(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + d, out)
