# stempo

Tempo-aware running companion built with Flutter. `stempo` helps users walk or run in sync with music tempo by combining Spotify playback data with motion and step tracking.

## Features

- Spotify OAuth authentication and remote playback integration
- Now Playing, Library, Playlists, and Search experiences
- Step and motion tracking to support pace-aware interaction
- Onboarding flow for Spotify connection and movement setup
- Cross-platform Flutter targets (Android, iOS, Web, Desktop)

## Tech Stack

- Flutter / Dart
- `go_router` for navigation
- `flutter_dotenv` for environment configuration
- `flutter_web_auth_2` for OAuth callback flow
- `health` for step/fitness data
- `lottie` for animated UI elements

## Project Structure

```text
lib/
  app/            # App shell, router, and root widgets
  controllers/    # Auth and Spotify remote service logic
  pages/          # Screens (home, now playing, playlists, onboarding, etc.)
  services/       # Platform/data services (step tracking)
  state/          # Models and state providers
  ui/             # Theme, components, and reusable widgets
  main.dart       # Entry point (loads .env and starts AuthScope)
```

## Prerequisites

- Flutter SDK compatible with `sdk: ^3.9.2` (see `pubspec.yaml`)
- Spotify Developer account and app credentials
- Emulator/simulator or physical device for mobile testing

## Setup

1. Clone the repository.
2. Create a `.env` file in the project root using `.env.example`.
3. Install dependencies.

```bash
flutter pub get
```

### Environment Variables

```env
SPOTIFY_CLIENT_ID=your_spotify_client_id
SPOTIFY_CLIENT_SECRET=your_spotify_client_secret
SPOTIFY_REDIRECT_URI=stempo://spotify-callback
```

**Important:** Register the same redirect URI scheme in platform configuration files (`AndroidManifest.xml` and `Info.plist`) to ensure OAuth callback handling works correctly.

## Running the App

```bash
flutter run
```

Run on a specific target:

```bash
flutter run -d android
flutter run -d ios
flutter run -d chrome
```

## Testing

```bash
flutter test
```

## Build

```bash
# Android
flutter build apk

# iOS
flutter build ipa
```

## Important Files

- `pubspec.yaml` - dependencies, assets, fonts, SDK constraint
- `.env.example` - sample environment variables
- `lib/controllers/auth_controller.dart` - Spotify auth flow
- `lib/controllers/spotify_remote_service.dart` - Spotify playback/data integration
- `lib/services/step_service.dart` - step/motion integration

## Contributing

- Keep pull requests focused and small.
- Follow existing lint/style rules (`flutter_lints`).
- Include clear reproduction and validation steps in PR descriptions.
