extends Control


var _scene_data: Dictionary = {}
var _current_dialog_idx: int = 0

# Requested public dialogue tracking vars
var current_dialogue_index: int = 0
var total_dialogue: int = 1

func _ready() -> void:
	# --- Dialogue panel grid buttons ---
	%PlotButton.pressed.connect(_on_plot_pressed)
	%PlayAudioButton.pressed.connect(_on_play_audio_pressed)
	%DialogButton.pressed.connect(_on_dialog_btn_pressed)
	%ImageButton.pressed.connect(_on_image_btn_pressed)
	%PrevDialogButton.pressed.connect(_on_prev_dialog_pressed)
	%NextDialogButton.pressed.connect(_on_next_dialog_pressed)
	%PrevSceneButton.pressed.connect(_on_prev_scene_pressed)
	%NextSceneButton.pressed.connect(_on_next_scene_pressed)
	%SettingButton.pressed.connect(_on_setting_pressed)
	%BackButton.pressed.connect(_on_back_pressed)

	# --- Choice overlay ---
	%ChoiceConfirm.pressed.connect(_on_choice_confirm)
	%ChoiceCancel.pressed.connect(_on_choice_cancel)
	%ChoiceOverlay.visible = false

	# --- GameSettingsOverlay (in-game settings) ---
	if has_node("%GameSettingsOverlay"):
		%GameSettingsOverlay.closed.connect(_on_settings_closed)

	# --- ErrorReturnDialog ---
	%ErrorReturnDialog.confirmed.connect(_on_error_return)
	%ErrorReturnDialog.canceled.connect(_on_error_return)
	# AcceptDialog close via X also triggers canceled

	# Clicking on DialogArea advances dialogue (optional convenience)
	if has_node("%DialogArea"):
		%DialogArea.gui_input.connect(_on_dialog_area_input)

	_update_labels()
	_load_default_background()

	match GameProgressManager.settings.get("game_status", ""):
		"new_story":
			var uuid: String = str(GameProgressManager.settings.get("current_uuid", ""))
			var ok: bool = SceneDataManager.load_data(uuid)
			if ok:
				_scene_data = SceneDataManager.scene_data
			await _handle_new_story()
			# --- After new_story: update dialogue tracking and trigger image generation ---
			_update_total_dialogue()
			_show_current_dialogue()
			await _generate_comfyui_image()
		"new_scene":
			pass
		"running":
			pass
		_:
			pass


func _load_default_background() -> void:
	# Runtime load to avoid requiring .import (handles missing Texture2D loader error).
	# Uses Image.load_from_file via globalized path, then ImageTexture.
	var res_path := "res://assets/images/loading.jpg"
	var global_path := ProjectSettings.globalize_path(res_path)
	var img := Image.new()
	var err: Error = img.load(global_path)
	if err != OK:
		# Fallback: try direct res:// path (works if file is imported elsewhere)
		err = img.load(res_path)
	if err == OK:
		var tex := ImageTexture.create_from_image(img)
		%BackgroundImage.texture = tex
		%BackgroundImage.modulate = Color(1, 1, 1, 0.5)
	else:
		# Final fallback: try ResourceLoader (requires import)
		var res_tex: Resource = load(res_path)
		if res_tex is Texture2D:
			%BackgroundImage.texture = res_tex
		else:
			push_warning("Failed to load default background %s: %s" % [res_path, err])
		# Keep modulate for placeholder / 50% opacity
		%BackgroundImage.modulate = Color(1, 1, 1, 0.5)

# ------------------------------------------------------------------
# Dialogue helpers — current/total tracking and UI update
# ------------------------------------------------------------------
func _update_total_dialogue() -> void:
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	total_dialogue = interactions.size()
	if total_dialogue <= 0:
		total_dialogue = 1
	# keep legacy var in sync
	_current_dialog_idx = current_dialogue_index
	# clamp index inside range
	if current_dialogue_index < 0:
		current_dialogue_index = 0
	if current_dialogue_index >= total_dialogue:
		current_dialogue_index = total_dialogue - 1


