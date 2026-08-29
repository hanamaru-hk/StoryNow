extends Node
## Library functions for managing the ComfyUI (Image Server) process.

const STATUS_PATH := "user://image_server_status.json"
const COMFYUI_DIR := "server/ComfyUI"
const HEALTH_TIMEOUT := 5.0
const WORKFLOW_TEMPLATE_PATH := "data/comfyui/workflow_template.json"
const DEFAULT_MODEL := "waiIllustriousSDXL_v170.safetensors"
const DEFAULT_IMAGE_TIMEOUT := 120.0
const FILENAME_PREFIX := "SN"

signal status_changed(status: Dictionary)

var status := {
	"pid": -1,
	"running": false,
	"healthy": false,
}
var _cancel_requested := false


func _ready() -> void:
	load_status()


func start_server() -> void:
	if status["running"]:
		return
	var port: int = ImageServerSettingsManager.settings["port"]
	var base_path := AppPaths.external_path(COMFYUI_DIR)
	var exe_path := base_path + "/python_embeded/python.exe"
	if not FileAccess.file_exists(exe_path):
		push_error("ComfyUI Python not found: " + exe_path)
		return
	var args := PackedStringArray(["-s", base_path + "/ComfyUI/main.py", "--port", str(port), "--windows-standalone-build", "--disable-auto-launch"])
	var pid: int = OS.create_process(exe_path, args, OS.is_stdout_verbose())
	if pid < 0:
		push_error("Failed to start ComfyUI process")
		return
	status["pid"] = pid
	status["running"] = true
	status["healthy"] = false
	save_status()
	status_changed.emit(status)


func stop_server() -> void:
	if status["pid"] > 0:
		OS.execute("taskkill", ["/T", "/F", "/PID", str(status["pid"])])
		status["pid"] = -1
	status["running"] = false
	status["healthy"] = false
	save_status()
	status_changed.emit(status)


func health_check() -> bool:
	var port: int = ImageServerSettingsManager.settings["port"]
	var http := HTTPClient.new()

	var error := http.connect_to_host("127.0.0.1", port)
	if error != OK:
		_set_unhealthy()
		return false

	var timeout := HEALTH_TIMEOUT

	while http.get_status() == HTTPClient.STATUS_CONNECTING \
			or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		await get_tree().process_frame

		timeout -= get_process_delta_time()
		if timeout <= 0:
			http.close()
			_set_unhealthy()
			return false

	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		http.close()
		_set_unhealthy()
		return false

	error = http.request(
		HTTPClient.METHOD_GET,
		"/system_stats",
		PackedStringArray()
	)

	if error != OK:
		http.close()
		_set_unhealthy()
		return false

	timeout = HEALTH_TIMEOUT

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		await get_tree().process_frame

		timeout -= get_process_delta_time()
		if timeout <= 0:
			http.close()
			_set_unhealthy()
			return false

	if not http.has_response():
		http.close()
		_set_unhealthy()
		return false

	var response_code := http.get_response_code()

	# Consume the response body.
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()

		if chunk.is_empty():
			await get_tree().process_frame

	http.close()

	if response_code >= 200 and response_code < 400:
		status["healthy"] = true
		status["running"] = true
		save_status()
		status_changed.emit(status)
		return true

	_set_unhealthy()
	return false


func _set_unhealthy() -> void:
	status["healthy"] = false
	save_status()
	status_changed.emit(status)


func save_status() -> void:
	var file := FileAccess.open(STATUS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(status, "\t"))
		file.close()


