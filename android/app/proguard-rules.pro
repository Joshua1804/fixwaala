# Firebase and Flutter plugins rely on reflection; keep their entry points.
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }

# Suppress warnings for optional Play Core classes Flutter references but
# does not bundle in a non-deferred-components build.
-dontwarn com.google.android.play.core.**
