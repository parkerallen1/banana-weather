# banana_weather

A new Flutter project.

## API keys

The app reads an OpenWeatherMap key and a Gemini key from `lib/api_keys.dart`. The keys committed
there are visible to anyone, because this repo and its history are public. Both have been revoked:

- The Gemini key was already invalid when it was checked on 2026-10-05.
- The OpenWeatherMap key was deleted on 2026-10-05.

To run the app, put your own keys in `lib/api_keys.dart` and keep that change out of commits, for
example with `git update-index --skip-worktree lib/api_keys.dart`. Anything pushed here is public.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
