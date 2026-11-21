import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clé d'envoi (upload key) pour Google Play. Le fichier android/key.properties
// et la clé .jks restent sur l'ordinateur de Bocar : jamais dans le dépôt
// (android/.gitignore). Sans ce fichier (autre machine, tests), la version
// « release » est signée avec la clé de débogage : `flutter run --release`
// marche toujours, mais ce paquet-là ne peut pas aller sur Google Play.
// Voir docs/ARCHITECTURE.md, « Signature Android ».
val proprietesCle = Properties()
val fichierCle = rootProject.file("key.properties")
if (fichierCle.exists()) {
    FileInputStream(fichierCle).use { proprietesCle.load(it) }
}

android {
    namespace = "sn.samaclasse.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identifiant définitif sur Google Play (D28).
        applicationId = "sn.samaclasse.app"
        // Version : champ `version` de pubspec.yaml (nom+numéro, ex. 0.2.0+2).
        // Le numéro doit augmenter à chaque envoi sur Google Play.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (fichierCle.exists()) {
            create("envoi") {
                keyAlias = proprietesCle["keyAlias"] as String
                keyPassword = proprietesCle["keyPassword"] as String
                storeFile = file(proprietesCle["storeFile"] as String)
                storePassword = proprietesCle["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (fichierCle.exists()) {
                signingConfigs.getByName("envoi")
            } else {
                signingConfigs.getByName("debug")
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
