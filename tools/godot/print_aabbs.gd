extends SceneTree
func _init() -> void:
	var dir := "res://assets/thirdparty/polyhaven/models/"
	for d in DirAccess.get_directories_at(dir):
		var p := dir + d + "/" + d + "_1k.gltf"
		if not ResourceLoader.exists(p):
			continue
		var s: PackedScene = load(p)
		var n := s.instantiate()
		var box := Models.node_aabb(n, Transform3D.IDENTITY)
		print("%-28s size=(%.2f, %.2f, %.2f) center=(%.2f, %.2f, %.2f)" % [d, box.size.x, box.size.y, box.size.z, box.get_center().x, box.get_center().y, box.get_center().z])
		n.free()
	for kit in ["car-kit", "survival-kit"]:
		for f in ["sedan", "suv", "van", "truck", "hatchback-sports", "delivery", "tent", "workbench", "bedroll", "campfire-pit", "chest", "barrel", "box-large"]:
			var p2 := "res://assets/thirdparty/kenney/%s/%s.glb" % [kit, f]
			if ResourceLoader.exists(p2):
				var n2: Node = (load(p2) as PackedScene).instantiate()
				var b2 := Models.node_aabb(n2, Transform3D.IDENTITY)
				print("k:%s/%-18s size=(%.2f, %.2f, %.2f) center=(%.2f, %.2f, %.2f)" % [kit, f, b2.size.x, b2.size.y, b2.size.z, b2.get_center().x, b2.get_center().y, b2.get_center().z])
				n2.free()
	quit()
