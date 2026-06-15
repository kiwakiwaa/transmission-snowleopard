# Building Transmission for OS X 10.8

Install a modern compiler, CMake, Ninja, OpenSSL, and curl on the build host. With MacPorts, one suitable setup is:

```bash
sudo port install clang-16 cmake ninja openssl3 curl
```

The repository provides a `macos-10.8` CMake preset:

```bash
cmake --preset macos-10.8
cmake --build --preset macos-10.8
```

The preset uses `cmake/MacOSLegacyToolchain.cmake` with a 10.8 deployment target and SDK.

This branch is intended for extended legacy macOS support, with compatibility verification spanning 10.6 through 10.10 as build coverage grows.

Set `TR_RAISE_FILE_DESCRIPTOR_LIMIT=ON` to raise the app's startup file descriptor soft limit to 1024.

Override nonstandard paths with:

- `CMAKE_OSX_SYSROOT`: path to `MacOSX10.8.sdk`
- `CMAKE_PREFIX_PATH`: dependency prefix, such as `/opt/local`
- `CMAKE_C_COMPILER`, `CMAKE_CXX_COMPILER`, and `CMAKE_MAKE_PROGRAM`

The application bundle is produced at:

```bash
build-10.8/macosx/Transmission.app
```

## Notes

- Xcode 5.1.1 or another source of the OS X 10.8 SDK must be available.
- The QuickLook extension target is disabled for this deployment target.
