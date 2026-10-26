# Keep Flutter app startup and plugin classes intact while allowing R8 cleanup.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }

# Preserve plugin-specific classes accessed via reflection or native callbacks
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }

# Preserve generated Android classes required by Flutter.
-keep class androidx.lifecycle.** { *; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Retain source file and line numbers for de-obfuscation in Play Console
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# Suppress R8 warnings for Play Core split-install classes (not used at runtime).
-dontwarn com.google.android.play.core.**

