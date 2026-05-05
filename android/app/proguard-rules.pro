# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core - Règles étendues
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.review.** { *; }
-keep class com.google.android.play.core.common.** { *; }

-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.** { *; }
-keep class com.google.android.gms.** { *; }

-dontwarn com.google.android.play.**
-dontwarn com.google.android.gms.**

# Pour les deferred components
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Camera X
-keep class androidx.camera.** { *; }

# Google Maps
-keep class com.google.android.gms.maps.** { *; }
-keep class com.google.maps.android.** { *; }

# Activity / Fragment (embedding Flutter + plugins)
-keep class androidx.activity.** { *; }
-keep class androidx.fragment.app.** { *; }
-keep public class * extends androidx.fragment.app.Fragment

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# OneSignal
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# Votre code applicatif
-keep class com.casa.casa.casa.** { *; }

# Optimisations supplémentaires
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

# Supprimer les logs en production
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Optimiser les ressources
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Réduire la taille du code
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*

