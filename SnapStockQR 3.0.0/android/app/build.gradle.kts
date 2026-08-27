import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
} else {
    logger.warn("No existe android/key.properties: el APK se firmará como TEST con la clave debug.")
}

android {
    namespace = "com.example.foto_catalogo"
    compileSdk = 36
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.foto_catalogo"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "3.0.0" 
    }

    flavorDimensions += "environment"
    productFlavors {
        create("local") {
            dimension = "environment"
            applicationIdSuffix = ".local"
            versionNameSuffix = "-local"
            resValue("string", "app_name", "SnapStock QR Local")
        }
        create("public") {
            dimension = "environment"
            resValue("string", "app_name", "SnapStock QR")
        }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
            
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // Configuración compatible con Kotlin Script (.kts)
    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this
            if (output is com.android.build.gradle.internal.api.ApkVariantOutputImpl) {
                val abiFilter = output.filters.find { it.filterType == "ABI" }?.identifier
                val flavorSuffix = variant.flavorName.uppercase()
                val signingSuffix = if (hasReleaseKey) "" else "_TEST_DEBUG_SIGNED"
                val newName = if (abiFilter != null) {
                    "SnapStockQR_v3_0_0_${flavorSuffix}_${abiFilter}${signingSuffix}.apk"
                } else {
                    "SnapStockQR_v3_0_0_${flavorSuffix}${signingSuffix}.apk"
                }
                output.outputFileName = newName
            }
        }
    }
}

flutter {
    source = "../.."
}
