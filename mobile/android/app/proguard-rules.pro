# Flutter wrapper around ML Kit Text Recognition references all language script options,
# but we only bundled the latin script. Ignore the warnings about missing classes for other languages.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
