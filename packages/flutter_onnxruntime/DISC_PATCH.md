# Local copy of flutter_onnxruntime 1.6.4 (MIT licence, see LICENSE)

Patched for the DISC app: all method calls run on one background thread
instead of Android's main thread (see the "DISC patch" comment in
FlutterOnnxruntimePlugin.kt). Without this, every ONNX run froze the UI,
and runs over 5 s caused ANRs ("app isn't responding").
Only the Android side is changed.

Second patch: a "whisperDecoderStep" method that runs one Whisper KV decoder
step in a single call (create token/pos, run, read logits, swap the cache)
instead of about 9 separate calls per token. Same model and inputs, so the
output is identical (unit test: whisper_kv_fused_step_test.dart).
Measured on a OnePlus Nord CE4: 81.9 -> 63.5 ms/token, RTF 0.70 -> 0.62.
Other platforms don't have the method; the app then uses the generic path.
