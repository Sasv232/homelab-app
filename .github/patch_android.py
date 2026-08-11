"""Patch android config after `flutter create`:
- add INTERNET permission
- allow cleartext http traffic
- sign release build with debug key (so APK is installable)
"""

import re
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

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

gradle = ROOT / "android" / "app" / "build.gradle.kts"
if gradle.exists():
    g = gradle.read_text()
    # ensure release uses debug signing so APK is installable
    if 'signingConfigs' not in g:
        g = g.replace(
            'compileSdk = flutter.compileSdkVersion',
            'compileSdk = flutter.compileSdkVersion\n'
            '\n'
            '    signingConfigs {\n'
            '        create("release") {\n'
            '            storeFile = file("${rootProject.projectDir}/debug.keystore")\n'
            '        }\n'
            '    }',
        )
    if 'debug.keystore' in g and not (ROOT / "android" / "debug.keystore").exists():
        # use the standard debug keystore from ~/.android
        g = g.replace(
            'storeFile = file("${rootProject.projectDir}/debug.keystore")',
            'storeFile = file(System.getProperty("user.home") + "/.android/debug.keystore")\n'
            '            storePassword = "android"\n'
            '            keyAlias = "androiddebugkey"\n'
            '            keyPassword = "android"',
        )
        g = g.replace(
            'create("release")',
            'create("release")',
        )
    gradle.write_text(g)
    print("build.gradle.kts patched (debug signing for release)")
else:
    # legacy groovy gradle
    gradle = ROOT / "android" / "app" / "build.gradle"
    g = gradle.read_text()
    if 'signingConfigs' not in g:
        g = g.replace(
            'android {',
            'android {\n'
            '    signingConfigs {\n'
            '        release {\n'
            '            storeFile file(System.getProperty("user.home") + "/.android/debug.keystore")\n'
            '            storePassword "android"\n'
            '            keyAlias "androiddebugkey"\n'
            '            keyPassword "android"\n'
            '        }\n'
            '    }',
        )
    if 'signingConfig signingConfigs.release' not in g:
        g = g.replace(
            'release {',
            'release {\n            signingConfig signingConfigs.release',
            1,
        )
    gradle.write_text(g)
    print("build.gradle patched (debug signing for release)")