extends Node
## Headless Sherpa-ONNX TTS manager.
## Uses sherpa-onnx-offline-tts.exe via PowerShell .ps1 to preserve UTF-8
## (avoids OS.create_process / OS.execute UTF-8 corruption on Windows).
## Generates wav per interaction.dialogue -> attaches sound_filename.

signal tts_generated(uuid: String, idx: int, sound_filename: String, save_path: String)
signal batch_completed(uuid: String)

const SHERPA_DIR := "server/sherpa-onnx"
const SHERPA_EXE := "server/sherpa-onnx/bin/sherpa-onnx-offline-tts.exe"
const MODELS_ROOT := "server/sherpa-onnx/models"
const SPEED := 1.0
const SID := 0
const NUM_THREADS := 1

# model resolution
const MODEL_EN_FEMALE := "vits-piper-en_US-amy-low/en_US-amy-low.onnx"
const MODEL_EN_MALE := "vits-piper-en_US-lessac-medium/en_US-lessac-medium.onnx"
const MODEL_ZH_FEMALE := "vits-piper-zh_CN-huayan-medium/zh_CN-huayan-medium.onnx"
const MODEL_ZH_MALE := "vits-piper-zh_CN-chaowen-medium/zh_CN-chaowen-medium.onnx"
const MODEL_ZH_FALLBACK := "vits-piper-zh_CN-huayan-medium/zh_CN-huayan-medium.onnx"

var _queue: Array = [] # Array[Dictionary] {uuid, idx, dialogue, sex, language}
var _generating: bool = false
var _current_task: Dictionary = {}


func _ready() -> void:
	pass


func is_available() -> bool:
	var exe_path := ProjectSettings.globalize_path("res://" + SHERPA_EXE)
	return FileAccess.file_exists(exe_path) or FileAccess.file_exists("res://" + SHERPA_EXE)


func _model_for(sex: String, language: String) -> Dictionary:
	var s := sex.strip_edges().to_lower()
	var lang := language.strip_edges().to_lower()
	if lang.begins_with("zh"):
		if s == "female" or s == "woman" or s == "girl":
			return _resolve_model(MODEL_ZH_FEMALE)
		elif s == "male" or s == "man" or s == "boy":
			return _resolve_model(MODEL_ZH_MALE)
		else:
			return _resolve_model(MODEL_ZH_FALLBACK)
	else:
		# en and fallback
		if s == "female" or s == "woman" or s == "girl":
			return _resolve_model(MODEL_EN_FEMALE)
		else:
			return _resolve_model(MODEL_EN_MALE)


func _resolve_model(onnx_rel: String) -> Dictionary:
	# onnx_rel like vits-piper-en_US-amy-low/en_US-amy-low.onnx
	var base_dir := MODELS_ROOT + "/" + onnx_rel.get_base_dir() # models/xxx
	var tokens := base_dir + "/tokens.txt"
	var data_dir := base_dir + "/espeak-ng-data"
	var lexicon := base_dir + "/lexicon.txt"
	var rule_fsts := base_dir + "/date.fst," + base_dir + "/number.fst," + base_dir + "/phone.fst"
	var onnx := MODELS_ROOT + "/" + onnx_rel
	return {"onnx": onnx, "tokens": tokens, "data_dir": data_dir, "lexicon": lexicon, "rule_fsts": rule_fsts, "base_dir": base_dir}


func _is_sherpa_ready(model: Dictionary) -> bool:
	var exe_global := ProjectSettings.globalize_path("res://" + SHERPA_EXE)
	if not FileAccess.file_exists(exe_global) and not FileAccess.file_exists("res://" + SHERPA_EXE):
		push_warning("TTSManager: sherpa exe not found: %s" % exe_global)
		return false
	for k in ["onnx", "tokens"]:
		var p: String = str(model.get(k, ""))
		var gp := ProjectSettings.globalize_path("res://" + p)
		if not FileAccess.file_exists(gp) and not FileAccess.file_exists("res://" + p):
			push_warning("TTSManager: missing model file: %s" % p)
			return false
	# data_dir or lexicon: at least one must exist
	var data_dir: String = str(model.get("data_dir", ""))
	var gp_data := ProjectSettings.globalize_path("res://" + data_dir)
	var has_data_dir := DirAccess.dir_exists_absolute(gp_data) or DirAccess.dir_exists_absolute("res://" + data_dir)
	var lex: String = str(model.get("lexicon", ""))
	var gp_lex := ProjectSettings.globalize_path("res://" + lex)
	var has_lex := FileAccess.file_exists(gp_lex) or FileAccess.file_exists("res://" + lex)
	if not has_data_dir and not has_lex:
		push_warning("TTSManager: missing model data_dir and lexicon: %s / %s" % [data_dir, lex])
		return false
	return true


