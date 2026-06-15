# Building Transmission for Mac OS X 10.6

[Xcode 4.2](https://drive.proton.me/urls/0EK78E78EW#pj5sxK3lQ3eB) is recommended when building on Snow leopard.

Install a modern compiler, CMake, Ninja, OpenSSL, and curl on the build host. With MacPorts, one suitable setup is:

```bash
sudo port install clang-16 cmake ninja openssl3 curl ld64-latest
```

The linker on Snow leopard is too old for this project. I removed it and created a symlink for `ld-latest`.
```bash
sudo ln -s /opt/local/bin/ld-latest /opt/local/bin/ld
```

The repository provides a `macos-10.6` CMake preset:

```bash
cmake --preset macos-10.6
cmake --build --preset macos-10.6
```

The application bundle is produced at:

```bash
build-10.6/macosx/Transmission.app
```

Set `TR_RAISE_FILE_DESCRIPTOR_LIMIT=ON` to raise the app's startup file descriptor soft limit to 1024.

## libarclite setup

ARC builds targeting 10.6 need Apple's Mac ARC-lite archive. The Snow Xcode 4.2
install does not seem to have it, but [Xcode 4.6.1](https://download.developer.apple.com/Developer_Tools/xcode_4.6.1/Xcode_4.6.1.dmg) does. With the Xcode 4.6.1
disk image mounted, copy:

```bash
sudo mkdir -p /Developer/usr/lib/arc
sudo cp \
    /Volumes/Xcode/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/arc/libarclite_macosx.a \
    /Developer/usr/lib/arc/libarclite_macosx.a
```


Mike Ash's [ARC writeup](https://www.mikeash.com/pyblog/friday-qa-2011-09-30-automatic-reference-counting.html) explains why: ARC emits runtime helpers like `objc_retain`, `objc_release`, and autorelease pool calls instead of plain Objective-C messages.

Weak references were the second trap. `-fobjc-weak` isn't available for 10.6 targets. The current Snow build uses [PLWeakCompatibility](https://www.mikeash.com/pyblog/introducing-plweakcompatibility.html) with `-Xclang -fobjc-runtime-has-weak` to supply the weak runtime entry points.
