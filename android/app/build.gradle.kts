plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

fun loadKeystoreProperties(): Map<String, String> {
    val file = rootProject.file("key.properties")
    if (!file.exists()) return emptyMap()
    val lines = file.readLines()
    val map = mutableMapOf<String, String>()
    for (line in lines) {
        val trimmed = line.trim()
        if (trimmed.isEmpty() || trimmed.startsWith("#")) continue
        val eq = trimmed.indexOf('=')
        if (eq > 0) {
            map[trimmed.substring(0, eq).trim()] = trimmed.substring(eq + 1).trim()
        }
    }
    return map
}

val keystoreProps = loadKeystoreProperties()
val hasKeystore = keystoreProps.isNotEmpty()

android {
    namespace = "com.thingdcloud.dartcam"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.thingdcloud.dartcam"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    }

    if (hasKeystore) {
        signingConfigs {
            create("release") {
                keyAlias = keystoreProps["keyAlias"] ?: ""
                keyPassword = keystoreProps["keyPassword"] ?: ""
                storeFile = keystoreProps["storeFile"]?.let { rootProject.file(it) }
                storePassword = keystoreProps["storePassword"] ?: ""
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = if (hasKeystore) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