func generate_all_for_scene(scene_data: Dictionary) -> void:
	if scene_data.is_empty():
		return
	var uuid := str(scene_data.get("uuid", "")).strip_edges()
	if uuid.is_empty():
		uuid = str(GameProgressManager.settings.get("current_uuid", "")).strip_edges()
	if uuid.is_empty():
		push_warning("TTSManager.generate_all_for_scene: missing uuid")
		return
	var language := str(scene_data.get("language", I18n.current_lang))
	var interactions: Array = scene_data.get("interactions", [])
	if not interactions is Array:
		return
	for i in interactions.size():
		var entry = interactions[i]
		if not entry is Dictionary:
			continue
		var d: Dictionary = entry as Dictionary
		var dialogue: String = str(d.get("dialogue", "")).strip_edges()
		if dialogue.is_empty():
			continue
		var sex: String = str(d.get("sex", "male"))
		# skip if already has sound_filename and file exists and dialogue unchanged? For now always enqueue but dedup later
		_enqueue(uuid, i, dialogue, sex, language)
	_process_queue_deferred()


func generate_single_interaction(uuid: String, idx: int) -> void:
	var u := uuid.strip_edges()
	if u.is_empty():
		u = str(SceneDataManager.scene_data.get("uuid", "")).strip_edges()
	if u.is_empty():
		return
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	if idx < 0 or idx >= interactions.size():
		return
	var entry = interactions[idx]
	if not entry is Dictionary:
		return
	var d: Dictionary = entry as Dictionary
	var dialogue: String = str(d.get("dialogue", "")).strip_edges()
	if dialogue.is_empty():
		return
	var sex: String = str(d.get("sex", "male"))
	var language := str(SceneDataManager.scene_data.get("language", I18n.current_lang))
	_enqueue(u, idx, dialogue, sex, language)
	_process_queue_deferred()


func generate_for_interaction(uuid: String, idx: int, dialogue: String, sex: String) -> void:
	var d2 := dialogue.strip_edges()
	if d2.is_empty():
		return
	var language := str(SceneDataManager.scene_data.get("language", I18n.current_lang))
	_enqueue(uuid, idx, d2, sex, language)
	_process_queue_deferred()


func _enqueue(uuid: String, idx: int, dialogue: String, sex: String, language: String) -> void:
	# dedup: if same uuid+idx already queued, replace dialogue/sex
	for q in _queue:
		if str(q.get("uuid", "")) == uuid and int(q.get("idx", -1)) == idx:
			q["dialogue"] = dialogue
			q["sex"] = sex
			q["language"] = language
			return
	if _generating and _current_task.get("uuid", "") == uuid and int(_current_task.get("idx", -999)) == idx:
		# currently generating same idx -> queue an update after
		for q in _queue:
			if str(q.get("uuid", "")) == uuid and int(q.get("idx", -1)) == idx:
				return
	_queue.append({"uuid": uuid, "idx": idx, "dialogue": dialogue, "sex": sex, "language": language})


func _process_queue_deferred() -> void:
	if _generating:
		return
	call_deferred("_process_queue")


