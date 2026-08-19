extends Node

const LANGUAGES := ["en", "zh_CN", "zh_TW"]
const DEFAULT_LANG := "en"

var current_lang: String = DEFAULT_LANG

var _translations := {
	"en": {
		"main_title": "Instant Visual Novel",
		"btn_start": "Start",
		"btn_load": "Load",
		"btn_gallery": "Gallery",
		"btn_game_setting": "Game Setting",
		"btn_image_setting": "Image Setting",
		"btn_llm_setting": "LLM Setting",
		"btn_exit": "Exit",
		"prompt_title": "Story Background",
		"prompt_desc": "Describe the world, characters, and mood for your story. Leave blank and press Random to let the AI decide.",
		"prompt_placeholder": "e.g. A dark fantasy world where magic is fading. The protagonist is a young mage discovering forbidden powers...",
		"btn_random": "Random",
		"btn_enhance": "Enhance",
		"btn_back": "Back",
		"btn_reset": "Reset",
		"btn_save": "Save",
		"settings_title": "Game Settings",
		"settings_language": "Language",
		"settings_screen_size": "Screen Size",
		"settings_screen_full": "Full",
		"settings_screen_1344": "1344 x 768",
		"settings_port": "Port",
		"image_settings_title": "Image Settings",
		"llm_settings_title": "LLM Settings",
		"lang_en": "English",
		"lang_zh_cn": "简体中文",
		"lang_zh_tw": "繁體中文",
	},
	"zh_CN": {
		"main_title": "即时视觉小说",
		"btn_start": "开始",
		"btn_load": "加载",
		"btn_gallery": "画廊",
		"btn_game_setting": "游戏设置",
		"btn_image_setting": "图像设置",
		"btn_llm_setting": "LLM 设置",
		"btn_exit": "退出",
		"prompt_title": "故事背景",
		"prompt_desc": "描述你故事的世界、角色和氛围。留空并按随机让AI决定。",
		"prompt_placeholder": "例如：一个魔法正在消退的黑暗奇幻世界。主角是一位发现禁忌力量的年轻法师...",
		"btn_random": "随机",
		"btn_enhance": "增强",
		"btn_back": "返回",
		"btn_save": "保存",
		"btn_reset": "重置",
		"settings_title": "游戏设置",
		"settings_language": "语言",
		"settings_screen_size": "屏幕尺寸",
		"settings_screen_full": "全屏",
		"settings_screen_1344": "1344 x 768",
		"settings_port": "端口",
		"image_settings_title": "图像设置",
		"llm_settings_title": "LLM 设置",
		"lang_en": "English",
		"lang_zh_cn": "简体中文",
		"lang_zh_tw": "繁體中文",
	},
	"zh_TW": {
		"main_title": "即時視覺小說",
		"btn_start": "開始",
		"btn_load": "載入",
		"btn_gallery": "畫廊",
		"btn_game_setting": "遊戲設定",
		"btn_image_setting": "影像設定",
		"btn_llm_setting": "LLM 設定",
		"btn_exit": "退出",
		"prompt_title": "故事背景",
		"prompt_desc": "描述你故事的世界、角色和氛圍。留空並按隨機讓AI決定。",
		"prompt_placeholder": "例如：一個魔法正在消退的黑暗奇幻世界。主角是一位發現禁忌力量的年輕法師...",
		"btn_random": "隨機",
		"btn_enhance": "增強",
		"btn_back": "返回",
		"btn_save": "儲存",
		"btn_reset": "重設",
		"settings_title": "遊戲設定",
		"settings_language": "語言",
		"settings_screen_size": "螢幕尺寸",
		"settings_screen_full": "全螢幕",
		"settings_screen_1344": "1344 x 768",
		"settings_port": "連接埠",
		"image_settings_title": "影像設定",
		"llm_settings_title": "LLM 設定",
		"lang_en": "English",
		"lang_zh_cn": "简体中文",
		"lang_zh_tw": "繁體中文",
	},
}


func set_language(lang: String) -> void:
	if lang not in LANGUAGES:
		return
	current_lang = lang
	TranslationServer.set_locale(lang)


func translate(key: String) -> String:
	if _translations.has(current_lang) and _translations[current_lang].has(key):
		return _translations[current_lang][key]
	return key