func _show_current_dialogue() -> void:
	var interactions: Array = SceneDataManager.scene_data.get("interactions", [])
	if interactions.is_empty():
		if has_node("%NameLabel"):
			%NameLabel.text = ""
		if has_node("%DialogLabel"):
			%DialogLabel.text = ""
		if has_node("%DialogProgressLabel"):
			%DialogProgressLabel.text = "%d / %d" % [current_dialogue_index + 1, total_dialogue]
		return
	# clamp
	if current_dialogue_index < 0:
		current_dialogue_index = 0
	if current_dialogue_index >= interactions.size():
		current_dialogue_index = interactions.size() - 1
	var entry: Dictionary = interactions[current_dialogue_index] if interactions[current_dialogue_index] is Dictionary else {}
	# NOTE: spec has typo "characer" — support both keys
	var character_name: String = str(entry.get("character", entry.get("characer", "")))
	var dialogue_text: String = str(entry.get("dialogue", ""))
	if has_node("%NameLabel"):
		%NameLabel.text = character_name
	if has_node("%DialogLabel"):
		%DialogLabel.text = dialogue_text
	if has_node("%DialogProgressLabel"):
		%DialogProgressLabel.text = "%d / %d" % [current_dialogue_index + 1, total_dialogue]
	# sync legacy
	_current_dialog_idx = current_dialogue_index
	_scene_data = SceneDataManager.scene_data

# ------------------------------------------------------------------
# ComfyUI image generation — workflow_template.json + download
# ------------------------------------------------------------------
func _load_workflow_template_text() -> String:
	var path := "res://data/comfyui/workflow_template.json"
	if not FileAccess.file_exists(path):
		push_error("workflow_template.json not found: %s" % path)
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open workflow_template.json")
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _load_negative_prompt() -> String:
	var is_free: bool = GameSettingsManager.is_free_mode()
	var candidates: Array[String] = []
	if is_free:
		# user spec says comfyui/free_negative_prompt (also typo free_negatvie_prompt exists)
		candidates = ["res://data/comfyui/free_negative_prompt", "res://data/comfyui/free_negatvie_prompt"]
	else:
		candidates = ["res://data/comfyui/safe_negative_prompt", "res://data/comfyui/safe_negative_prompts"]
	for p in candidates:
		if FileAccess.file_exists(p):
			var f := FileAccess.open(p, FileAccess.READ)
			if f != null:
				var t := f.get_as_text().strip_edges()
				f.close()
				return t
	# fallback: try the opposite naming if first not found
	var fallback_paths: Array[String] = ["res://data/comfyui/safe_negative_prompt", "res://data/comfyui/free_negatvie_prompt", "res://data/comfyui/free_negative_prompt"]
	for p in fallback_paths:
		if FileAccess.file_exists(p):
			var f2 := FileAccess.open(p, FileAccess.READ)
			if f2 != null:
				var t2 := f2.get_as_text().strip_edges()
				f2.close()
				# if we were looking for free but only safe exists, still return it as last resort
				# caller decides; but better than empty
				if not candidates.has(p):
					return t2
	return ""


