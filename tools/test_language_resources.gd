extends SceneTree

const I18nScript = preload("res://scripts/i18n.gd")
const EXPECTED_LANGUAGES := ["en", "zh_CN", "zh_TW", "yue", "ja"]
const REQUIRED_PROMPTS := [
	"enhance",
	"random",
	"scene",
	"story",
	"themes",
	"common/choices",
	"common/ending",
	"common/free_danbooru_guardrail",
	"common/free_guardrail",
	"common/output_json_requirement",
	"common/output_template.json",
	"common/safe_danbooru_guardrail",
	"common/safe_guardrail",
	"common/story_background_requirement",
]

var _failures := 0
var _i18n := I18nScript.new()


func _initialize() -> void:
	_test_translation_contract()
	_test_prompt_contract()
	if _failures == 0:
		print("LanguageResources: all tests passed")
	_i18n.free()
	quit(_failures)


func _test_translation_contract() -> void:
	_expect(I18nScript.LANGUAGES == EXPECTED_LANGUAGES, "language list matches supported languages")
	var english: Dictionary = _i18n._translations.get("en", {})
	for language in EXPECTED_LANGUAGES:
		var translations: Dictionary = _i18n._translations.get(language, {})
		_expect(not translations.is_empty(), "%s has translations" % language)
		for key in english:
			_expect(translations.has(key), "%s contains translation key %s" % [language, key])


func _test_prompt_contract() -> void:
	for language in EXPECTED_LANGUAGES:
		for relative_path in REQUIRED_PROMPTS:
			var path := "res://data/llm/%s/%s" % [language, relative_path]
			_expect(FileAccess.file_exists(path), "%s prompt exists" % path)
		var template_path := "res://data/llm/%s/common/output_template.json" % language
		var file := FileAccess.open(template_path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		_expect(parsed is Dictionary, "%s template is valid JSON" % language)
		if parsed is Dictionary:
			_expect(str(parsed.get("language", "")) == language, "%s template preserves its language code" % language)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("LanguageResources test failed: %s" % message)
