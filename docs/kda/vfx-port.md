# Approved burn shader on Flutter

The bundled `assets/kda/fire_transition.html` preserves the approved 1.5-second
BPA burn VFX. Android no longer creates a second WebView to play it: the test
emulator stalled in the WebView WebGL draw and also reported a Quickstep ANR.

`shaders/kda_burn.frag` is extracted from that exact fragment. The adaptations
are FlutterFragCoord, the vertical coordinate convention, runtime-effect output
syntax and a wrapped one-pixel noise border for Flutter's clamp sampler. The
flame, ember, smoke, spark, alpha and burn-progress expressions are unchanged.

`kda_burn_field.dart` translates the original buildBurnField: same 32-bit LCG,
64 sites, shape distribution, isotropic noise, float32 distance map, quantiles,
Hermite timing curve and 16-bit RG packing. It runs in an isolate at the actual
screen aspect ratio with a fresh seed. The unit test compares complete arrival
and timing SHA-256 hashes against the original JavaScript for seed 42 at 9:16.

Only this approved kernel is used. It reaches opaque black at 1.5 seconds and
retains that black frame until the MV is ready. The overlay paints at up to
30 frames/second; no extra video player or native WebView context is created.
