# OneSignal
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**
-keep class org.json.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Huawei HMS
-keep class com.huawei.** { *; }
-dontwarn com.huawei.**
-keep class com.hianalytics.** { *; }
-dontwarn com.hianalytics.**
-keep class com.huawei.updatesdk.** { *; }
-dontwarn com.huawei.updatesdk.**
-keep class com.huawei.hms.** { *; }
-dontwarn com.huawei.hms.**

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
