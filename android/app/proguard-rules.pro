# MediaPipe LLM Inference - prevent class stripping in release builds
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Protocol Buffers used by MediaPipe
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# ML Kit Text Recognition
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# RAG / local agent functionality
-keep class com.google.ai.edge.localagents.** { *; }
-dontwarn com.google.ai.edge.localagents.**

# flutter_gemma background downloader
-keep class com.your.package.** { *; }
-dontwarn com.your.package.**