func _fix_comfy_workflow_dict(workflow_dict: Dictionary, seed_val: int) -> void:
	# Ensure workflow_dict has correct types and wiring for ComfyUI validation.
	# The shipped workflow_template.json historically had SaveImage wired to latent ("7")
	# and seed as string — both cause "prompt_outputs_failed_validation".
	# Also JSON parsing in Godot can produce float 0.0 for link indices, which
	# ComfyUI rejects as "tuple indices must be integers or slices, not float".
	if not workflow_dict.has("prompt") or not workflow_dict["prompt"] is Dictionary:
		return
	var prompt: Dictionary = workflow_dict["prompt"] as Dictionary
	# Fix SaveImage node "5" → must read from VAEDecode "4", not EmptyLatentImage "7"
	if prompt.has("5") and prompt["5"] is Dictionary:
		var n5: Dictionary = prompt["5"] as Dictionary
		if n5.has("inputs") and n5["inputs"] is Dictionary:
			var inputs5: Dictionary = n5["inputs"] as Dictionary
			# If miswired to latent, correct it
			var cur_images: Variant = inputs5.get("images", null)
			if cur_images is Array and cur_images.size() >= 2:
				if str(cur_images[0]) == "7":
					inputs5["images"] = ["4", 0]
			else:
				inputs5["images"] = ["4", 0]
	# Fix KSampler seed type — must be int, not string or float
	if prompt.has("2") and prompt["2"] is Dictionary:
		var n2: Dictionary = prompt["2"] as Dictionary
		if n2.has("inputs") and n2["inputs"] is Dictionary:
			var inputs2: Dictionary = n2["inputs"] as Dictionary
			inputs2["seed"] = int(seed_val)
	# Coerce width/height in node "7" to int in case placeholder produced string
	if prompt.has("7") and prompt["7"] is Dictionary:
		var n7: Dictionary = prompt["7"] as Dictionary
		if n7.has("inputs") and n7["inputs"] is Dictionary:
			var inputs7: Dictionary = n7["inputs"] as Dictionary
			inputs7["width"] = int(inputs7.get("width", 1344))
			inputs7["height"] = int(inputs7.get("height", 768))
			inputs7["batch_size"] = int(inputs7.get("batch_size", 1))
	# Normalize all link arrays ["node_id", idx] → idx must be int, not float/string
	for node_id in prompt.keys():
		var node: Variant = prompt[node_id]
		if not node is Dictionary:
			continue
		var nd: Dictionary = node as Dictionary
		if not nd.has("inputs") or not nd["inputs"] is Dictionary:
			continue
		var inputs: Dictionary = nd["inputs"] as Dictionary
		for key in inputs.keys():
			var val: Variant = inputs[key]
			if val is Array and val.size() == 2 and val[0] is String:
				# looks like a link
				var idx: Variant = val[1]
				if idx is float or idx is String:
					inputs[key] = [str(val[0]), int(idx)]
				elif idx is int:
					# already int, but ensure no float contamination via Variant conversion
					inputs[key] = [str(val[0]), int(idx)]


