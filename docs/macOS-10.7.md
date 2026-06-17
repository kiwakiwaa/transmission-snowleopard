# Building Transmission for Mac OS X 10.7

[Xcode 4.6.3](https://download.developer.apple.com/Developer_Tools/xcode_4.6.3/Xcode_4.6.3.dmg) is recommended when building on Lion.

Install a modern compiler, CMake, Ninja, OpenSSL, and curl on the build host. With MacPorts, one suitable setup is:

```bash
sudo port install clang-16 cmake ninja openssl3 curl
```

The repository provides a `macos-10.7` CMake preset:

```bash
cmake --preset macos-10.7
cmake --build --preset macos-10.7
```

The application bundle is produced at:

```bash
build-10.7/macosx/Transmission.app
```

Set `TR_RAISE_FILE_DESCRIPTOR_LIMIT=ON` to raise the app's startup file descriptor soft limit to 1024.
