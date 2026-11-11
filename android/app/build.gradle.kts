import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma compartida del equipo (decisión D3, docs/auth/plan-auth-social.md).
// `android/key.properties` NO se versiona (ver android/.gitignore); la
// plantilla es `android/key.properties.example`. Rutas relativas a `android/`.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

fun signingValue(name: String): String? =
    keystoreProperties.getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }

val sharedDevKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val releaseKeys = sharedDevKeys.map { "release" + it.replaceFirstChar(Char::uppercaseChar) }
val hasSharedDevKeystore = sharedDevKeys.all { signingValue(it) != null }
val hasReleaseKeystore = releaseKeys.all { signingValue(it) != null }

if (!hasSharedDevKeystore) {
    logger.warn(
        "MACHUCO: falta android/key.properties con el keystore compartido; " +
            "se firma con el debug local y Google/GitHub no funcionarán " +
            "(ver docs/auth/android-setup.md).",
    )
}

android {
    // El namespace es el paquete del código Kotlin (MainActivity); puede
    // diferir del applicationId sin afectar la instalación.
    namespace = "com.example.machuco"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // applicationId definitivo de producción (decisión D2). El flavor dev
        // agrega el sufijo `.dev` para no sobrescribir la instalación de prod.
        applicationId = "co.machuco.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasSharedDevKeystore) {
            create("sharedDev") {
                storeFile = rootProject.file(signingValue("storeFile")!!)
                storePassword = signingValue("storePassword")
                keyAlias = signingValue("keyAlias")
                keyPassword = signingValue("keyPassword")
            }
        }
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(signingValue("releaseStoreFile")!!)
                storePassword = signingValue("releaseStorePassword")
                keyAlias = signingValue("releaseKeyAlias")
                keyPassword = signingValue("releaseKeyPassword")
            }
        }
    }

    // Separación de entornos (decisión D8). Ambos usan el mismo proyecto de
    // Firebase `machuco`; cada uno tiene su app Android registrada.
    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "Machuco Dev"
        }
        create("prod") {
            dimension = "environment"
            manifestPlaceholders["appLabel"] = "machuco"
        }
    }

    buildTypes {
        getByName("debug") {
            if (hasSharedDevKeystore) {
                signingConfig = signingConfigs.getByName("sharedDev")
            }
        }
        getByName("release") {
            // Sin keystore de release se conserva el comportamiento previo
            // (firma de desarrollo): sirve para probar, NO para Google Play.
            signingConfig = when {
                hasReleaseKeystore -> signingConfigs.getByName("release")
                hasSharedDevKeystore -> signingConfigs.getByName("sharedDev")
                else -> signingConfigs.getByName("debug")
            }
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
