import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val previewBuild = providers.environmentVariable("BRAIN_PREVIEW_BUILD").orNull == "true"
val signingPropertiesFile = rootProject.file("../key.properties")
val signingProperties = Properties()
if (signingPropertiesFile.isFile && !previewBuild) {
    signingPropertiesFile.inputStream().use { signingProperties.load(it) }
    for (name in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        require(!signingProperties.getProperty(name).isNullOrBlank()) {
            "Missing $name in the project root key.properties"
        }
    }
}

android {
    namespace = "com.brainnourishment.brain_nourishment"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.brainnourishment.brain_nourishment" + if (previewBuild) ".preview" else ""
        manifestPlaceholders["appLabel"] = if (previewBuild) "Brain Nourishment Preview" else "Brain Nourishment"
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
    }

    signingConfigs {
        if (signingPropertiesFile.isFile && !previewBuild) {
            create("release") {
                // Relative paths are resolved from the project root, on every OS.
                storeFile = rootProject.file("../" + signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (previewBuild) signingConfigs.getByName("debug")
                else signingConfigs.findByName("release")
        }
    }
}

// Debug development never needs the production key. Stable release builds do.
gradle.taskGraph.whenReady {
    if (!previewBuild && !signingPropertiesFile.isFile && allTasks.any {
        it.project == project && (it.name == "assembleRelease" || it.name == "bundleRelease")
    }) {
        throw GradleException("Release signing is missing. Restore key.properties and the keystore in the project root. For a development-signed preview, set BRAIN_PREVIEW_BUILD=true.")
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
