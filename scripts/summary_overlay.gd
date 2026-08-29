extends Control

signal closed
signal summary_saved(summary: String)

func _ready() -> void:
	%Back.pressed.connect(_on_back_pressed)
	%Save.pressed.connect(_on_save_pressed)
	_load_summary()
	_update_labels()
	visible = false


func open() -> void:
	visible = true
	_load_summary()
	_update_labels()
	%Save.disabled = false
	%Back.disabled = false
	%SummaryInput.editable = true


func _load_summary() -> void:
	if has_node("%SummaryInput"):
		%SummaryInput.text = str(SceneDataManager.scene_data.get("summary", ""))
		%SummaryInput.editable = true


func _on_back_pressed() -> void:
	visible = false
	closed.emit()


func _on_save_pressed() -> void:
	var txt: String = %SummaryInput.text if %SummaryInput.text != null else ""
	SceneDataManager.scene_data["summary"] = txt
	SceneDataManager.save()
	summary_saved.emit(txt)
	visible = false
	closed.emit()


func _update_labels() -> void:
	if has_node("%Title"):
		%Title.text = I18n.translate("summary_overlay_title") if I18n.translate("summary_overlay_title") != "summary_overlay_title" else "Summary"
	if has_node("%Back"):
		%Back.text = I18n.translate("btn_back") if I18n.translate("btn_back") != "btn_back" else "Back"
	if has_node("%Save"):
		%Save.text = I18n.translate("btn_save") if I18n.translate("btn_save") != "btn_save" else "Save"
	if has_node("%SummaryInput"):
		%SummaryInput.placeholder_text = I18n.translate("summary_placeholder") if I18n.translate("summary_placeholder") != "summary_placeholder" else "Summary..."
