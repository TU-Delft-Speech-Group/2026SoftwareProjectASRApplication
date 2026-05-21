"""
Generate the reference files for comparing the calculated filterbank with the generated mel filterbank
through the [librosa](https://librosa.org/) python library

updated: 20 may 2026 18:26

---
Running the script

- Run the script at the root of the repository
- `python test/services/audio/python_references/librosa_mel_filterbank.py`
"""
import json
## Include dependencies
import pathlib
import librosa
import numpy as np

## Settings
goldenDir = "test/services/audio/golden/"

## Generate exports
for (samplerate, fMin, fMax, nFft, nMels, htkOverSlaney) in [
    (16_000, 0, 8_000, 512, 80, True),
    (16_000, 0, 8_000, 512, 80, False),
]:

    ### Generate spectrogram
    if htkOverSlaney:
        melBank = librosa.filters.mel(fmin=fMin, fmax=fMax, n_mels=nMels, n_fft=nFft, sr=samplerate, htk=True, dtype=np.float32)
    else:
        melBank = librosa.filters.mel(fmin=fMin, fmax=fMax, n_mels=nMels, n_fft=nFft, sr=samplerate, norm='slaney', dtype=np.float32)


    ### Export to JSON
    jsonPath = pathlib.Path.joinpath(
        pathlib.Path(goldenDir),
        'librosa_mel_filterbank_{}x{}_{}.json'.format(nMels, nFft, 'htk' if htkOverSlaney else 'slaney')
    )
    with open(jsonPath, "w") as f:
        json.dump(melBank.tolist(), f, separators=(",", ":"))
    print('Exported: ', jsonPath)

