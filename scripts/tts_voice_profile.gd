class_name TTSVoiceProfile
extends RefCounted

const CANTONESE_MALE_PITCH_SCALE := 0.7
const JAPANESE_MALE_PITCH_SCALE := 0.76
const JAPANESE_MALE_PLAYBACK_SCALE := 0.92


static func resolve(language: String, sex: String) -> Dictionary:
	var normalized_language := language.strip_edges().to_lower()
	var normalized_sex := sex.strip_edges().to_lower()
	var is_male := normalized_sex in ["male", "man", "boy"]
	if not is_male:
		return {"pitch_scale": 1.0, "playback_scale": 1.0}
	var is_japanese := normalized_language == "ja" or normalized_language.begins_with("ja_") or normalized_language.begins_with("ja-") or normalized_language.contains("japanese")
	if is_japanese:
		return {
			"pitch_scale": JAPANESE_MALE_PITCH_SCALE,
			"playback_scale": JAPANESE_MALE_PLAYBACK_SCALE,
		}
	var is_cantonese := normalized_language == "yue" or normalized_language == "zh_hk" or normalized_language.contains("cantonese")
	if is_cantonese:
		return {"pitch_scale": CANTONESE_MALE_PITCH_SCALE, "playback_scale": 1.0}
	return {"pitch_scale": 1.0, "playback_scale": 1.0}
