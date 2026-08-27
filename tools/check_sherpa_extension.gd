extends SceneTree


func _init() -> void:
	var path := "res://addons/sherpa_tts/sherpa_tts.gdextension"
	print("exists=", ResourceLoader.exists(path))
	var res := ResourceLoader.load(path)
	print("resource=", res)
	print("class_exists=", ClassDB.class_exists("SherpaOfflineTTS"))
	quit(0 if ClassDB.class_exists("SherpaOfflineTTS") else 1)
