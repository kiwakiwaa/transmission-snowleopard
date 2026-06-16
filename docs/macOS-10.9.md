# Building Transmission for OS X 10.9

[Xcode 6.2](https://download.developer.apple.com/Developer_Tools/Xcode_6.2/Xcode_6.2.dmg) is recommended when building on Mavericks.

Install a modern compiler, CMake, Ninja, OpenSSL, and curl on the build host. With MacPorts, one suitable setup is:

```bash
sudo port install clang-16 cmake ninja openssl3 curl
```

The repository provides a `macos-10.9` CMake preset:

```bash
cmake --preset macos-10.9
cmake --build --preset macos-10.9
```

Set `TR_RAISE_FILE_DESCRIPTOR_LIMIT=ON` to raise the app's startup file descriptor soft limit to 1024.

Override nonstandard paths with:

- `CMAKE_OSX_SYSROOT`: path to `MacOSX10.9.sdk`
- `CMAKE_PREFIX_PATH`: dependency prefix, such as `/opt/local`
- `CMAKE_C_COMPILER`, `CMAKE_CXX_COMPILER`, and `CMAKE_MAKE_PROGRAM`

The application bundle is produced at:

```bash
build-10.9/macosx/Transmission.app
```
