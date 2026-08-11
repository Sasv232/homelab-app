"""Patch Windows CMakeLists for flutter_inappwebview compatibility.
New MSVC removed experimental/coroutine support; silence the deprecation error.
"""

import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

cmake = ROOT / "windows" / "CMakeLists.txt"
if cmake.exists():
    t = cmake.read_text()
    define = 'add_compile_definitions(_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)'
    if define not in t:
        t = t.replace(
            'project(homelab LANGUAGES CXX)',
            'project(homelab LANGUAGES CXX)\n\n'
            + define + '\n',
        )
    cmake.write_text(t)
    print("windows/CMakeLists.txt patched")
else:
    print("windows/CMakeLists.txt NOT FOUND")