func _generate_comfyui_image() -> void:
	var raw_prompt: String = str(SceneDataManager.scene_data.get("image_prompt", ""))
	var image_prompt: String = _sanitize_image_prompt(raw_prompt)
	if image_prompt != raw_prompt:
		print_verbose("Sanitized stored image_prompt for ComfyUI: '%s'" % image_prompt.substr(0, 100))
		# Persist cleaned version
		SceneDataManager.scene_data["image_prompt"] = image_prompt
		SceneDataManager.save()
		_scene_data = SceneDataManager.scene_data
	if image_prompt.strip_edges().is_empty():
		push_warning("SceneDataManager image_prompt is empty after sanitize, skipping ComfyUI generation (raw was: '%s')" % raw_prompt.substr(0, 100))
		return

	var workflow_text := _load_workflow_template_text()
	if workflow_text.is_empty():
		show_error("Failed to load ComfyUI workflow_template.json")
		return

	var model_filename: String = str(ImageServerSettingsManager.settings.get("model_filename", ""))
	if model_filename.is_empty():
		model_filename = "waiIllustriousSDXL_v170.safetensors"

	var negative_prompt: String = _load_negative_prompt()

	var image_width: String = str(GameSettingsManager.settings.get("image_width", "1344"))
	var image_height: String = str(GameSettingsManager.settings.get("image_height", "768"))

	# Generate a random seed for __SEED__
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seed_val: int = rng.randi_range(0, 2147483647)

	# Replace placeholders — keep order, handle both naming variants
	workflow_text = workflow_text.replace("__MODEL_FILENAME__", model_filename)
	workflow_text = workflow_text.replace("__MODEL_NAME__", model_filename)
	workflow_text = workflow_text.replace("__POSITIVE_PROMPT__", image_prompt)
	workflow_text = workflow_text.replace("__NEGATIVE_PROMPT__", negative_prompt)
	workflow_text = workflow_text.replace("__FILENAME_PREFIX__", "SN")
	workflow_text = workflow_text.replace("__IMAGE_WIDTH__", image_width)
	workflow_text = workflow_text.replace("__IMAGE_HEIGHT__", image_height)
	workflow_text = workflow_text.replace("__SEED__", str(seed_val))

	print_verbose("image prompt" + image_prompt)
	print_verbose("ComfyUI workflow: " + workflow_text)

	var json := JSON.new()
	var err := json.parse(workflow_text)
	if err != OK or not json.data is Dictionary:
		push_error("Failed to parse workflow_template after replacement: %s" % error_string(err))
		show_error("Invalid ComfyUI workflow template after replacement")
		return
	var workflow_dict: Dictionary = json.data as Dictionary
	_fix_comfy_workflow_dict(workflow_dict, seed_val)

	# Use ImageServerManager port to queue prompt, then poll history and download
	var prompt_id := await _queue_comfy_prompt(workflow_dict)
	if prompt_id.is_empty():
		show_error("Failed to queue ComfyUI prompt")
		return

	var image_info := await _poll_comfy_history(prompt_id)
	if image_info.is_empty():
		show_error("ComfyUI did not return image (timeout or error)")
		return

	var filename: String = str(image_info.get("filename", ""))
	var subfolder: String = str(image_info.get("subfolder", ""))
	var img_type: String = str(image_info.get("type", "output"))
	if filename.is_empty():
		show_error("ComfyUI history missing filename")
		return

	var uuid: String = str(SceneDataManager.scene_data.get("id", GameProgressManager.settings.get("current_uuid", "")))
	var save_path := await _download_comfy_image(filename, subfolder, img_type, uuid)
	if save_path.is_empty():
		show_error("Failed to download ComfyUI image")
		return

	# update background
	_set_background_from_file(save_path)

	# append filename to SceneDataManager image_filenames array and persist
	if not SceneDataManager.scene_data.has("image_filenames") or not SceneDataManager.scene_data["image_filenames"] is Array:
		SceneDataManager.scene_data["image_filenames"] = []
	var arr: Array = SceneDataManager.scene_data["image_filenames"]
	# store relative filename (or full user:// path basename)
	arr.append(filename)
	SceneDataManager.scene_data["image_filenames"] = arr
	SceneDataManager.save()
	_scene_data = SceneDataManager.scene_data
	print_verbose("Saved ComfyUI image to %s, image_filenames: %s" % [save_path, str(arr)])


func _queue_comfy_prompt(workflow_dict: Dictionary) -> String:
	var port: int = int(ImageServerSettingsManager.settings.get("port", 56321))
	var url := "http://127.0.0.1:%d/prompt" % port
	var body := JSON.stringify(workflow_dict)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	add_child(http)
	# Increase timeout for ComfyUI
	http.timeout = 30.0
	var req_err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if req_err != OK:
		push_error("Failed to send ComfyUI prompt request: %s" % error_string(req_err))
		http.queue_free()
		return ""
	var result: Array = await http.request_completed
	http.queue_free()
	var result_code: int = result[0]
	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		push_error("ComfyUI prompt request failed code %d" % result_code)
		return ""
	if response_code < 200 or response_code >= 300:
		push_error("ComfyUI prompt HTTP %d: %s" % [response_code, response_body.get_string_from_utf8()])
		return ""
	var j := JSON.new()
	if j.parse(response_body.get_string_from_utf8()) != OK or not j.data is Dictionary:
		push_error("Invalid ComfyUI prompt response JSON")
		return ""
	var prompt_id: String = str(j.data.get("prompt_id", ""))
	if prompt_id.is_empty():
		# some ComfyUI versions return nested
		prompt_id = str(j.data.get("promptId", ""))
	return prompt_id


