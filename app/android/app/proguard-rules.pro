# Uygulamaya özel R8 kuralları (Flutter'ın kendi kurallarına ek olarak).

# google_mobile_ads üzerinden gelen WorkManager, veritabanını Room ile yansıma (Class.forName + newInstance) kullanarak
# oluşturur. R8 tam modunda WorkDatabase_Impl'in yapıcısı silinince uygulama daha açılışta çöküyordu:
# "Unable to get provider androidx.startup.InitializationProvider ... Failed to create an instance of
# androidx.work.impl.WorkDatabase" (8 Kasım 2026'da emülatörde release APK ile yakalandı).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
