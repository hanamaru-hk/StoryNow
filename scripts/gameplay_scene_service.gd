class_name GameplaySceneService
extends RefCounted

const CURRENT_VERSION := "1.0"


static func generation_flow_for_round(current_round: int) -> String:
	return "new_story" if current_round == 1 else "new_scene"


static func parse_generation_result(result: Dictionary) -> Dictionary:
	var title := str(result.get("title", "")).strip_edges()
	if not result.get("success", false):
		return {
			"success": false,
			"error": str(result.get("error", "Generation request failed")),
			"title": title,
		}

	var raw_text := str(result.get("text", ""))
	var json_text := _extract_json(raw_text)
	var parsed := _parse_dictionary(json_text)
	if parsed.is_empty():
		var repaired_text := _repair_image_prompt(json_text)
		if repaired_text != json_text:
			parsed = _parse_dictionary(repaired_text)
	if parsed.is_empty():
		return {
			"success": false,
			"error": "invalid_json",
			"title": title,
		}
	return {
		"success": true,
		"data": parsed,
		"title": title,
	}
static func merge_generated_scene(
	existing_scene: Dictionary,
	generated_scene: Dictionary,
	current_uuid: String,
	current_round: int,
	expected_rounds: int,
	preserve_navigation: bool
) -> Dictionary:
	var merged := existing_scene.duplicate(true)
	var preserved_uuid := str(merged.get("uuid", current_uuid))
	var preserved_prev_uuid := str(merged.get("prev_uuid", ""))
	var preserved_version := str(merged.get("version", CURRENT_VERSION))
	var preserved_round: Variant = merged.get("current_round", current_round)

	for key in generated_scene:
		merged[key] = generated_scene[key]

	if preserve_navigation:
		merged["uuid"] = preserved_uuid
		if not preserved_prev_uuid.is_empty():
			merged["prev_uuid"] = preserved_prev_uuid
		merged["version"] = preserved_version
		merged["current_round"] = preserved_round
		merged["id"] = str(merged.get("id", preserved_uuid))
	else:
		merged["uuid"] = str(merged.get("uuid", current_uuid))
		merged["version"] = str(merged.get("version", CURRENT_VERSION))

	merged["current_image_index"] = int(merged.get("current_image_index", 0))
	if expected_rounds > 0 and current_round >= expected_rounds:
		merged["end"] = true
	return merged


static func build_choice_transition(
	scene: Dictionary,
	choice_text: String,
	current_round: int,
	language: String,
	new_uuid: String
) -> Dictionary:
	var normalized_text := choice_text.strip_edges()
	if normalized_text.is_empty():
		return {"success": false, "error": "empty_choice"}

	var parent_scene := scene.duplicate(true)
	var raw_choices: Variant = parent_scene.get("choices", [])
	var choices: Array = raw_choices if raw_choices is Array else []

	var choice_index := _find_choice(choices, normalized_text)
	if choice_index == -1:
		choice_index = choices.size()
		choices.append({"plot": normalized_text})
	elif not choices[choice_index] is Dictionary:
		choices[choice_index] = {"plot": str(choices[choice_index])}

	var entry: Dictionary = choices[choice_index] as Dictionary
	var existing_uuid := str(entry.get("uuid", "")).strip_edges()
	parent_scene["choices"] = choices
	if not existing_uuid.is_empty():
		return {
			"success": true,
			"reused": true,
			"target_uuid": existing_uuid,
			"parent_scene": parent_scene,
			"next_round": current_round + 1,
		}

	var parent_uuid := str(parent_scene.get("uuid", ""))
	entry["uuid"] = new_uuid
	choices[choice_index] = entry
	parent_scene["choices"] = choices
	parent_scene["end"] = false

	return {
		"success": true,
		"reused": false,
		"target_uuid": new_uuid,
		"parent_scene": parent_scene,
		"next_round": current_round + 1,
		"target_scene": {
			"uuid": new_uuid,
			"prev_uuid": parent_uuid,
			"image_filenames": [],
			"current_image_index": 0,
			"image_prompt": "",
			"instruction": [],
			"interactions": [],
			"choices": [],
			"language": language,
			"summary": "",
			"version": CURRENT_VERSION,
			"current_round": current_round + 1,
			"player_input": normalized_text,
			"game_status": "new_scene",
		}
	}


static func generate_uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes: Array = []
	for i in 16:
		bytes.append(rng.randi_range(0, 255))
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5], bytes[6], bytes[7],
		bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
	]


static func _find_choice(choices: Array, choice_text: String) -> int:
	var normalized_text := choice_text.to_lower()
	for index in choices.size():
		var choice = choices[index]
		var plot := ""
		if choice is Dictionary:
			plot = str(choice.get("plot", choice.get("text", choice.get("choice", ""))))
		else:
			plot = str(choice)
		if plot.strip_edges().to_lower() == normalized_text:
			return index
	return -1


static func _parse_dictionary(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	return (json.data as Dictionary).duplicate(true)


static func _extract_json(text: String) -> String:
	var extracted := text.strip_edges()
	if not extracted.begins_with("```"):
		return extracted
	var start := extracted.find("\n")
	var end := extracted.rfind("```")
	if start != -1 and end > start:
		return extracted.substr(start + 1, end - start - 1).strip_edges()
	return extracted.replace("```json", "").replace("```", "").strip_edges()


static func _repair_image_prompt(text: String) -> String:
	var key := "\"image_prompt\""
	var key_index := text.find(key)
	if key_index == -1:
		return text
	var colon := text.find(":", key_index + key.length())
	if colon == -1:
		return text
	var first_quote := text.find("\"", colon)
	if first_quote == -1:
		return text
	var next_key_index := text.find("\"summary\"", first_quote)
	if next_key_index == -1:
		next_key_index = text.find("\"end\"", first_quote)
	if next_key_index == -1:
		next_key_index = text.find("\"language\"", first_quote)
	if next_key_index == -1:
		return text
	var close_quote := text.rfind("\",", next_key_index)
	if close_quote <= first_quote:
		return text
	var value := text.substr(first_quote + 1, close_quote - first_quote - 1)
	value = value.replace("\\\"", "").replace("\\", "").replace("\"", "").replace("'", "")
	value = value.replace("\n", " ").replace("\r", " ").strip_edges()
	while value.contains(",,"):
		value = value.replace(",,", ",")
	return text.substr(0, first_quote + 1) + value + text.substr(close_quote)
