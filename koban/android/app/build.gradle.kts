import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Copied from the 0.1.1 app/build.gradle.kts.
fun loadDotEnv(file: java.io.File): Map<String, String> {
    if (!file.exists()) return emptyMap()
    return file.readLines()
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") && it.contains("=") }
        .associate { line ->
            val idx = line.indexOf('=')
            val key = line.substring(0, idx).trim()
            var value = line.substring(idx + 1).trim()
            if ((value.startsWith("\"") && value.endsWith("\"")) ||
                (value.startsWith("'") && value.endsWith("'"))
            ) {
                value = value.substring(1, value.length - 1)
            }
            key to value
        }
}

fun escapeBuildConfig(value: String): String =
    value.replace("\\", "\\\\").replace("\"", "\\\"")

// The publishable Supabase key comes from the git-ignored .env at the repository root.
val rootEnv = loadDotEnv(rootProject.file("../../.env"))
val supabaseKey = rootEnv["SUPABASE_KEY"].orEmpty()
if (supabaseKey.isEmpty()) {
    logger.warn("SUPABASE_KEY is missing in .env: groups and receipt reading will not work.")
}

// Release signing, the same file as 0.1.1 (docs/RELEASING.md). Never commit or print it.
val releaseSigningFile = file("${System.getProperty("user.home")}/.koban/release-signing.properties")
val releaseSigning = Properties().apply {
    if (releaseSigningFile.exists()) releaseSigningFile.inputStream().use { load(it) }
}
// The names of the keys that have no value. Only names, never values.
val missingSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .filter { releaseSigning.getProperty(it).isNullOrBlank() }

// A release build without the release key must stop: an APK with another key cannot update 0.1.1.
// Debug builds and unit tests do not need the file (CI has no key).
gradle.taskGraph.whenReady {
    if (missingSigningKeys.isNotEmpty() && hasTask("${project.path}:preReleaseBuild")) {
        throw GradleException(
            "Release signing file ${releaseSigningFile.path} is missing or has no value for " +
                "${missingSigningKeys.joinToString()}. " +
                "A release APK must use the release key (docs/RELEASING.md, section 2).",
        )
    }
}

android {
    namespace = "io.github.skooyo.koban"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
        resValues = true
    }
    testOptions { unitTests { isIncludeAndroidResources = true } }
    // The release lint check crashes inside lint on the image_picker_android plugin
    // (NoSuchMethodError in JavaDocParser, AGP 9.3.1), so a release build cannot end.
    // ponytail: release builds skip the lint vital check. Turn it on again after an AGP or plugin update.
    lint { checkReleaseBuilds = false }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (missingSigningKeys.isEmpty()) {
            create("release") {
                storeFile = file(releaseSigning.getProperty("storeFile"))
                storePassword = releaseSigning.getProperty("storePassword")
                keyAlias = releaseSigning.getProperty("keyAlias")
                keyPassword = releaseSigning.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.github.skooyo.koban"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("String", "SUPABASE_URL", "\"https://ydrlxhqdalomlkqkdjyb.supabase.co\"")
        buildConfigField("String", "SUPABASE_KEY", "\"${escapeBuildConfig(supabaseKey)}\"")
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"221621530092-1n4jia2b9v4ctjue56d1gilej11q9l8h.apps.googleusercontent.com\"")
        resValue("string", "app_name", "Koban")
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            // The launcher shows which Koban is the test build.
            resValue("string", "app_name", "Koban (Debug)")
        }
        release {
            // The release key from ~/.koban, never the debug key (the check above stops the build without it).
            signingConfig = signingConfigs.findByName("release")
            // No R8, the same as 0.1.1 (owner decision, milestone 6). The Flutter plugin turns both on.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.datastore:datastore-preferences:1.1.1")
    implementation("androidx.core:core-ktx:1.15.0")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.18")
    testImplementation("androidx.test:core:1.7.0")
}

flutter {
    source = "../.."
}
