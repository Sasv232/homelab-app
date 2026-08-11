"""Patch AGP/Gradle versions for flutter_inappwebview compatibility.
flutter_inappwebview 6.x breaks with AGP 9 (getDefaultProguardFile removed).
We pin AGP 8.7.3 + Gradle 8.12 for the android build.
"""

import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent

# ---------- settings.gradle.kts ----------
settings = ROOT / "android" / "settings.gradle.kts"
if settings.exists():
    s = settings.read_text()
    s = re.sub(r'id\("com\.android\.application"\) version "[^"]+"',
               'id("com.android.application") version "8.9.1"', s)
    s = re.sub(r'id\("org\.jetbrains\.kotlin\.android"\) version "[^"]+"',
               'id("org.jetbrains.kotlin.android") version "2.0.21"', s)
    settings.write_text(s)
    print("settings.gradle.kts patched")

# ---------- gradle-wrapper.properties ----------
wrapper = ROOT / "android" / "gradle" / "wrapper" / "gradle-wrapper.properties"
if wrapper.exists():
    w = wrapper.read_text()
    w = re.sub(r'distributionUrl=.*',
               'distributionUrl=https\\://services.gradle.org/distributions/gradle-8.12-bin.zip', w)
    wrapper.write_text(w)
    print("gradle-wrapper.properties patched")

# ---------- AndroidManifest.xml ----------
manifest = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
text = manifest.read_text()

if 'android.permission.INTERNET' not in text:
    text = text.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <uses-permission android:name="android.permission.INTERNET" />',
    )

if 'usesCleartextTraffic="true"' not in text:
    text = text.replace(
        '<application',
        '<application\n        android:usesCleartextTraffic="true"',
        1,
    )

manifest.write_text(text)
print("manifest patched")