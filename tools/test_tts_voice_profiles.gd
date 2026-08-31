extends SceneTree

const VoiceProfile = preload("res://scripts/tts_voice_profile.gd")

var _failures := 0


func _initialize() -> void:
	_test_profile("ja", "male", 0.76, 0.92)
	_test_profile("ja-JP", "man", 0.76, 0.92)
	_test_profile("ja", "female", 1.0, 1.0)
	_test_profile("yue", "boy", 0.7, 1.0)
	_test_profile("en", "male", 1.0, 1.0)

	if _failures == 0:
		print("TTSVoiceProfiles: all tests passed")
	quit(_failures)


func _test_profile(language: String, sex: String, expected_pitch: float, expected_playback: float) -> void:
	var profile: Dictionary = VoiceProfile.resolve(language, sex)
	_expect(is_equal_approx(float(profile.get("pitch_scale", 0.0)), expected_pitch), "%s/%s pitch" % [language, sex])
	_expect(is_equal_approx(float(profile.get("playback_scale", 0.0)), expected_playback), "%s/%s playback" % [language, sex])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("TTS voice profile test failed: %s" % message)
