# Flutter-specific ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep ChaosVoice native classes
-keep class com.chaosvoice.** { *; }

# Keep MethodChannel classes
-keep class flutter_foreground_task.** { *; }
