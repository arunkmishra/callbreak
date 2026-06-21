# Keep WorkManager and AndroidX classes
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class androidx.sqlite.** { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# Keep Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
