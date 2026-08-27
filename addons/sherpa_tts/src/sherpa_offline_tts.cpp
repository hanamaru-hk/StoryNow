#include "sherpa_offline_tts.h"

#include <sherpa-onnx/c-api/c-api.h>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cstring>

using namespace godot;

namespace {

std::string to_utf8(const String &p_value) {
    CharString utf8 = p_value.utf8();
    return std::string(utf8.get_data());
}

const char *dict_cstr(const Dictionary &p_dict, const char *p_key, std::string &r_storage) {
    if (!p_dict.has(p_key)) {
        r_storage.clear();
        return "";
    }
    r_storage = to_utf8(String(p_dict[p_key]));
    return r_storage.c_str();
}

} // namespace

SherpaOfflineTTS::SherpaOfflineTTS() {}

SherpaOfflineTTS::~SherpaOfflineTTS() {
    reset();
}

void SherpaOfflineTTS::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure_vits", "model", "num_threads"), &SherpaOfflineTTS::configure_vits);
    ClassDB::bind_method(D_METHOD("synthesize_to_wav", "text", "output_filename", "model", "sid", "speed", "num_threads"), &SherpaOfflineTTS::synthesize_to_wav);
    ClassDB::bind_method(D_METHOD("is_configured"), &SherpaOfflineTTS::is_configured);
    ClassDB::bind_method(D_METHOD("get_last_error"), &SherpaOfflineTTS::get_last_error);
    ClassDB::bind_method(D_METHOD("reset"), &SherpaOfflineTTS::reset);
}

bool SherpaOfflineTTS::configure_vits(const Dictionary &p_model, int32_t p_num_threads) {
    if (tts != nullptr && _same_config(p_model, p_num_threads)) {
        return true;
    }

    reset();

    std::string model;
    std::string tokens;
    std::string data_dir;
    std::string lexicon;
    std::string rule_fsts;

    SherpaOnnxOfflineTtsConfig config;
    memset(&config, 0, sizeof(config));

    config.model.vits.model = dict_cstr(p_model, "onnx", model);
    config.model.vits.tokens = dict_cstr(p_model, "tokens", tokens);
    config.model.vits.data_dir = dict_cstr(p_model, "data_dir", data_dir);
    config.model.vits.lexicon = dict_cstr(p_model, "lexicon", lexicon);
    config.model.vits.noise_scale = 0.667f;
    config.model.vits.noise_scale_w = 0.8f;
    config.model.vits.length_scale = 1.0f;
    config.model.provider = "cpu";
    config.model.num_threads = p_num_threads;
    config.rule_fsts = dict_cstr(p_model, "rule_fsts", rule_fsts);
    config.max_num_sentences = 1;

    if (model.empty() || tokens.empty()) {
        _set_error("Missing VITS model or tokens path.");
        return false;
    }

    tts = SherpaOnnxCreateOfflineTts(&config);
    if (tts == nullptr) {
        _set_error("SherpaOnnxCreateOfflineTts failed.");
        return false;
    }

    configured_model = p_model.duplicate(true);
    configured_num_threads = p_num_threads;
    last_error = "";
    return true;
}

bool SherpaOfflineTTS::synthesize_to_wav(const String &p_text, const String &p_output_filename, const Dictionary &p_model, int32_t p_sid, double p_speed, int32_t p_num_threads) {
    String text = p_text.strip_edges();
    if (text.is_empty()) {
        _set_error("Text is empty.");
        return false;
    }

    if (!configure_vits(p_model, p_num_threads)) {
        return false;
    }

    std::string text_utf8 = to_utf8(text);
    std::string output_utf8 = to_utf8(p_output_filename);

    SherpaOnnxGenerationConfig gen_config;
    memset(&gen_config, 0, sizeof(gen_config));
    gen_config.sid = p_sid;
    gen_config.speed = static_cast<float>(p_speed);

    const SherpaOnnxGeneratedAudio *audio = SherpaOnnxOfflineTtsGenerateWithConfig(tts, text_utf8.c_str(), &gen_config, nullptr, nullptr);
    if (audio == nullptr || audio->samples == nullptr || audio->n <= 0) {
        if (audio != nullptr) {
            SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);
        }
        _set_error("Sherpa synthesis returned no audio.");
        return false;
    }

    int32_t ok = SherpaOnnxWriteWave(audio->samples, audio->n, audio->sample_rate, output_utf8.c_str());
    SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio);

    if (ok == 0) {
        _set_error("Failed to write WAV file.");
        return false;
    }

    last_error = "";
    return true;
}

bool SherpaOfflineTTS::is_configured() const {
    return tts != nullptr;
}

String SherpaOfflineTTS::get_last_error() const {
    return last_error;
}

void SherpaOfflineTTS::reset() {
    if (tts != nullptr) {
        SherpaOnnxDestroyOfflineTts(tts);
        tts = nullptr;
    }
    configured_model.clear();
    configured_num_threads = 0;
}

bool SherpaOfflineTTS::_same_config(const Dictionary &p_model, int32_t p_num_threads) const {
    if (configured_num_threads != p_num_threads) {
        return false;
    }
    for (const String &key : {"onnx", "tokens", "data_dir", "lexicon", "rule_fsts"}) {
        if (String(configured_model.get(key, "")) != String(p_model.get(key, ""))) {
            return false;
        }
    }
    return true;
}

void SherpaOfflineTTS::_set_error(const String &p_error) {
    last_error = p_error;
    UtilityFunctions::push_warning(String("SherpaOfflineTTS: ") + p_error);
}
