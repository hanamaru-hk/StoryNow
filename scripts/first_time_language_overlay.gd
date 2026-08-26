extends Control

signal language_selected(lang: String)


func _ready() -> void:
	%EnglishButton.pressed.connect(func(): _choose_language("en"))
	%ZhCNButton.pressed.connect(func(): _choose_language("zh_CN"))
	%ZhTWButton.pressed.connect(func(): _choose_language("zh_TW"))
	%CantoneseButton.pressed.connect(func(): _choose_language("yue"))
	_update_labels()


func open() -> void:
	visible = true
	_update_labels()


func _choose_language(lang: String) -> void:
	GameSettingsManager.set_language(lang)
	visible = false
	language_selected.emit(lang)


func _update_labels() -> void:
	# Show trilingual title/remark so user understands regardless of current language,
	# but also support i18n if we want single-language display after selection.
	# Using combined string for first-time accessibility.
	%Title.text = "Please choose your language / 请选择你的语言 / 請選擇你的語言 / 請選擇你嘅語言"
	%Remark.text = "You can change this afterwards in Game Settings / 你可以在游戏设置中更改 / 你可以在遊戲設定中更改 / 之後可以喺遊戲設定入面更改"
