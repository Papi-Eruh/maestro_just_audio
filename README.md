# Maestro Just Audio

> This package was born out of the development of the [Erudit](https://github.com/Papi-Eruh/erudit_public) application. We decided to make it open source so other developers can benefit from it.

## What is Maestro Just Audio?

`maestro_just_audio` is a Flutter package that provides a concrete implementation of the [`maestro`](https://github.com/Papi-Eruh/maestro) audio interface package. It uses the powerful and popular [`just_audio`](https://pub.dev/packages/just_audio) library to handle audio playback, giving you a ready-to-use, full-featured audio system with a clean, decoupled architecture.

### Key Features:

*   **Ready-to-Use Implementation**: Provides a complete, out-of-the-box implementation of the `maestro` interfaces, saving you from writing boilerplate code.
*   **Powered by `just_audio`**: Leverages the robustness and extensive features of `just_audio`, including support for various audio formats, gapless playback, and platform integrations.
*   **Specialized Players**: Comes with pre-configured players for different audio types: a `MusicPlayer` for background music, a `voicePlayer` for voice-overs, and a `vfxPlayer` for sound effects.
*   **Advanced Audio Management**: Implements advanced features like a stack-based `MusicPlayer` for managing multiple playlists and a pool of players for handling concurrent sound effects efficiently.
*   **Seamless Integration**: Designed to work perfectly with packages like [`anecdotes`](https://github.com/Papi-Eruh/anecdotes) that are built on the `maestro` interfaces.

### Built with

*   [![Flutter][Flutter]][Flutter-url]
*   [![Dart][Dart]][Dart-url]
*   [just_audio](https://pub.dev/packages/just_audio)
*   [maestro](https://github.com/Papi-Eruh/maestro)

## Getting started

### Prerequisites

Make sure you have the Flutter SDK (version >=3.35.0) and Dart SDK (version >=3.9.0) installed.

### Installation

To use this package, add it as a git dependency in your `pubspec.yaml` file, along with the `maestro` interfaces.

```yaml
dependencies:
  flutter:
    sdk: flutter
  maestro:
    git:
      url: https://github.com/Papi-Eruh/maestro.git
  maestro_just_audio:
    git:
      url: https://github.com/Papi-Eruh/maestro_just_audio.git
```

Then, run `flutter pub get` in your project's root directory.

## Usage

Welcome to the `maestro_just_audio` package! Here’s how you can set up and use your audio system in just a few steps.

<br>

### 1. Create the Maestro

The first step is to create a `Maestro` instance. This package provides a simple factory function, `createMaestro()`, which will set up all the necessary players for you. It's recommended to have a single `Maestro` instance for your entire application.

```dart
import 'package:maestro_just_audio/maestro_just_audio.dart';

final maestro = createMaestro();
```

<br>

### 2. Define an `AudioSource`

The `maestro` package provides a flexible `AudioSource` system to define where your audio comes from. `maestro_just_audio` knows how to handle all of them.

```dart
import 'package:maestro/maestro.dart';

// Audio from your project's assets
final backgroundMusic = AssetAudioSource('assets/audio/theme.mp3');

// Audio from a network URL
final voiceOver = NetworkAudioSource('https://example.com/voice.mp3');

// A playlist of sources
final playlist = PlaylistSource([
  AssetAudioSource('assets/audio/track1.mp3'),
  AssetAudioSource('assets/audio/track2.mp3'),
]);
```

<br>

### 3. Control the Players

The `maestro` object gives you access to specialized players: `musicPlayer`, `voicePlayer`, and `vfxPlayer`.

#### Playing Background Music

The `musicPlayer` is designed for background music and can manage a stack of playlists.

```dart
// Start playing background music
await maestro.musicPlayer.pushAudioSource(backgroundMusic);
await maestro.musicPlayer.play();

// Later, you can pause it
await maestro.musicPlayer.pause();

// Or push a new track or playlist on top of the old one
await maestro.musicPlayer.pushAudioSource(playlist);

// When you're done with the current track/playlist, pop it to return to the previous one
await maestro.musicPlayer.pop();
```

#### Playing Voice-Overs

The `voicePlayer` is a simpler player, perfect for individual audio clips like dialogue or narration.

```dart
// Set the audio source for the voice player
await maestro.voicePlayer.setAudioSource(voiceOver);

// Play the voice-over
await maestro.voicePlayer.play();

// You can listen for when it's finished
maestro.voicePlayer.completedStream.listen((_) {
  print('Voice-over has finished playing.');
});
```

#### Playing Sound Effects

The `vfxPlayer` is optimized for short, often overlapping sound effects. It manages a pool of players to handle multiple effects at once.

```dart
// Play a sound effect
await maestro.vfxPlayer.playAsset('assets/audio/swoosh.wav');

// Play another one immediately after, even if the first isn't finished
await maestro.vfxPlayer.playAsset('assets/audio/click.mp3');
```

<br>

### 4. Clean Up

When your application is closing, or when you're done with the audio system, make sure to dispose of the `maestro` instance to release all resources.

```dart
await maestro.dispose();
```

You now have a fully functional, decoupled audio system in your Flutter app!

## License

Distributed under the MIT License. See `./LICENSE` for more information.

[Dart]: https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white
[Dart-url]: https://dart.dev/
[Flutter]: https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white
[Flutter-url]: https://flutter.dev/
