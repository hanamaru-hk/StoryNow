extends SceneTree

func _initialize() -> void:
	var ok: bool = ClassDB.class_exists("SherpaOfflineTTS")
	print("SherpaOfflineTTS class loaded: %s" % ok)
	if not ok:
		quit(1)
		return

	var repo: String = OS.get_cmdline_user_args()[0]
	var out_wav: String = OS.get_cmdline_user_args()[1]
	var model_dir: String = "vits-piper-en_US-amy-low"
	var onnx_name: String = "en_US-amy-low.onnx"
	var text: String = "Native Sherpa TTS is ready."
	if OS.get_cmdline_user_args().size() >= 4:
		model_dir = OS.get_cmdline_user_args()[2]
		onnx_name = OS.get_cmdline_user_args()[3]
	if OS.get_cmdline_user_args().size() >= 5:
		text = OS.get_cmdline_user_args()[4]
	var base: String = repo.path_join("data/sherpa-models").path_join(model_dir)
	var model: Dictionary = {
		"onnx": base.path_join(onnx_name),
		"tokens": base.path_join("tokens.txt"),
		"data_dir": base.path_join("espeak-ng-data"),
		"lexicon": base.path_join("lexicon.txt"),
		"rule_fsts": "",
	}
	if not DirAccess.dir_exists_absolute(str(model["data_dir"])):
		model["data_dir"] = ""
	if not FileAccess.file_exists(str(model["lexicon"])):
		model["lexicon"] = ""
	var tts: Object = ClassDB.instantiate("SherpaOfflineTTS")
	var synth_ok: bool = bool(tts.call("synthesize_to_wav", text, out_wav, model, 0, 1.0, 4))
	print("Native synthesis ok: %s" % synth_ok)
	if not synth_ok:
		print("Native synthesis error: %s" % str(tts.call("get_last_error")))
		quit(1)
		return
	quit(0)
