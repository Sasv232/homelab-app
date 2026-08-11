"""Patch android config after `flutter create`:
- add INTERNET permission
- allow cleartext http traffic
- sign release build with generated keystore (android/app/homelab.keystore)
"""

import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

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

# ---------- build.gradle.kts (new templates) ----------
gradle = ROOT / "android" / "app" / "build.gradle.kts"

if gradle.exists():
    g = gradle.read_text()

    if 'signingConfigs' not in g:
        g = g.replace(
            '    buildTypes {',
            '    signingConfigs {\n'
            '        create("release") {\n'
            '            storeFile = file("homelab.keystore")\n'
            '            storePassword = "homelab123"\n'
            '            keyAlias = "homelab"\n'
            '            keyPassword = "homelab123"\n'
            '        }\n'
            '    }\n'
            '\n'
            '    buildTypes {',
        )

    if 'getByName("release")' not in g:
        g = g.replace(
            '            signingConfig = signingConfigs.getByName("debug")',
            '            signingConfig = signingConfigs.getByName("release")',
        )

    gradle.write_text(g)
    print("build.gradle.kts patched")

else:
    # ---------- legacy build.gradle ----------
    gradle = ROOT / "android" / "app" / "build.gradle"
    g = gradle.read_text()

    if 'signingConfigs' not in g:
        g = g.replace(
            '    buildTypes {',
            '    signingConfigs {\n'
            '        release {\n'
            '            storeFile file("homelab.keystore")\n'
            '            storePassword "homelab123"\n'
            '            keyAlias "homelab"\n'
            '            keyPassword "homelab123"\n'
            '        }\n'
            '    }\n'
            '\n'
            '    buildTypes {',
        )

    if 'signingConfig signingConfigs.release' not in g:
        g = g.replace(
            '            signingConfig signingConfigs.debug',
            '            signingConfig signingConfigs.release',
        )

    gradle.write_text(g)
    print("build.gradle patched")