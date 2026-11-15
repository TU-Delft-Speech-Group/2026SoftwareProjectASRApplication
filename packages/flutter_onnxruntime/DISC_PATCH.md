# Local copy of flutter_onnxruntime 1.6.4 (MIT licence, see LICENSE)

Patched for the DISC app: all method calls run on one background thread
instead of Android's main thread (see the "DISC patch" comment in
FlutterOnnxruntimePlugin.kt). Without this, every ONNX run froze the UI,
and runs over 5 s caused ANRs ("app isn't responding").
Only the Android side is changed.
