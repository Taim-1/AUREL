#!/usr/bin/env bash
set -euo pipefail

# The Android native project is kept as reviewed source under platform/android.
# Generate Flutter's version-matched Gradle wrapper and project scaffolding,
# then apply AUREL's manifest, activity, notification and launcher resources.
if [[ ! -f android/gradlew || ! -f android/app/build.gradle.kts ]]; then
  flutter create --platforms=android --org com.aurel --project-name aurel .
fi

mkdir -p android/app/src/main/kotlin/com/aurel/aurel
mkdir -p android/app/src/main/res

cp platform/android/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
cp platform/android/MainActivity.kt android/app/src/main/kotlin/com/aurel/aurel/MainActivity.kt
cp -R platform/android/res/. android/app/src/main/res/

if [[ -f android/app/build.gradle.kts ]]; then
  if grep -q 'minSdk = flutter.minSdkVersion' android/app/build.gradle.kts; then
    sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 23/' android/app/build.gradle.kts
  fi
elif [[ -f android/app/build.gradle ]]; then
  if grep -q 'minSdkVersion flutter.minSdkVersion' android/app/build.gradle; then
    sed -i 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 23/' android/app/build.gradle
  fi
fi

echo "AUREL Android project is ready."
