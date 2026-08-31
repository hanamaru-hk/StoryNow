import argparse
import shutil
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_model", type=Path)
    parser.add_argument("output_model", type=Path)
    parser.add_argument("source_lexicon", type=Path)
    parser.add_argument("output_lexicon", type=Path)
    parser.add_argument("module_path", type=Path)
    args = parser.parse_args()

    sys.path.insert(0, str(args.module_path))
    import onnx

    model = onnx.load(args.source_model)
    input_names = {value.name for value in model.graph.input}
    required_inputs = {"x", "tones"}
    missing_inputs = required_inputs - input_names
    if missing_inputs:
        raise RuntimeError(f"Unexpected Japanese MeloTTS inputs; missing {sorted(missing_inputs)}")

    metadata = {item.key: item.value for item in model.metadata_props}
    if metadata.get("model_type") != "melo-vits" or metadata.get("language_code") != "ja":
        raise RuntimeError("Expected a Japanese MeloTTS model")

    # Sherpa 1.13.5 selects its tone-aware Melo frontend only for Chinese and
    # English metadata. Routing through that frontend does not alter the
    # model's Japanese lang_id, speaker, or synthesis graph.
    for item in model.metadata_props:
        if item.key == "language":
            item.value = "English"
            break
    else:
        item = model.metadata_props.add()
        item.key = "language"
        item.value = "English"

    onnx.checker.check_model(model)
    onnx.save(model, args.output_model)
    shutil.copyfile(args.source_lexicon, args.output_lexicon)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