func _process_queue() -> void:
	if _generating:
		return
	if _queue.is_empty():
		return
	_generating = true
	while not _queue.is_empty():
		var task: Dictionary = _queue.pop_front()
		_current_task = task
		var uuid: String = str(task.get("uuid", ""))
		var idx: int = int(task.get("idx", 0))
		var dialogue: String = str(task.get("dialogue", ""))
		var sex: String = str(task.get("sex", "male"))
		var language: String = str(task.get("language", "en"))
		if dialogue.strip_edges().is_empty():
			continue
		var model := _model_for(sex, language)
		if not _is_sherpa_ready(model):
			push_warning("TTSManager: not ready, skip idx %d" % idx)
			continue
		var out_path := _output_path_for(uuid, idx, dialogue)
		# Ensure sounds dir exists
		var sounds_dir := "user://saves/%s/sounds" % uuid
		if not DirAccess.dir_exists_absolute(sounds_dir):
			var mk := DirAccess.make_dir_recursive_absolute(sounds_dir)
			if mk != OK:
				push_warning("TTSManager: failed to create sounds dir %s" % sounds_dir)
				continue
		var exit_code := await _synthesize(dialogue, out_path, model)
		if exit_code != 0:
			push_warning("TTSManager: synthesize failed idx %d exit %d" % [idx, exit_code])
			continue
		var fname := out_path.get_file()
		# attach to scene_data if still same uuid
		_attach_sound_filename(uuid, idx, fname)
		var user_save_path := "user://saves/%s/sounds/%s" % [uuid, fname]
		tts_generated.emit(uuid, idx, fname, user_save_path)
		await get_tree().create_timer(6).timeout
	var batch_uuid := str(_current_task.get("uuid", ""))
	_current_task = {}
	_generating = false
	if not batch_uuid.is_empty():
		batch_completed.emit(batch_uuid)
	# if new items arrived while generating, loop again
	if not _queue.is_empty():
		_process_queue_deferred()


func _output_path_for(uuid: String, idx: int, dialogue: String) -> String:
	var h := str(dialogue.hash())
	# make short hash
	if h.begins_with("-"):
		h = h.substr(1)
	if h.length() > 8:
		h = h.substr(0, 8)
	var fname := "tts_%d_%s.wav" % [idx, h]
	var dir_global := ProjectSettings.globalize_path("user://saves/%s/sounds" % uuid)
	# Use global path for sherpa output-filename
	return dir_global + "/" + fname


func _attach_sound_filename(uuid: String, idx: int, fname: String) -> void:
	# Only attach if SceneDataManager currently holds same uuid
	var cur_uuid := str(SceneDataManager.scene_data.get("uuid", "")).strip_edges()
	if cur_uuid != uuid:
		# load file, patch, save back without overwriting current scene_data
		var path := "user://saves/%s/scene_data.json" % uuid
		if not FileAccess.file_exists(path):
			return
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			return
		var txt := f.get_as_text()
		f.close()
		var j := JSON.new()
		if j.parse(txt) != OK or not j.data is Dictionary:
			return
		var data: Dictionary = j.data
		var inters: Array = data.get("interactions", [])
		if idx < 0 or idx >= inters.size():
			return
		if inters[idx] is Dictionary:
			(inters[idx] as Dictionary)["sound_filename"] = fname
			data["interactions"] = inters
			var out := FileAccess.open(path, FileAccess.WRITE)
			if out:
				out.store_string(JSON.stringify(data, "\t"))
				out.close()
		return
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	if idx < 0 or idx >= interactions.size():
		return
	if interactions[idx] is Dictionary:
		(interactions[idx] as Dictionary)["sound_filename"] = fname
		SceneDataManager.scene_data["interactions"] = interactions
		SceneDataManager.save()


