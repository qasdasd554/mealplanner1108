import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Wymagana, żeby google-services.json trafił do aplikacji.
    // Zależności Firebase (BoM, analytics) z instrukcji Firebase są
    // ZBĘDNE — dokładają je pakiety firebase_core i firebase_messaging.
    id("com.google.gms.google-services")
}

// Wczytaj key.properties (dane keystore'a) — plik NIE jest w repozytorium
// (patrz .gitignore), musi istnieć lokalnie w katalogu android/ obok tego
// pliku. Bez niego build release nadal zadziała, ale podpisze się kluczem
// debug (nieprzydatnym do publikacji w Google Play).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.smart_meal_planner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // WYMAGANE przez flutter_local_notifications (powiadomienia push
        // wyświetlane przy otwartej aplikacji). Biblioteka używa
        // nowoczesnego API dat i czasu z Javy 8+, którego starsze wersje
        // Androida nie mają. Desugaring "tłumaczy" te wywołania wstecz
        // przy kompilacji, dzięki czemu aplikacja działa też na starszych
        // urządzeniach. Bez tego build pada na checkReleaseAarMetadata.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.meal_planner_polska_v1"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                // UWAGA: zwykłe file(...) liczy ścieżki względne od
                // katalogu android/app/, a keystore leży w android/
                // (obok key.properties) — stąd rootProject.file(...),
                // które poprawnie liczy względność od katalogu android/.
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Podpisuje kluczem z key.properties, jeśli plik istnieje —
            // w przeciwnym razie spada z powrotem na klucz debug (żeby
            // `flutter run --release` nadal działało nawet bez keystore'a).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            ndk {
                // "symbol_table", NIE "none". Przy "none" Gradle w ogóle
                // nie generuje plików .sym/.dbg, a wewnętrzna kontrola
                // narzędzia flutter i tak sprawdza, czy istnieją — build
                // kończy się wtedy błędem "failed to strip debug symbols"
                // (flutter/flutter#169252). "symbol_table" wymusza format,
                // którego ta kontrola szuka.
                debugSymbolLevel = "symbol_table"
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// UWAGA (naprawa): androidx.core:core-ktx:1.19.0 wymagał SDK 37 i AGP
// 9.1.0+, czego ten projekt nie ma (SDK 36, AGP 9.0.1 — celowo NIE
// podnoszony, patrz wcześniejsze problemy z tym samym AGP przy innym
// pakiecie w tej samej sesji). Wersja 1.12.0 wymaga tylko SDK 34 —
// bezpiecznie poniżej granicy tego projektu — a jest wystarczająco nowa,
// żeby zawierać WindowCompat.setDecorFitsSystemWindows() używane w
// MainActivity.kt (ta metoda istnieje w androidx.core od bardzo dawna).
dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    // Biblioteka realizująca desugaring włączony w compileOptions powyżej.
    // Wersja 2.1.4+ jest wymagana przez flutter_local_notifications 18.x —
    // starsze wydania nie zawierają wszystkich potrzebnych klas.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
