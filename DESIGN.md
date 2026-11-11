# Keysthetic design

## Direction: "keycap tray"

Marketplace UIs are flat grids of white cards. Keysthetic's surfaces are **keycaps**: a lit top edge, a darker lip along the bottom, a soft drop shadow underneath. Everything you can press looks pressable and squishes like a switch. One bold accent (vermilion) carries every primary action, the active nav key and every "this is yours to act on" signal. Neutrals are warm paper (light) and warm charcoal (dark), never blue-grey, so the keycaps read as physical plastic.

Soft tactile depth is used as an accent on cards, buttons and the nav tray, not on every element, to keep contrast usable (see references).

### Palette (tokens in `lib/theme/tokens.dart`, theme in `lib/theme/app_theme.dart`)

| Role | Light | Dark |
|---|---|---|
| Accent (primary) | `#FF4D1C` | `#FF6A3D` |
| Background | `#F4F0E7` | `#16140F` |
| Ink (on surface) | `#1D1A14` | `#F2EEE4` |
| Keycap top / bottom / lip | `#FFFFFF` / `#F3EFE6` / `#D9D2C3` | `#2E2B25` / `#24211C` / `#0E0D0A` |
| Offer / Counter / Accepted / Declined | `#B7791F` / `#2B6CB0` / `#1E8A4C` / `#C53030` | `#F0B04A` / `#6BA8F0` / `#4CC785` / `#FF7A7A` |

Access them with `context.cs` (ColorScheme), `context.keys` (KeysColors extension), `context.tt` (TextTheme).

### Type (bundled, offline; see ATTRIBUTION.md)
- **Bricolage Grotesque**: display and titles (700-800, tight tracking). Family name `Bricolage`.
- **Instrument Sans**: body, labels (450-650). Family `InstrumentSans`.
- **JetBrains Mono**: prices, counts, legends, tabular figures via `monoStyle()`. Family `JetBrainsMono`.
Variable fonts: weights are set with `FontVariation.weight`, already wrapped by the theme's text styles. Use `context.tt.*`, do not hand-roll `TextStyle`s.

### Spacing, radii, elevation
- Spacing (`Sp`): 4 / 8 / 12 / 16 / 24 / 32. Screen gutter 16.
- Radii (`Rad`): 10 (chips, inputs of small things) / 16 (buttons, inputs) / 22 (cards) / 28 (nav tray).
- Elevation = `KeycapCard` / `KeyButton` / nav tray: gradient top-to-bottom, 3-4 dp bottom lip in the lip colour, blur 12-22 shadow at y offset 6-10. No Material elevation tint.

### Motion principles
1. Springs for things you touch (press, tilt, layer drop), eased curves (`easeOutCubic`) for things that arrive (stagger, route, reveal).
2. Transform + opacity only; `RepaintBoundary` around anything that animates continuously (shimmer, waveform, keyboard layers).
3. Short: 140 / 260 / 420 ms (`Dur`). Stagger delay capped so a long list never waits.
4. Reduce-motion is a first-class path: every widget checks `context.reduceMotion` (`MediaQuery.disableAnimationsOf`) and falls back to a plain fade or nothing. The Motion lab has a "Simulate reduce-motion" switch.
5. Motion explains state: the build keyboard drops a part in when you pick it and lifts it away when you remove it.

## Architecture
`lib/screens`, `lib/widgets`, `lib/models`, `lib/services`, `lib/theme`. Riverpod everywhere (`flutter_riverpod` 3: `Notifier` / `NotifierProvider`).
- `services/providers.dart`: `prefsProvider` (overridden in `main`), `sessionProvider` (baseUrl, token, user, demo flag; persisted), `apiProvider` (rebuilt when the session changes), `themeModeProvider`, `mediaImage(ref, url)`.
- `services/api.dart`: one `Api` with a method per endpoint in `keysthetic-server/API.md`; `ApiException(status, message)`; `DemoModeException` for every write in Demo mode; demo reads come from `assets/demo/demo.json`.
- `widgets/routes.dart`: `context.push(Screen())` is the only way to navigate (custom transition). `context.popToRoot()` before changing session.
- Errors: `showApiError(context, e)` (turns `DemoModeException` into the "Connect to a server to do this" snackbar).
- Navigation: `RootGate` (Connect -> Login -> Shell) is driven by the session; do not push those screens by hand.

## Test keys convention
`ValueKey('<area>.<thing>')`, lower snake case, on every interactive widget:
`connect.url`, `connect.test`, `connect.continue`, `connect.demo`, `auth.email`, `auth.password`, `auth.submit`, `auth.register` (link on Login), `auth.name`, `auth.area`, `auth.role.buyer|seller`, `nav.home|search|build|chats|profile|my_listings|orders|listings|users|legit`, `demo.banner`, `demo.role`, `theme.system|light|dark`, `profile.motion_lab`, `profile.signout`, `lab.*`. New screens: `<screen>.<element>` (`feed.card.<listingId>`, `chat.send`, `checkout.confirm`). Lists: suffix with the id.

## Android
- minSdk **23**: the `record` plugin needs 23, every other chosen plugin (audioplayers, image_picker, file_picker, shared_preferences, http) is at or below that. targetSdk/compileSdk are Flutter's defaults.
- `network_security_config.xml` allows cleartext HTTP (LAN server); INTERNET, CAMERA, RECORD_AUDIO permissions declared.

## References opened while choosing the direction
- Flutter: Introduction to animations (implicit vs explicit, `SpringSimulation`): https://docs.flutter.dev/ui/animations
- Flutter: Accessibility (48x48 tap targets, large text scales): https://docs.flutter.dev/accessibility-and-localization/accessibility
- Material 3 colour roles: https://m3.material.io/styles/color/roles (page is script-rendered; only the title could be fetched, used from prior knowledge)
- Material 3 motion: https://m3.material.io/styles/motion/overview/how-it-works (same caveat)
- 2026 mobile UI trend roundup that frames soft tactile depth as an accent, not a whole-app style: https://vp0.com/blogs/mobile-app-ui-design-inspiration-2026
Mobbin and Dribbble returned 403 / empty to the fetch tool, so no shots from them were studied. No claim here depends on them.