func _synthesize(text: String, output_global_path: String, model: Dictionary) -> int:
	# Reliable: Godot -> UTF-8 text file -> PowerShell reads UTF-8 -> Python helper -> Sherpa
	# No Chinese in PS1 or command line, only file paths (ASCII)
	var tmp_id := "%d_%d" % [Time.get_ticks_msec(), randi()]
	var txt_user := "user://tmp_tts_%s.txt" % tmp_id
	var ps1_user := "user://tmp_tts_%s.ps1" % tmp_id
	var txt_global := ProjectSettings.globalize_path(txt_user)
	var ps1_global := ProjectSettings.globalize_path(ps1_user)
	var helper_global := ProjectSettings.globalize_path("res://scripts/tts_helper.py")
	var onnx_global := ProjectSettings.globalize_path("res://" + str(model.get("onnx", "")))
	var tokens_global := ProjectSettings.globalize_path("res://" + str(model.get("tokens", "")))
	var data_dir_global := ProjectSettings.globalize_path("res://" + str(model.get("data_dir", "")))
	var lexicon_global := ProjectSettings.globalize_path("res://" + str(model.get("lexicon", "")))
	var rule_fsts_global := str(model.get("rule_fsts", ""))
	var rule_fsts_arg := ""
	if not rule_fsts_global.is_empty():
		var parts := rule_fsts_global.split(",")
		var glob_parts: Array = []
		for p in parts:
			var gp := ProjectSettings.globalize_path("res://" + str(p).strip_edges())
			glob_parts.append(gp)
		rule_fsts_arg = ",".join(glob_parts)
	var extra_args := ""
	var gp_data_check := ProjectSettings.globalize_path("res://" + str(model.get("data_dir", "")))
	var has_data_dir := DirAccess.dir_exists_absolute(gp_data_check)
	if has_data_dir:
		extra_args = '--vits-data-dir "%s"' % data_dir_global
	else:
		var has_lex := FileAccess.file_exists(lexicon_global)
		if has_lex:
			extra_args = '--vits-lexicon "%s"' % lexicon_global
			if not rule_fsts_arg.is_empty():
				extra_args += ' --tts-rule-fsts "%s"' % rule_fsts_arg
		else:
			extra_args = '--vits-data-dir "%s"' % data_dir_global
	# 1. Write dialogue to UTF-8 text file (Godot FileAccess is UTF-8)
	var tf := FileAccess.open(txt_user, FileAccess.WRITE)
	if tf == null:
		push_error("TTSManager: failed to create txt %s" % txt_user)
		return -1
	tf.store_string(text)
	tf.close()
	# 2. Write PS1 that calls Python helper with --text-file (no Chinese in PS1)
	# PS1 itself is ASCII-only, so no BOM / encoding issues
	var ps1_content := """$ErrorActionPreference='Stop'
python "%s" --vits-model "%s" --vits-tokens "%s" %s --output-filename "%s" --text-file "%s" --num-threads=%d
exit $LASTEXITCODE
""" % [helper_global, onnx_global, tokens_global, extra_args, output_global_path, txt_global, NUM_THREADS]
	var f := FileAccess.open(ps1_user, FileAccess.WRITE)
	if f == null:
		push_error("TTSManager: failed to create ps1 %s" % ps1_user)
		if FileAccess.file_exists(txt_user):
			var d2 := DirAccess.open(txt_global.get_base_dir())
			if d2:
				d2.remove(txt_global.get_file())
		return -1
	f.store_string(ps1_content)
	f.close()
	# 3. Run PS1 off the main thread. OS.execute blocks the whole game (hover/input
	# stall ~1s+) while Python loads the ONNX model and synthesizes. Poll instead.
	var args := PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps1_global])
	var pid: int = OS.create_process("powershell", args, false)
	if pid < 0:
		pid = OS.create_process("pwsh", args, false)
	if pid < 0:
		push_error("TTSManager: failed to start powershell for TTS")
		_cleanup_tts_temp_files([ps1_user, txt_user])
		return -1
	while OS.is_process_running(pid):
		await get_tree().process_frame
	var exit_code := 0 if FileAccess.file_exists(output_global_path) else -1
	# 4. Delete both temp files
	_cleanup_tts_temp_files([ps1_user, txt_user])
	return exit_code


func _cleanup_tts_temp_files(user_paths: Array) -> void:
	for user_path in user_paths:
		if not FileAccess.file_exists(user_path):
			continue
		var g := ProjectSettings.globalize_path(str(user_path))
		var dir := g.get_base_dir()
		var fname := g.get_file()
		var d := DirAccess.open(dir)
		if d != null:
			d.remove(fname)


func _generate_uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes: Array = []
	for i in 16:
		bytes.append(rng.randi_range(0, 255))
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5],
		bytes[6], bytes[7],
		bytes[8], bytes[9],
		bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
	]
