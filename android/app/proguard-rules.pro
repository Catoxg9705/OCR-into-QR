# ==========================================
# ML Kit Text Recognition ProGuard Rules
# ==========================================

# Only Latin is selected. These scripts are compileOnly in ML Kit's Flutter plugin.
# Suppress exactly the optional Options/Builder pairs; retain R8 minification.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# ==========================================
# CRITICAL: Keep ML Kit Core Classes
# ==========================================
# These classes are accessed via JNI/reflection by native libraries
# Removing them causes NullPointerException at runtime in release builds

-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep Google Android GMS classes (ML Kit dependency)
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep TensorFlow Lite classes (ML Kit backend)
-keep class org.tensorflow.lite.** { *; }
-keep interface org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# Keep all native methods (JNI)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep InputImage and related classes
-keep class com.google.mlkit.vision.common.InputImage { *; }
-keep class com.google.mlkit.vision.common.InputImage$Builder { *; }

# Keep Text Recognition classes
-keep class com.google.mlkit.vision.text.** { *; }
-keep interface com.google.mlkit.vision.text.** { *; }

# ==========================================
# Flutter & Dart
# ==========================================
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# Keep Flutter plugin classes
-keep class io.flutter.plugins.** { *; }

# ==========================================
# General Android
# ==========================================
# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
