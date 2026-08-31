extends SceneTree

const SettingsValidator := preload("res://scripts/settings_value_validator.gd")

var _failures := 0


func _init() -> void:
	_test_non_negative_values()
	_test_ports_and_timeouts()
	_test_image_dimensions()
	if _failures == 0:
		print("SettingsValueValidator: all tests passed")
	quit(_failures)


func _test_non_negative_values() -> void:
	_expect(SettingsValidator.is_non_negative_integer("0"), "zero is a valid non-negative value")
	_expect(SettingsValidator.is_non_negative_integer(10.0), "whole JSON numbers are accepted")
	_expect(SettingsValidator.non_negative_integer_or_default(10.0, 0) == 10, "whole JSON numbers retain their value")
	_expect(not SettingsValidator.is_non_negative_integer("-1"), "negative values are rejected")
	_expect(not SettingsValidator.is_non_negative_integer(1.5), "fractional values are rejected")
	_expect(SettingsValidator.non_negative_integer_or_default("-1", 7) == 7, "invalid progress values use their default")


func _test_ports_and_timeouts() -> void:
	_expect(SettingsValidator.is_valid_port("1"), "lowest port is accepted")
	_expect(SettingsValidator.port_or_default(48763.0, 1) == 48763, "JSON port numbers retain their value")
	_expect(SettingsValidator.is_valid_port("65535"), "highest port is accepted")
	_expect(not SettingsValidator.is_valid_port("0"), "zero port is rejected")
	_expect(not SettingsValidator.is_valid_port("65536"), "out-of-range port is rejected")
	_expect(SettingsValidator.port_or_default("-2", 48763) == 48763, "invalid persisted port uses its default")
	_expect(SettingsValidator.is_valid_timeout("1"), "positive timeout is accepted")
	_expect(SettingsValidator.timeout_or_default(240.0, 1) == 240, "JSON timeout numbers retain their value")
	_expect(not SettingsValidator.is_valid_timeout("0"), "zero timeout is rejected")
	_expect(SettingsValidator.timeout_or_default("invalid", 240) == 240, "invalid persisted timeout uses its default")


func _test_image_dimensions() -> void:
	_expect(SettingsValidator.is_valid_image_dimension("16"), "minimum aligned dimension is accepted")
	_expect(SettingsValidator.image_dimension_or_default(1344.0, 16) == "1344", "JSON dimensions retain their value")
	_expect(SettingsValidator.is_valid_image_dimension("1344"), "default width is accepted")
	_expect(SettingsValidator.is_valid_image_dimension("16384"), "maximum dimension is accepted")
	_expect(not SettingsValidator.is_valid_image_dimension("0"), "zero dimension is rejected")
	_expect(not SettingsValidator.is_valid_image_dimension("8"), "dimension below the minimum is rejected")
	_expect(not SettingsValidator.is_valid_image_dimension("1345"), "unaligned dimension is rejected")
	_expect(not SettingsValidator.is_valid_image_dimension("16392"), "dimension above the maximum is rejected")
	_expect(SettingsValidator.image_dimension_or_default("-8", 768) == "768", "invalid persisted dimension uses its default")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("SettingsValueValidator test failed: %s" % message)
