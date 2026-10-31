# StikJIT

<h3 align="center">
  <a href="https://discord.gg/ZnNcrRT3M8"><img src="https://img.shields.io/badge/Discord-join%20us-7289DA?logo=discord&logoColor=white&style=for-the-badge&labelColor=23272A" /></a>&nbsp;
  <a href="https://github.com/StikDebug/StikJIT/blob/main/LICENSE"><img src="https://img.shields.io/github/license/StikDebug/StikJIT?label=License&color=5865F2&style=for-the-badge&labelColor=23272A" /></a>&nbsp;
  <a href="https://github.com/StikDebug/StikJIT"><img src="https://img.shields.io/github/stars/StikDebug/StikJIT?label=Stars&color=FEE75C&style=for-the-badge&labelColor=23272A" /></a>&nbsp;
  <a href="https://github.com/StikDebug/StikJIT/releases"><img src="https://img.shields.io/github/v/release/StikDebug/StikJIT?label=Latest&color=00BFFF&style=for-the-badge&labelColor=23272A" /></a>&nbsp;
  <a href="https://deepwiki.com/StikDebug/StikJIT"><img src="https://img.shields.io/badge/Ask-DeepWiki-grey?style=for-the-badge&labelColor=23272A&color=007ec6" /></a>
</h3>

An iOS and tvOS XCFramework that enables JIT for another process over the device's RSD tunnel.

StikJIT is self-contained and bundles the idevice FFI and its JIT scripts.

## Integration

For iOS 26 JIT support, StikDebug URL integration, Built-in StikJIT setup, API usage, requirements, and recommended app settings, see [Integrating StikJIT](INTEGRATION.md).

## Build

```sh
xcodegen generate
xcodebuild archive -scheme StikJIT -destination 'generic/platform=iOS' \
  -archivePath build/StikJIT BUILD_LIBRARY_FOR_DISTRIBUTION=YES
xcodebuild -create-xcframework \
  -framework build/StikJIT.xcarchive/Products/Library/Frameworks/StikJIT.framework \
  -output StikJIT.xcframework
```

## License

StikJIT is licensed under the MPL-2.0 (see [`LICENSE`](LICENSE)). It uses StikDebug as a reference.
