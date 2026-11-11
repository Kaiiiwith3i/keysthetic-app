# Keysthetic — phone demo setup

Everything runs locally: the Mac runs the server, the phone runs the app, both on the same Wi-Fi (no internet needed). All seeded people, listings, chats and payment QRs are **fake demo data**; product images are generated renders.

## 1. Start the server (Mac)

```bash
cd ~/Documents/Development/keysthetic-server
/opt/homebrew/share/flutter/bin/dart run bin/seed.dart     # fresh demo data (wipes previous changes)
/opt/homebrew/share/flutter/bin/dart run bin/server.dart   # leave this terminal open
```

It prints `Keysthetic API on http://0.0.0.0:8080`. Stop it with Ctrl+C. Only run `seed.dart` while the server is stopped.

## 2. Find the Mac's address

```bash
ipconfig getifaddr en0
```

Example: `192.168.1.205`. The app needs `<that address>:8080`, e.g. `192.168.1.205:8080`. The address can change when you join a different Wi-Fi or hotspot — re-check it before the defense.

Quick check from the phone's browser: open `http://192.168.1.205:8080/health` → it should show `{"ok":true,"app":"keysthetic"}`. If it doesn't load, the phone and Mac are not on the same network (or the macOS firewall is blocking `dart` — allow it in System Settings → Network → Firewall).

## 3. Install the app on the phone

APK: `keysthetic-app/build/app/outputs/flutter-apk/app-release.apk`

**Over USB (recommended):**
1. On the phone: Settings → About phone → tap *Build number* 7 times → Developer options → turn on **USB debugging**.
2. Plug the phone into the Mac, unlock it, accept "Allow USB debugging?".
3. Check it's seen, then install:
   ```bash
   /opt/homebrew/share/android-commandlinetools/platform-tools/adb devices
   /opt/homebrew/share/android-commandlinetools/platform-tools/adb install -r ~/Documents/Development/keysthetic-app/build/app/outputs/flutter-apk/app-release.apk
   ```

**Without a cable:** AirDrop isn't available for Android, so send the APK to the phone (e.g. Google Drive / Messenger / USB file copy), open it, and allow "Install unknown apps" for that app when Android asks.

The app needs **Android 7.0 or newer** (minSdk 24; built for Android 16 / API 36). The APK is ~65 MB because it contains all CPU types. It asks for Camera and Microphone only when you take a listing photo or record a typing clip.

## 4. First launch

1. **Connect to your server** → type `192.168.1.205:8080` (your address from step 2) → **Test connection** → "Connected. The server is up." → **Continue**.
2. Sign in with a demo account (password for all: `demo1234`):

| Role | Email |
|---|---|
| Buyer | `buyer@keysthetic.demo` |
| Seller | `seller@keysthetic.demo` |
| Admin | `admin@keysthetic.demo` |

To switch account: Profile → Sign out. To change server: Profile → Server → Change server.

If the server can't be reached, Test connection fails and **Use Demo mode** appears — the app then browses bundled offline data with a "Demo data" banner (read-only).

## 5. Defense click path

Tip: two phones (or phone + emulator) make the buyer↔seller steps smoother; with one phone, sign out and in between roles.

1. **Connect** screen → Test connection → Continue → sign in as **buyer**.
2. **Home feed** — staggered keycap cards; tap the category chips; tap **Fits my build** to filter to parts that fit a saved build.
3. Open a keyboard listing — photo **hero** transition, swipe the gallery, tap ▶ **Hear it first** (animated waveform), scroll to the **Legit Check** result and its disclaimer.
4. **Add to build** → pick a build → watch the thumbnail **fly** into the Build tab. Note the warning line when a part doesn't fit the build's specs.
5. **Build** tab — the layered keyboard fills in as slots fill; **drag it to tilt**; switch colourways; the total counts up; "Find compatible" on an empty slot opens a filtered search.
6. **Chats** → *Dark amber doubleshot PBT keycap set* thread → the seller's **counter** is pending → **Accept** → **Go to checkout**.
7. Checkout → **Pay via seller's QR** (sample QR, "SAMPLE: NOT A REAL ACCOUNT") → Confirm → **I've paid**.
8. Sign out → sign in as **seller** → **Orders** → open that order → **Confirm payment** → **Mark handed over**.
9. Sign out → **buyer** → Profile → My orders → open it → **Confirm received** → status **Completed** (also shown in the seller's Orders).
10. As **seller**: **My Listings** → **Post listing** → take a photo with the camera, set tags, **record a 5–10 s typing clip** → Post. Then **Run Legit Check** on a keyboard listing → pick the model → fill in → result reveals field by field.
11. As **admin**: **Listings** → Hide a listing → sign in as buyer → it's gone from the feed. (Unhide afterwards.)
12. **Offline fallback**: stop the server (Ctrl+C) → Profile → Change server → Test connection fails → **Use Demo mode** → browse with the "Demo data" banner.

Reset everything after rehearsals: stop the server, run `seed.dart`, start it again.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Test connection fails on the phone | Same Wi-Fi? Address current (`ipconfig getifaddr en0`)? Server terminal still running? Try `http://<ip>:8080/health` in the phone's browser. |
| Venue Wi-Fi blocks phone↔laptop traffic (common on school/guest Wi-Fi) | Turn on the phone's **hotspot**, join it from the Mac, re-check the Mac's address, use that. |
| `adb devices` shows nothing / "unauthorized" | Unlock the phone, re-plug, accept the USB debugging prompt; try another cable (some are charge-only). |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | An older build with a different signature is installed: `adb uninstall ph.keysthetic.keysthetic`, then install again. |
| Photos don't load but text does | The server must be the one you seeded; restart it from `keysthetic-server/`. |
