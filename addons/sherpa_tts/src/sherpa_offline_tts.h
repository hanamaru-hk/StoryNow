#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

struct SherpaOnnxOfflineTts;

namespace godot {

class SherpaOfflineTTS : public RefCounted {
    GDCLASS(SherpaOfflineTTS, RefCounted)

public:
    SherpaOfflineTTS();
    ~SherpaOfflineTTS();

    bool configure_vits(const Dictionary &p_model, int32_t p_num_threads);
    bool synthesize_to_wav(const String &p_text, const String &p_output_filename, const Dictionary &p_model, int32_t p_sid, double p_speed, int32_t p_num_threads);
    bool is_configured() const;
    String get_last_error() const;
    void reset();

protected:
    static void _bind_methods();

private:
    const SherpaOnnxOfflineTts *tts = nullptr;
    Dictionary configured_model;
    int32_t configured_num_threads = 0;
    String last_error;

    bool _same_config(const Dictionary &p_model, int32_t p_num_threads) const;
    void _set_error(const String &p_error);
};

} // namespace godot
