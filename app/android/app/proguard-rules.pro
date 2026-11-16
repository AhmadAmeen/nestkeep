# ML Kit text recognition: the plugin references option classes for scripts
# this app does not ship (Latin only). They are optional at runtime, so tell
# R8 not to fail on their absence.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
