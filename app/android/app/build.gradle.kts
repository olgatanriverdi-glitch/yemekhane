import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// İmza bilgileri android/key.properties'te (git'e girmez); yoksa debug anahtarıyla imzalanır.
val anahtarDosyasi = rootProject.file("key.properties")
val anahtar = Properties().apply { if (anahtarDosyasi.exists()) load(FileInputStream(anahtarDosyasi)) }

android {
    namespace = "com.tolga.yemekhane"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications (günlük menü bildirimi) java.time için core library desugaring ister
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tolga.yemekhane"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // AdMob uygulama kimliği: android/key.properties içindeki `admobAppId`; yoksa Google'ın herkese açık TEST
        // uygulama kimliği (yalnız manifestin zorunlu alanı için; kimliksiz release'te reklam isteği zaten atılmaz).
        manifestPlaceholders["admobAppId"] =
            (anahtar["admobAppId"] as String?)?.takeIf { it.isNotBlank() }
                ?: "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        if (anahtarDosyasi.exists()) {
            create("release") {
                keyAlias = anahtar["keyAlias"] as String
                keyPassword = anahtar["keyPassword"] as String
                storeFile = file(anahtar["storeFile"] as String)
                storePassword = anahtar["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (anahtarDosyasi.exists()) "release" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