func _poll_comfy_history(prompt_id: String) -> Dictionary:
	var port: int = int(ImageServerSettingsManager.settings.get("port", 56321))
	var url := "http://127.0.0.1:%d/history/%s" % [port, prompt_id]
	var max_attempts: int = 120  # up to ~60s with 0.5s interval
	for attempt in max_attempts:
		var http := HTTPRequest.new()
		add_child(http)
		http.timeout = 10.0
		var req_err := http.request(url, PackedStringArray(), HTTPClient.METHOD_GET, "")
		if req_err != OK:
			http.queue_free()
			await get_tree().create_timer(0.5).timeout
			continue
		var result: Array = await http.request_completed
		http.queue_free()
		var result_code: int = result[0]
		var response_code: int = result[1]
		var body: PackedByteArray = result[3]
		if result_code != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
			await get_tree().create_timer(0.5).timeout
			continue
		var j := JSON.new()
		if j.parse(body.get_string_from_utf8()) != OK or not j.data is Dictionary:
			await get_tree().create_timer(0.5).timeout
			continue
		# history response is { prompt_id: { outputs: { "5": { images: [...] } } } } or { prompt_id: { ... } }
		var history: Dictionary = j.data as Dictionary
		var entry: Dictionary = {}
		if history.has(prompt_id) and history[prompt_id] is Dictionary:
			entry = history[prompt_id] as Dictionary
		elif not history.is_empty():
			# sometimes wrapped directly
			var first_key: String = history.keys()[0]
			if history[first_key] is Dictionary:
				entry = history[first_key] as Dictionary
		if entry.is_empty():
			await get_tree().create_timer(0.5).timeout
			continue
		# Try to find images in outputs
		var outputs: Dictionary = entry.get("outputs", {}) as Dictionary
		if outputs.is_empty() and entry.has("history"):
			# alternative nesting
			outputs = entry
		for node_id in outputs.keys():
			var node_out: Dictionary = outputs[node_id] as Dictionary if outputs[node_id] is Dictionary else {}
			if node_out.has("images") and node_out["images"] is Array:
				var images: Array = node_out["images"] as Array
				if not images.is_empty() and images[0] is Dictionary:
					return images[0] as Dictionary
		# ComfyUI SaveImage node is "5" — check explicitly
		if outputs.has("5"):
			var n5: Dictionary = outputs["5"] as Dictionary if outputs["5"] is Dictionary else {}
			if n5.has("images") and n5["images"] is Array and not (n5["images"] as Array).is_empty():
				return (n5["images"] as Array)[0] as Dictionary
		await get_tree().create_timer(0.5).timeout
	return {}


