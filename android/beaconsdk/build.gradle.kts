plugins {
    id("com.android.library")
    id("kotlin-android")
    id ("maven-publish")
}

android {
    namespace = "com.xenber.beaconsdk"
    compileSdk = 34

    defaultConfig {
        minSdk = 21
        consumerProguardFiles("consumer-rules.pro")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
    
    repositories {
        google()
        mavenCentral()
    }
}

dependencies {
    // AltBeacon Library
    api("org.altbeacon:android-beacon-library:2.20.6")
    
    // Android/AndroidX
    implementation("androidx.lifecycle:lifecycle-process:2.6.2")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
}

afterEvaluate {
    publishing {
        publications {
            create<MavenPublication>("release") {
                groupId = "com.xenber"
                artifactId = "beaconsdk"
                version = "1.0.1"

                // Use the release AAR built by Android plugin
                artifact("$buildDir/outputs/aar/beaconsdk-android-1.0.1.aar")

                pom {
                    name.set("Xenber BeaconSDK")
                    description.set("Beacon SDK for Android")
                    url.set("https://xenber.com")
                }
            }
        }
        repositories {
            mavenLocal() 
        }
    }
}
