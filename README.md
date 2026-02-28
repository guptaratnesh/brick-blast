# 🧱 Brick Blast — Flutter Game

A fully working multi-platform Brick Blast game built with Flutter/Dart.
Runs on **Android, iOS, Web, Windows, macOS, and Linux**.

---

## 📁 Project Structure

```
brick_blast/
├── lib/
│   ├── main.dart            ← App entry point
│   ├── game_screen.dart     ← Main widget + game loop (Ticker)
│   ├── game_controller.dart ← All game logic (physics, collisions, powerups)
│   ├── game_models.dart     ← Data classes: Ball, Brick, Particle, Drop, etc.
│   └── game_painter.dart    ← All drawing via CustomPainter
├── pubspec.yaml             ← Dependencies
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.0+ installed → https://flutter.dev/docs/get-started/install
- For Android: Android Studio + Android SDK
- For iOS: Xcode (macOS only)

### Steps

```bash
# 1. Navigate to project folder
cd brick_blast

# 2. Get dependencies
flutter pub get

# 3. Run on your connected device or emulator
flutter run

# 4. Build release APK for Android
flutter build apk --release

# 5. Build for web
flutter build web

# 6. Build for Windows
flutter build windows
```

---

## 🎮 How to Play

- **Drag finger** left/right anywhere on screen to move the paddle
- **Tap** to start or retry
- Break all bricks to advance to the next level
- Catch falling powerup capsules with your paddle

### Powerups
| Icon | Name | Effect |
|------|------|--------|
| 🔥 | FIREBALL | Ball burns through bricks without bouncing |
| ⬛ | BIG BALL | Ball size doubles |
| ✦ | MULTIBALL | Adds 2 extra balls |
| ❤ | LIFE | Gain an extra life |

---

## 🏪 Publishing to Play Store

1. **Build a release AAB:**
   ```bash
   flutter build appbundle --release
   ```

2. **Sign your app** — follow Flutter's signing guide:
   https://docs.flutter.dev/deployment/android

3. Upload the `.aab` file from `build/app/outputs/bundle/release/` to Google Play Console.

---

## 🔧 Customization Tips

- `game_models.dart` → Change `brickColors`, brick layout, powerup drop rate
- `game_controller.dart` → Tweak ball speed (`6.0 + level * 0.4`), lives, powerup duration
- `game_painter.dart` → Change colors, add new visual effects
- `pubspec.yaml` → Add `shared_preferences` package to persist high scores properly

---

## 📦 Add High Score Persistence (optional)

```bash
flutter pub add shared_preferences
```

Then in `game_controller.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadBest() async {
  final prefs = await SharedPreferences.getInstance();
  best = prefs.getInt('best') ?? 0;
}

Future<void> saveBest() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('best', best);
}
```