func _download_comfy_image(filename: String, subfolder: String, img_type: String, uuid: String) -> String:
	var port: int = int(ImageServerSettingsManager.settings.get("port", 56321))
	# Build /view URL — ComfyUI expects ?filename=&subfolder=&type=
	var url := "http://127.0.0.1:%d/view?filename=%s&subfolder=%s&type=%s" % [port, filename.uri_encode(), subfolder.uri_encode(), img_type.uri_encode()]
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 30.0
	var req_err := http.request(url, PackedStringArray(), HTTPClient.METHOD_GET, "")
	if req_err != OK:
		push_error("Failed to request ComfyUI image view: %s" % error_string(req_err))
		http.queue_free()
		return ""
	var result: Array = await http.request_completed
	http.queue_free()
	var result_code: int = result[0]
	var response_code: int = result[1]
	var body: PackedByteArray = result[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		push_error("ComfyUI image download failed result_code %d" % result_code)
		return ""
	if response_code < 200 or response_code >= 300:
		push_error("ComfyUI image view HTTP %d" % response_code)
		return ""
	if body.is_empty():
		push_error("ComfyUI image view returned empty body")
		return ""

	# Save to user://saves/<uuid>/images/<filename>
	# fallback uuid dir if empty
	if uuid.strip_edges().is_empty():
		uuid = "default"
	var dir_path := "user://saves/%s/images" % uuid
	# ensure saves and subdirs exist
	if not DirAccess.dir_exists_absolute("user://saves"):
		var e0 := DirAccess.make_dir_absolute("user://saves")
		if e0 != OK:
			push_error("Failed to create user://saves: %s" % error_string(e0))
			return ""
	if not DirAccess.dir_exists_absolute(dir_path):
		var e1 := DirAccess.make_dir_recursive_absolute(dir_path)
		if e1 != OK:
			push_error("Failed to create images dir %s: %s" % [dir_path, error_string(e1)])
			return ""
	var save_path := "%s/%s" % [dir_path, filename]
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open %s for writing" % save_path)
		return ""
	file.store_buffer(body)
	file.close()
	return save_path


func _set_background_from_file(user_path: String) -> void:
	# user_path is like user://saves/.../images/SN_00001_.png
	var global_path := ProjectSettings.globalize_path(user_path)
	var img := Image.new()
	var err: Error = img.load(global_path)
	if err != OK:
		# try direct user:// path (Godot 4 may load user:// directly)
		err = img.load(user_path)
	if err != OK:
		push_warning("Failed to load generated image %s: %s" % [user_path, error_string(err)])
		return
	var tex := ImageTexture.create_from_image(img)
	%BackgroundImage.texture = tex
	%BackgroundImage.modulate = Color(1, 1, 1, 1)

# ------------------------------------------------------------------
# Input handlers
# ------------------------------------------------------------------
# Trigger: virtual Node._input / _unhandled_input — called automatically by Godot's
# input dispatch (no signal connection needed). _input is used so right-click
# works even when GUI Controls (Dialogue/TopBar) would otherwise mark the event
# as handled and prevent _unhandled_input from firing.
func _input(event: InputEvent) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	pass


func _toggle_chrome() -> void:
	pass


func _on_dialog_area_input(event: InputEvent) -> void:
	pass


func _on_prev_dialog_pressed() -> void:
	if total_dialogue <= 1:
		return
	if current_dialogue_index > 0:
		current_dialogue_index -= 1
		_show_current_dialogue()


func _on_next_dialog_pressed() -> void:
	if total_dialogue <= 1:
		return
	if current_dialogue_index < total_dialogue - 1:
		current_dialogue_index += 1
		_show_current_dialogue()


func _on_prev_scene_pressed() -> void:
	pass

func _on_next_scene_pressed() -> void:
	pass


func _on_dialog_btn_pressed() -> void:
	pass


func _on_image_btn_pressed() -> void:
	pass


func _on_plot_pressed() -> void:
	pass


func _on_setting_pressed() -> void:
	if has_node("%GameSettingsOverlay"):
		%GameSettingsOverlay.open()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_play_audio_pressed() -> void:
	pass


func _on_settings_closed() -> void:
	_update_labels()


func _extract_json(text: String) -> String:
	var t := text.strip_edges()
	if t.begins_with("```"):
		var start := t.find("\n")
		var end := t.rfind("```")
		if start != -1 and end != -1 and end > start:
			t = t.substr(start + 1, end - start - 1).strip_edges()
		else:
			t = t.replace("```json", "").replace("```", "").strip_edges()
	return t


func _repair_llm_json_text(text: String) -> String:
	# LLM often emits image_prompt with bare quotes like "recurring" instead of \"recurring\",
	# which breaks JSON parsing. Repair by sanitizing the image_prompt value before parse.
	var key := "\"image_prompt\""
	var idx := text.find(key)
	if idx == -1:
		return text
	var colon := text.find(":", idx + key.length())
	if colon == -1:
		return text
	var first_quote := text.find("\"", colon)
	if first_quote == -1:
		return text
	# Find the closing delimiter before "summary" — look for the last '",' before summary key
	var summary_key := "\"summary\""
	var summary_idx := text.find(summary_key, first_quote)
	if summary_idx == -1:
		# Fallback: try "end" or "language"
		summary_idx = text.find("\"end\"", first_quote)
		if summary_idx == -1:
			summary_idx = text.find("\"language\"", first_quote)
		if summary_idx == -1:
			return text
	# The image_prompt's closing quote is the '",' immediately before summary (allow whitespace)
	var close_seq := text.rfind("\",", summary_idx)
	if close_seq == -1 or close_seq <= first_quote:
		return text
	# Also handle the case where value ends with \" then ",
	var raw_val := text.substr(first_quote + 1, close_seq - first_quote - 1)
	# Sanitize: strip escaped and unescaped quotes, newlines, and Danbooru tag noise
	var sanitized := raw_val.replace("\\\"", "").replace("\\", "").replace("\"", "").replace("'", "").replace("\n", " ").replace("\r", " ")
	# Collapse whitespace and clean trailing commas
	sanitized = sanitized.strip_edges()
	# Remove duplicate commas
	while sanitized.find(",,") != -1:
		sanitized = sanitized.replace(",,", ",")
	# Rebuild text with sanitized value (no inner quotes, safe for JSON)
	var before := text.substr(0, first_quote + 1)
	var after := text.substr(close_seq)
	return before + sanitized + after


func _sanitize_image_prompt(prompt: String) -> String:
	# Remove any characters that would break workflow JSON insertion.
	# Keep only danbooru-safe chars: letters, numbers, comma, underscore, hyphen, space
	var s := prompt.strip_edges()
	# Remove surrounding quotes if any
	s = s.replace("\\\"", "").replace("\\", "").replace("\"", "").replace("'", "")
	s = s.replace("\n", " ").replace("\r", " ").replace("\t", " ")
	# Remove player_input_for_the_next_step marker if LLM left it as literal tag
	s = s.replace("player_input_for_the_next_step", "")
	# Collapse whitespace and commas
	while s.find("  ") != -1:
		s = s.replace("  ", " ")
	while s.find(",,") != -1:
		s = s.replace(",,", ",")
	s = s.strip_edges()
	# Trim leading/trailing commas
	while s.begins_with(","):
		s = s.substr(1).strip_edges()
	while s.ends_with(","):
		s = s.substr(0, s.length() - 1).strip_edges()
	return s


func _handle_new_story() -> void:
	var result: Dictionary = await LLMManager.request_new_story()
	print_verbose("LLM request_new_story result: %s" % str(result))
	if not result.get("success", false):
		show_error(str(result.get("error", "Failed to generate story")))
		return
	var raw_text: String = str(result.get("text", ""))
	var json_str: String = _extract_json(raw_text)
	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK or not json.data is Dictionary:
		# Try to repair common LLM malformed image_prompt (bare quotes) and re-parse
		var repaired := _repair_llm_json_text(json_str)
		if repaired != json_str:
			print_verbose("Attempting repaired JSON parse for image_prompt bare quotes")
			json = JSON.new()
			err = json.parse(repaired)
			if err == OK and json.data is Dictionary:
				json_str = repaired
			else:
				# Fallback: try fallback extraction for image_prompt even if still invalid,
				# then attempt to recover other fields via manual parse
				print_verbose("Repaired JSON still invalid: %s" % error_string(err))
		if err != OK or not json.data is Dictionary:
			show_error("LLM returned invalid JSON: " + raw_text.substr(0, 300))
			return
	var llm_data: Dictionary = json.data as Dictionary
	# Sanitize image_prompt immediately after parse — remove stray quotes that would break workflow JSON
	if llm_data.has("image_prompt"):
		var raw_prompt: String = str(llm_data.get("image_prompt", ""))
		var clean_prompt: String = _sanitize_image_prompt(raw_prompt)
		if clean_prompt != raw_prompt:
			print_verbose("Sanitized image_prompt from '%s' to '%s'" % [raw_prompt.substr(0, 80), clean_prompt.substr(0, 80)])
		llm_data["image_prompt"] = clean_prompt
	print_verbose("Parsed llm_data image_prompt: '%s'" % str(llm_data.get("image_prompt", "<missing>")))
	# Don't modify the format of the LLM JSON – just extract and merge into SceneDataManager.scene_data
	if SceneDataManager.scene_data.is_empty():
		SceneDataManager.scene_data = llm_data.duplicate(true)
		if not SceneDataManager.scene_data.has("id"):
			SceneDataManager.scene_data["id"] = str(GameProgressManager.settings.get("current_uuid", ""))
	else:
		for key in llm_data.keys():
			SceneDataManager.scene_data[key] = llm_data[key]
	# Ensure essential meta fields remain if LLM omitted them
	if not SceneDataManager.scene_data.has("id"):
		SceneDataManager.scene_data["id"] = str(GameProgressManager.settings.get("current_uuid", ""))
	if not SceneDataManager.scene_data.has("version"):
		SceneDataManager.scene_data["version"] = "1.0"
	SceneDataManager.save()
	_scene_data = SceneDataManager.scene_data
	# Mark progress as running so next load doesn't re-request
	GameProgressManager.settings["game_status"] = "running"
	GameProgressManager.save_settings()
	print_verbose("Final scene data: " + str(SceneDataManager.scene_data))
	print_verbose("Final game progress settings: " + str(GameProgressManager.settings))
# ------------------------------------------------------------------
# Choice overlay (array of scene.next)
# ------------------------------------------------------------------
func _show_choice_overlay() -> void:
	%CustomInput.text = ""
	%CustomInput.placeholder_text = I18n.translate("choice_custom_placeholder") if I18n.translate("choice_custom_placeholder") != "choice_custom_placeholder" else "Or write what you want to do..."
	%ChoiceOverlay.visible = true


func _hide_choice_overlay() -> void:
	%ChoiceOverlay.visible = false


func _on_choice_button_pressed(choice_text: String) -> void:
	_hide_choice_overlay()
	pass


func _on_choice_confirm() -> void:
	pass
	# _hide_choice_overlay()
	# await _advance_with_choice(chosen)


func _on_choice_cancel() -> void:
	_hide_choice_overlay()


func _advance_with_choice(choice_text: String) -> void:
	pass


# ------------------------------------------------------------------
# Error handling — common error return dialog for returning to main menu
# ------------------------------------------------------------------
func show_error(message: String) -> void:
	%ErrorReturnDialog.dialog_text = message if not message.is_empty() else I18n.translate("error_dialog_text")
	%ErrorReturnDialog.title = I18n.translate("error_dialog_title")
	%ErrorReturnDialog.popup_centered()


func _on_error_return() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _update_labels() -> void:
	%DialogButton.text = I18n.translate("btn_dialog") if I18n.translate("btn_dialog") != "btn_dialog" else "Dialog"
	%ImageButton.text = I18n.translate("btn_image") if I18n.translate("btn_image") != "btn_image" else "Image"
	%PlotButton.text = I18n.translate("btn_plot") if I18n.translate("btn_plot") != "btn_plot" else "Plot"
	%PlayAudioButton.text = I18n.translate("btn_play_audio") if I18n.translate("btn_play_audio") != "btn_play_audio" else "Play"
	%PrevDialogButton.text = I18n.translate("btn_prev_dialog") if I18n.translate("btn_prev_dialog") != "btn_prev_dialog" else "< Prev"
	# NextDialog text is dynamic in _show_dialog
	%PrevSceneButton.text = I18n.translate("btn_prev_scene") if I18n.translate("btn_prev_scene") != "btn_prev_scene" else "< Scene"
	%NextSceneButton.text = I18n.translate("btn_next_scene") if I18n.translate("btn_next_scene") != "btn_next_scene" else "Next Scene >"
	%SettingButton.text = I18n.translate("btn_setting") if I18n.translate("btn_setting") != "btn_setting" else "Setting"
	%BackButton.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	%ChoiceCancel.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	%ChoiceConfirm.text = I18n.translate("btn_confirm") if I18n.translate("btn_confirm") != "btn_confirm" else "Confirm"
	%CustomInput.placeholder_text = I18n.translate("choice_custom_placeholder") if I18n.translate("choice_custom_placeholder") != "choice_custom_placeholder" else "Or write what you want to do..."
