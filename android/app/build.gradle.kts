import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

dependencies {
    implementation("androidx.work:work-runtime-ktx:2.11.2")
    implementation(project(":findbike"))
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20250517")
    testImplementation("org.robolectric:robolectric:4.16.1")
}

android {
    namespace = "vn.edu.phenikaa.better_phenikaa_schedule"
    androidResources { noCompress += listOf("mp4", "m4a") }
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    testOptions { unitTests.isIncludeAndroidResources = true }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "vn.edu.phenikaa.better_phenikaa_schedule"
        manifestPlaceholders["appLabel"] = "Better Phenikaa App"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = System.getenv("COOC_VERSION_NAME") ?: "cooc.2.0"
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("coocRelease") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        configureEach {
            if (name != "release" && providers.gradleProperty("bpaKdaTest").orNull == "true") {
                applicationIdSuffix = ".kdatest"
                manifestPlaceholders["appLabel"] = "BPA KDA Test"
                signingConfig = signingConfigs.getByName("debug")
            }
            if(name!="release" && providers.gradleProperty("bpaWaterRecovery").orNull=="true") {
                applicationIdSuffix=".waterrecovery.test6r"
                manifestPlaceholders["appLabel"]="BPA Water Cooling Test6R4"
            }
        }
        release {
            signingConfig = signingConfigs.findByName("coocRelease")
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

// Never fall back to a generated debug key for release builds.
gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any { task ->
        task.project == project && task.name.contains("Release", ignoreCase = true)
    }
    if (releaseRequested && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "Missing android/key.properties for release signing. " +
                "Better Phenikaa release APKs must use the fixed cooc key.",
        )
    }
}

// AGP host-test packaging reads the Flutter asset directory copied by this task.
// Declare that producer explicitly for Gradle 9 validation and real-font QA.
tasks.configureEach {
    if (name == "packageDebugUnitTestForUnitTest") dependsOn("copyFlutterAssetsDebug")
}
