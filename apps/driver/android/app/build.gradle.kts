import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// =============================================================================
//  KUNCI PENANDATANGANAN DIBACA DARI BERKAS DI LUAR REPO
// =============================================================================
//  `android/key.properties` TIDAK ikut ke git — lihat `.gitignore`. Isinya:
//
//      storeFile=C:/kunci/antaride-release.jks
//      storePassword=...
//      keyAlias=antaride
//      keyPassword=...
//
//  Kalau berkasnya TIDAK ADA, build release tetap jalan dengan kunci debug.
//  Itu disengaja: pengembangan dan pengujian sideload tidak boleh terhenti
//  karena kunci rilis belum dibuat.
//
//  Yang HARUS diketahui sebelum rilis pertama:
//
//    * APK bertanda kunci debug TIDAK BISA diunggah ke Play Store.
//    * Kunci rilis tidak bisa diganti setelah aplikasi terbit. Kehilangan
//      keystore berarti kehilangan kemampuan MEMPERBARUI aplikasi selamanya —
//      penggantinya harus terbit sebagai aplikasi baru, dan seluruh pengguna
//      lama tidak akan pernah menerima pembaruan.
//    * Jadi keystore-nya wajib dicadangkan di tempat yang terpisah dari
//      komputer kerja, dan kata sandinya disimpan di password manager.
//
//  Membuat keystore-nya:
//
//      keytool -genkey -v -keystore antaride-release.jks \
//        -keyalg RSA -keysize 2048 -validity 10000 -alias antaride
//
//  `-validity 10000` (sekitar 27 tahun) bukan berlebihan: Play Store menolak
//  kunci yang kadaluarsa sebelum 2033, dan kunci yang habis masa berlakunya
//  menghasilkan masalah yang sama dengan kunci yang hilang.
// =============================================================================
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()

if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

val hasReleaseKey = keyProperties.getProperty("storeFile") != null

android {
    namespace = "id.antaride.driver"
    /*
     * ========================================================================
     *  compileSdk DITETAPKAN, TIDAK MENGIKUTI BAWAAN FLUTTER
     * ========================================================================
     *  `flutter.compileSdkVersion` sekarang bernilai 36. Yang memaksa naik:
     *  `permission_handler_android` menuntut pemakainya dikompilasi terhadap
     *  API 37 atau lebih baru.
     *
     *  Gejalanya kalau dibiarkan mengikuti bawaan, dan pesannya menyesatkan:
     *
     *      Execution failed for task ':app:checkReleaseAarMetadata'
     *      Dependency ':permission_handler_android' requires ... version 37
     *
     *  Baris berikutnya menyebut `minSdk`, jadi mudah disalahpahami sebagai
     *  masalah versi Android minimum. Yang dituntut compileSdk — dan keduanya
     *  hal yang sama sekali berbeda.
     *
     *  Ketiga aplikasi disetel SAMA, walaupun sekarang hanya aplikasi driver
     *  yang memakai `antaride_media`. Alasannya: begitu unggahan foto profil dan
     *  foto produk menyusul, dua aplikasi lainnya akan gagal build dengan pesan
     *  yang sama — dan yang mengerjakannya nanti harus menemukan penjelasan ini
     *  dari nol.
     * ========================================================================
     *
     *  compileSdk 37 TIDAK berarti aplikasi menuntut Android API 37 untuk
     *  dipasang. Yang menentukan itu `minSdk` (24, dari Flutter), dan
     *  `targetSdk` yang menentukan perilaku runtime mana yang diikuti. Keduanya
     *  dibiarkan mengikuti Flutter — menaikkan compileSdk hanya membuat API
     *  baru TERSEDIA saat kompilasi.
     */
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "id.antaride.driver"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                // Kunci debug sebagai jalan sementara, supaya
                // `flutter build apk --release` tetap bisa dipakai untuk
                // pengujian sideload sebelum keystore dibuat.
                signingConfigs.getByName("debug")
            }

            /*
             * =================================================================
             *  MINIFY DIMATIKAN, DAN ITU KEPUTUSAN YANG DISENGAJA
             * =================================================================
             *  R8 memperkecil APK sekitar 15%, dan biayanya: setiap crash report
             *  jadi tidak bisa dibaca tanpa mapping file yang benar, dan
             *  refleksi di plugin bisa rusak dengan cara yang hanya muncul di
             *  build release.
             *
             *  Untuk Fase 1 — APK yang dibagikan ke penguji dan driver awal —
             *  laporan crash yang bisa dibaca jauh lebih berharga daripada 3 MB.
             *  `--split-per-abi` sudah memotong ukurannya lebih banyak daripada
             *  yang bisa dilakukan R8.
             *
             *  Nyalakan sebelum rilis publik, bersama penyiapan Crashlytics dan
             *  pengunggahan mapping file.
             * =================================================================
             */
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

flutter {
    source = "../.."
}
