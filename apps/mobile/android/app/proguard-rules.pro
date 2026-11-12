# WorkManager (reminders) creates its Room database by reflection at app start.
# Without these rules the release build crashes on launch because R8 removes
# androidx.work.impl.WorkDatabase_Impl.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.** { *; }
-keep class * extends androidx.work.ListenableWorker { <init>(...); }
-dontwarn androidx.work.**
