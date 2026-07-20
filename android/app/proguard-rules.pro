# DartCam ProGuard Rules

# Flutter keeps these by default, but be explicit:
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Rust/FRB native methods
-keep class com.thingdcloud.dartcam.** { *; }

# Keep TFLite model loader
-keep class org.tensorflow.lite.** { *; }

# Keep Kotlin serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

# Keep Rust lib symbols (used by FRB)
-keep class rust_lib_local_dart_scorer.** { *; }

# Play Core split compat (not used in single-APK builds)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
