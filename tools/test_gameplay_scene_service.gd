extends SceneTree

const Service = preload("res://scripts/gameplay_scene_service.gd")

var _failures := 0


func _initialize() -> void:
	_test_generation_parsing()
	_test_scene_merge()
	_test_new_choice_transition()
	_test_existing_choice_transition()
	if _failures == 0:
		print("GameplaySceneService: all tests passed")
	quit(_failures)


func _test_generation_parsing() -> void:
	var result := Service.parse_generation_result({
		"success": true,
		"title": "Arrival",
		"text": "```json\n{\"title\":\"Arrival\",\"interactions\":[],\"image_prompt\":\"city\"}\n```",
	})
	_expect(result.get("success", false), "parses fenced LLM JSON")
	_expect(result.get("data", {}).get("title", "") == "Arrival", "returns parsed scene data")


func _test_scene_merge() -> void:
	var merged := Service.merge_generated_scene(
		{"uuid": "child", "prev_uuid": "parent", "version": "0.9", "current_round": 3},
		{"uuid": "bad", "prev_uuid": "bad", "title": "Generated", "end": false},
		"child",
		3,
		3,
		true
	)
	_expect(merged["uuid"] == "child" and merged["prev_uuid"] == "parent", "preserves navigation metadata")
	_expect(merged["current_round"] == 3 and merged["end"], "preserves round and enforces story end")


func _test_new_choice_transition() -> void:
	var transition := Service.build_choice_transition(
		{"uuid": "parent", "choices": [{"plot": "Go north"}]},
		"Go north",
		2,
		"en",
		"child"
	)
	_expect(transition.get("success", false) and not transition["reused"], "creates a new branch")
	_expect(transition["parent_scene"]["choices"][0]["uuid"] == "child", "links parent choice to child")
	_expect(transition["target_scene"]["prev_uuid"] == "parent", "links child back to parent")
	var recovered := Service.build_choice_transition(
		{"uuid": "parent", "choices": "invalid legacy value"},
		"Custom route",
		2,
		"en",
		"child-2"
	)
	_expect(recovered.get("success", false), "recovers a malformed choices field")


func _test_existing_choice_transition() -> void:
	var transition := Service.build_choice_transition(
		{"uuid": "parent", "choices": [{"plot": "Go north", "uuid": "existing"}]},
		"go NORTH",
		2,
		"en",
		"unused"
	)
	_expect(transition.get("success", false) and transition["reused"], "reuses an existing branch")
	_expect(transition["target_uuid"] == "existing", "returns the existing child uuid")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("GameplaySceneService test failed: %s" % message)