func load_status() -> void:
	if not FileAccess.file_exists(STATUS_PATH):
		return
	var file := FileAccess.open(STATUS_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK and json.data is Dictionary:
			status = json.data


func interrupt_active_generation() -> void:
	_cancel_requested = true
	await _post_comfy_control("/interrupt", "")
	await _post_comfy_control("/queue", JSON.stringify({"clear": true}))


func _post_comfy_control(endpoint: String, body: String) -> void:
	var port: int = int(ImageServerSettingsManager.settings.get("port", 56321))
	var url := "http://127.0.0.1:%d%s" % [port, endpoint]
	var headers := PackedStringArray()
	if not body.is_empty():
		headers.append("Content-Type: application/json")
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 5.0
	var req_err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if req_err == OK:
		await http.request_completed
	http.queue_free()

func _load_workflow_template_text() -> String:
	var workflow_path := AppPaths.external_path(WORKFLOW_TEMPLATE_PATH)
	if not FileAccess.file_exists(workflow_path):
		push_error("workflow_template.json not found: %s" % workflow_path)
		return ""
	var file := FileAccess.open(workflow_path, FileAccess.READ)
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
		candidates = ["data/comfyui/free_negative_prompt", "data/comfyui/free_negatvie_prompt"]
	else:
		candidates = ["data/comfyui/safe_negative_prompt", "data/comfyui/safe_negative_prompts"]
	for p in candidates:
		var candidate_path := AppPaths.external_path(p)
		if FileAccess.file_exists(candidate_path):
			var f := FileAccess.open(candidate_path, FileAccess.READ)
			if f != null:
				var t := f.get_as_text().strip_edges()
				f.close()
				return t
	var fallback_paths: Array[String] = ["data/comfyui/safe_negative_prompt", "data/comfyui/free_negatvie_prompt", "data/comfyui/free_negative_prompt"]
	for p in fallback_paths:
		var fallback_path := AppPaths.external_path(p)
		if FileAccess.file_exists(fallback_path):
			var f2 := FileAccess.open(fallback_path, FileAccess.READ)
			if f2 != null:
				var t2 := f2.get_as_text().strip_edges()
				f2.close()
				if not candidates.has(p):
					return t2
	return ""


func _fix_comfy_workflow_dict(workflow_dict: Dictionary, seed_val: int) -> void:
	if not workflow_dict.has("prompt") or not workflow_dict["prompt"] is Dictionary:
		return
	var prompt: Dictionary = workflow_dict["prompt"] as Dictionary
	if prompt.has("5") and prompt["5"] is Dictionary:
		var n5: Dictionary = prompt["5"] as Dictionary
		if n5.has("inputs") and n5["inputs"] is Dictionary:
			var inputs5: Dictionary = n5["inputs"] as Dictionary
			var cur_images: Variant = inputs5.get("images", null)
			if cur_images is Array and cur_images.size() >= 2:
				if str(cur_images[0]) == "7":
					inputs5["images"] = ["4", 0]
			else:
				inputs5["images"] = ["4", 0]
	if prompt.has("2") and prompt["2"] is Dictionary:
		var n2: Dictionary = prompt["2"] as Dictionary
		if n2.has("inputs") and n2["inputs"] is Dictionary:
			var inputs2: Dictionary = n2["inputs"] as Dictionary
			inputs2["seed"] = int(seed_val)
	if prompt.has("7") and prompt["7"] is Dictionary:
		var n7: Dictionary = prompt["7"] as Dictionary
		if n7.has("inputs") and n7["inputs"] is Dictionary:
			var inputs7: Dictionary = n7["inputs"] as Dictionary
			inputs7["width"] = int(inputs7.get("width", 1344))
			inputs7["height"] = int(inputs7.get("height", 768))
			inputs7["batch_size"] = int(inputs7.get("batch_size", 1))
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
				var idx: Variant = val[1]
				if idx is float or idx is String:
					inputs[key] = [str(val[0]), int(idx)]
				elif idx is int:
					inputs[key] = [str(val[0]), int(idx)]


func _get_image_timeout() -> float:
	return maxf(1.0, float(ImageServerSettingsManager.settings.get("timeout", DEFAULT_IMAGE_TIMEOUT)))


func _queue_comfy_prompt(workflow_dict: Dictionary, request_timeout: float) -> String:
	if _cancel_requested:
		return ""
	var port: int = int(ImageServerSettingsManager.settings.get("port", 56321))
	var url := "http://127.0.0.1:%d/prompt" % port
	var body := JSON.stringify(workflow_dict)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = request_timeout
	var req_err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if req_err != OK:
		push_error("Failed to send ComfyUI prompt request: %s" % error_string(req_err))
		http.queue_free()
		return ""
	var result: Array = await http.request_completed
	http.queue_free()
	if _cancel_requested:
		return ""
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
		prompt_id = str(j.data.get("promptId", ""))
	return prompt_id


func _poll_comfy_history(prompt_id: String, queue_id: int, request_timeout: float) -> Dictionary:
	var port: int = int(ImageServerSettingsManager.settings.get("port", 56321))
	var url := "http://127.0.0.1:%d/history/%s" % [port, prompt_id]
	var max_attempts: int = maxi(1, int(ceil(request_timeout / 0.5)))
	var deadline_msec := Time.get_ticks_msec() + int(request_timeout * 1000.0)
	for attempt in max_attempts:
		if _cancel_requested:
			return {}
		var remaining_seconds := float(deadline_msec - Time.get_ticks_msec()) / 1000.0
		if remaining_seconds <= 0.0:
			break
		await _update_comfy_queue_progress(prompt_id, queue_id, attempt, max_attempts)
		var http := HTTPRequest.new()
		add_child(http)
		http.timeout = maxf(0.5, minf(5.0, remaining_seconds))
		var req_err := http.request(url, PackedStringArray(), HTTPClient.METHOD_GET, "")
		if req_err != OK:
			http.queue_free()
			await get_tree().create_timer(0.5).timeout
			continue
		var result: Array = await http.request_completed
		http.queue_free()
		if _cancel_requested:
			return {}
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
		var history: Dictionary = j.data as Dictionary
		var entry: Dictionary = {}
		if history.has(prompt_id) and history[prompt_id] is Dictionary:
			entry = history[prompt_id] as Dictionary
		elif not history.is_empty():
			var first_key: String = history.keys()[0]
			if history[first_key] is Dictionary:
				entry = history[first_key] as Dictionary
		if entry.is_empty():
			await get_tree().create_timer(0.5).timeout
			continue
		var outputs: Dictionary = entry.get("outputs", {}) as Dictionary
		if outputs.is_empty() and entry.has("history"):
			outputs = entry
		for node_id in outputs.keys():
			var node_out: Dictionary = outputs[node_id] as Dictionary if outputs[node_id] is Dictionary else {}
			if node_out.has("images") and node_out["images"] is Array:
				var images: Array = node_out["images"] as Array
				if not images.is_empty() and images[0] is Dictionary:
					return images[0] as Dictionary
		if outputs.has("5"):
			var n5: Dictionary = outputs["5"] as Dictionary if outputs["5"] is Dictionary else {}
			if n5.has("images") and n5["images"] is Array and not (n5["images"] as Array).is_empty():
				return (n5["images"] as Array)[0] as Dictionary
		await get_tree().create_timer(0.5).timeout
	return {}


func _update_comfy_queue_progress(prompt_id: String, queue_id: int, attempt: int, max_attempts: int) -> void:
	var queue_state := await _get_comfy_queue_state(prompt_id)
	var progress := 0.1
	var status_text := "Queued"
	match str(queue_state.get("state", "")):
		"running":
			progress = 0.25 + 0.65 * clampf(float(attempt) / maxf(float(max_attempts), 1.0), 0.0, 1.0)
			status_text = "Running"
		"pending":
			var position := int(queue_state.get("position", 0))
			progress = 0.1
			status_text = "Queued %d" % position
		"done":
			progress = 0.92
			status_text = "Finalizing"
		_:
			progress = 0.15 + 0.5 * clampf(float(attempt) / maxf(float(max_attempts), 1.0), 0.0, 1.0)
			status_text = "Waiting"
	ServerRuntimeManager.update_request(queue_id, {
		"status": status_text,
		"progress": progress,
	})


func _get_comfy_queue_state(prompt_id: String) -> Dictionary:
	var port: int = int(ImageServerSettingsManager.settings.get("port", 56321))
	var url := "http://127.0.0.1:%d/queue" % port
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 5.0
	var req_err := http.request(url, PackedStringArray(), HTTPClient.METHOD_GET, "")
	if req_err != OK:
		http.queue_free()
		return {"state": "unknown"}
	var result: Array = await http.request_completed
	http.queue_free()
	var result_code: int = result[0]
	var response_code: int = result[1]
	var body: PackedByteArray = result[3]
	if result_code != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return {"state": "unknown"}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {"state": "unknown"}
	var data: Dictionary = json.data as Dictionary
	var running := _find_prompt_in_queue(data.get("queue_running", []), prompt_id)
	if not running.is_empty():
		return {"state": "running"}
	var pending := _find_prompt_in_queue(data.get("queue_pending", []), prompt_id)
	if not pending.is_empty():
		return {"state": "pending", "position": int(pending.get("position", 0))}
	return {"state": "done"}


func _find_prompt_in_queue(items: Variant, prompt_id: String) -> Dictionary:
	if not (items is Array):
		return {}
	var queue_items: Array = items as Array
	for index in range(queue_items.size()):
		var item = queue_items[index]
		if _queue_item_has_prompt_id(item, prompt_id):
			return {"position": index + 1}
	return {}


func _queue_item_has_prompt_id(item: Variant, prompt_id: String) -> bool:
	if item is Dictionary:
		var dict: Dictionary = item as Dictionary
		if str(dict.get("prompt_id", "")) == prompt_id:
			return true
		for value in dict.values():
			if _queue_item_has_prompt_id(value, prompt_id):
				return true
	elif item is Array:
		var array_item: Array = item as Array
		for value in array_item:
			if _queue_item_has_prompt_id(value, prompt_id):
				return true
	elif str(item) == prompt_id:
		return true
	return false


func _download_comfy_image(filename: String, subfolder: String, img_type: String, uuid: String, request_timeout: float) -> String:
	if _cancel_requested:
		return ""
	var port: int = int(ImageServerSettingsManager.settings.get("port", 56321))
	var url := "http://127.0.0.1:%d/view?filename=%s&subfolder=%s&type=%s" % [port, filename.uri_encode(), subfolder.uri_encode(), img_type.uri_encode()]
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = request_timeout
	var req_err := http.request(url, PackedStringArray(), HTTPClient.METHOD_GET, "")
	if req_err != OK:
		push_error("Failed to request ComfyUI image view: %s" % error_string(req_err))
		http.queue_free()
		return ""
	var result: Array = await http.request_completed
	http.queue_free()
	if _cancel_requested:
		return ""
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
	if uuid.strip_edges().is_empty():
		uuid = "default"
	var dir_path := "user://saves/%s/images" % uuid
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


func generate_scene_image(image_prompt: String, uuid: String) -> Dictionary:
	_cancel_requested = false
	var request_timeout := _get_image_timeout()
	var queue_id := ServerRuntimeManager.push_request("image", I18n.translate("request_generating_image"), request_timeout)
	var workflow_text := _load_workflow_template_text()
	if workflow_text.is_empty():
		ServerRuntimeManager.pop_request(queue_id)
		return {"success": false, "error": "Failed to load ComfyUI workflow_template.json", "prompt": image_prompt}
	var model_filename: String = str(ImageServerSettingsManager.settings.get("model_filename", ""))
	if model_filename.is_empty():
		model_filename = DEFAULT_MODEL
	var negative_prompt: String = _load_negative_prompt()
	var image_width: String = str(GameSettingsManager.settings.get("image_width", "1344"))
	var image_height: String = str(GameSettingsManager.settings.get("image_height", "768"))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seed_val: int = rng.randi_range(0, 2147483647)
	workflow_text = workflow_text.replace("__MODEL_FILENAME__", model_filename)
	workflow_text = workflow_text.replace("__MODEL_NAME__", model_filename)
	workflow_text = workflow_text.replace("__POSITIVE_PROMPT__", image_prompt)
	workflow_text = workflow_text.replace("__NEGATIVE_PROMPT__", negative_prompt)
	workflow_text = workflow_text.replace("__FILENAME_PREFIX__", FILENAME_PREFIX)
	workflow_text = workflow_text.replace("__IMAGE_WIDTH__", image_width)
	workflow_text = workflow_text.replace("__IMAGE_HEIGHT__", image_height)
	workflow_text = workflow_text.replace("__SEED__", str(seed_val))
	print_verbose("image prompt" + image_prompt)
	print_verbose("ComfyUI workflow: " + workflow_text)
	var json := JSON.new()
	var err := json.parse(workflow_text)
	if err != OK or not json.data is Dictionary:
		ServerRuntimeManager.pop_request(queue_id)
		return {"success": false, "error": "Invalid ComfyUI workflow template after replacement: %s" % error_string(err), "prompt": image_prompt}
	var workflow_dict: Dictionary = json.data as Dictionary
	_fix_comfy_workflow_dict(workflow_dict, seed_val)
	var prompt_id := await _queue_comfy_prompt(workflow_dict, request_timeout)
	if prompt_id.is_empty():
		ServerRuntimeManager.pop_request(queue_id)
		if _cancel_requested:
			return {"success": false, "cancelled": true, "error": "Cancelled", "prompt": image_prompt}
		return {"success": false, "error": "Failed to queue ComfyUI prompt", "prompt": image_prompt}
	ServerRuntimeManager.update_request(queue_id, {"status": "Queued", "progress": 0.1})
	var image_info := await _poll_comfy_history(prompt_id, queue_id, request_timeout)
	if image_info.is_empty():
		ServerRuntimeManager.pop_request(queue_id)
		if _cancel_requested:
			return {"success": false, "cancelled": true, "error": "Cancelled", "prompt": image_prompt}
		return {"success": false, "error": "ComfyUI did not return image (timeout or error)", "prompt": image_prompt}
	var filename: String = str(image_info.get("filename", ""))
	var subfolder: String = str(image_info.get("subfolder", ""))
	var img_type: String = str(image_info.get("type", "output"))
	if filename.is_empty():
		ServerRuntimeManager.pop_request(queue_id)
		return {"success": false, "error": "ComfyUI history missing filename", "prompt": image_prompt}
	ServerRuntimeManager.update_request(queue_id, {"status": I18n.translate("queue_status_transferring"), "progress": 0.95})
	var save_path := await _download_comfy_image(filename, subfolder, img_type, uuid, request_timeout)
	if save_path.is_empty():
		ServerRuntimeManager.pop_request(queue_id)
		if _cancel_requested:
			return {"success": false, "cancelled": true, "error": "Cancelled", "prompt": image_prompt}
		return {"success": false, "error": "Failed to download ComfyUI image", "prompt": image_prompt}
	ServerRuntimeManager.update_request(queue_id, {"status": "Done", "progress": 1.0})
	ServerRuntimeManager.pop_request(queue_id)
	return {"success": true, "save_path": save_path, "filename": filename, "prompt": image_prompt, "seed": seed_val}
