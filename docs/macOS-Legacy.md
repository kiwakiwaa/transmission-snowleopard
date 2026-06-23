# Building Transmission for Legacy macOS

These notes cover the shared compatibility build flow for Mac OS X 10.7 through macOS 10.15. Mac OS X 10.6 has a separate [Snow Leopard build guide](macOS-10.6.md) because it needs ARC-lite setup.

| Target                  | Preset        | Recommended Xcode                                                        | App bundle                            |
|-------------------------|---------------|--------------------------------------------------------------------------|---------------------------------------|
| OS X 10.7 Lion          | `macos-10.7`  | [Xcode 4.6.3](https://developer.apple.com/download/all/?q=Xcode%204.6.3) | `build-10.7/macosx/Transmission.app`  |
| OS X 10.8 Mountain Lion | `macos-10.8`  | [Xcode 5.1.1](https://developer.apple.com/download/all/?q=Xcode%205.1.1) | `build-10.8/macosx/Transmission.app`  |
| OS X 10.9 Mavericks     | `macos-10.9`  | [Xcode 6.2](https://developer.apple.com/download/all/?q=Xcode%206.2)     | `build-10.9/macosx/Transmission.app`  |
| OS X 10.10 Yosemite     | `macos-10.10` | [Xcode 7.2.1](https://developer.apple.com/download/all/?q=Xcode%207.2.1) | `build-10.10/macosx/Transmission.app` |
| macOS 10.13 High Sierra | `macos-10.13` | [Xcode 10.1](https://developer.apple.com/download/all/?q=Xcode%2010.1)   | `build-10.13/macosx/Transmission.app` |
| macOS 10.15 Catalina    | `macos-10.15` | [Xcode 12.4](https://developer.apple.com/download/all/?q=Xcode%2012.4)   | `build-10.15/macosx/Transmission.app` |

## Prerequisites

Install a modern compiler, CMake, Ninja, OpenSSL, and curl on the build host. With MacPorts, one suitable setup is:

```bash
sudo port install clang-16 cmake ninja openssl3 curl
```

The compatibility presets all inherit `macos-legacy-base`, which uses `cmake/MacOSLegacyToolchain.cmake` and sets the matching deployment target and SDK version for each target.

## Build

Choose a preset from the target table, then configure and build it:

```bash
cmake --preset macos-10.9
cmake --build --preset macos-10.9
```

Set `TR_RAISE_FILE_DESCRIPTOR_LIMIT=ON` to raise the app's startup file descriptor soft limit to 1024.

Override nonstandard paths with:

- `CMAKE_OSX_SYSROOT`: path to the target SDK, such as `MacOSX10.9.sdk`
- `CMAKE_PREFIX_PATH`: dependency prefix, such as `/opt/local`
- `CMAKE_C_COMPILER`, `CMAKE_CXX_COMPILER`, and `CMAKE_MAKE_PROGRAM`
