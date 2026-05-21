"""
Generate the reference files for comparing the full audio with the generated mel spectrogram
through the [ESPNet](https://espnet.github.io/espnet/) python library

updated: 20 may 2026 18:12

---
Running the script

- Run the script at the root of the repository
- `python test/services/audio/python_references/espnet_mel_spectrogram_tests.py`
"""
import json
import pathlib
import soundfile as sf
import torch
from espnet2.s2st.tgt_feats_extract.log_mel_fbank import LogMelFbank

## Settings
wavDir = "test/assets/"
goldenDir = "test/services/audio/golden/"

## Generate exports
for wavFile in [
    'poisoned_potato_test.wav'
]:
    ### Extract Wav
    wavPath = pathlib.Path.joinpath(pathlib.Path(wavDir), wavFile)
    print('Read: ', wavPath)
    wav, sr = sf.read(wavPath)
    wav = torch.tensor(wav, dtype=torch.float32).unsqueeze(0)  # [B, T]
    wav_lengths = torch.tensor([wav.shape[1]])

    ### Generate spectrogram
    layer = LogMelFbank(
        fs = sr,
        n_fft =512,
        win_length = 400,
        hop_length = 160,
        window = "hann",
        center = True,
        normalized = False,
        onesided = True,
        n_mels = 80,
        fmin = 0,
        fmax = 8000,
        htk = False,
        log_base = 10.0,
    )

    features, lengths = layer.forward(wav, wav_lengths)
    melValues = features[0]

    ### Export to JSON
    jsonPath = pathlib.Path.joinpath(
        pathlib.Path(goldenDir),
        'espnet_mel_spectrogram_tests_' + wavFile.replace('.', '_') + '.json'
    )
    with open(jsonPath, "w") as f:
        json.dump(melValues.tolist(), f, separators=(",", ":"))
    print('Exported: ', jsonPath)

