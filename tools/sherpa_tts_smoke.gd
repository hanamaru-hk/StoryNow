extends SceneTree

func _initialize() -> void:
	var ok: bool = ClassDB.class_exists("SherpaOfflineTTS")
	print("SherpaOfflineTTS class loaded: %s" % ok)
	if not ok:
		quit(1)
		return

	var repo: String = OS.get_cmdline_user_args()[0]
	var out_wav: String = OS.get_cmdline_user_args()[1]
	var base: String = repo.path_join("server/sherpa-onnx/models/vits-piper-en_US-amy-low")
	var model: Dictionary = {
		"onnx": base.path_join("en_US-amy-low.onnx"),
		"tokens": base.path_join("tokens.txt"),
		"data_dir": base.path_join("espeak-ng-data"),
		"lexicon": base.path_join("lexicon.txt"),
		"rule_fsts": "",
	}
	var tts: Object = ClassDB.instantiate("SherpaOfflineTTS")
	var synth_ok: bool = bool(tts.call("synthesize_to_wav", "Native Sherpa TTS is ready.", out_wav, model, 0, 1.0, 4))
	print("Native synthesis ok: %s" % synth_ok)
	if not synth_ok:
		print("Native synthesis error: %s" % str(tts.call("get_last_error")))
		quit(1)
		return
	quit(0)
