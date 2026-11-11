# Keysthetic (app)

Flutter (Android) marketplace for keyboard parts. See `DESIGN.md` for direction, architecture and the test-key convention, `ATTRIBUTION.md` for bundled assets. API contract: `../keysthetic-server/API.md`.

```
flutter pub get
flutter run            # Android device/emulator; desktop (macOS) also works for quick looks
flutter test
SCREENSHOTS=1 flutter test test/tool/screenshots_test.dart   # PNGs into .dev-screens/
```
