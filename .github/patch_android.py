"""Patch android config after `flutter create`:
- add INTERNET permission
- allow cleartext http traffic
"""

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