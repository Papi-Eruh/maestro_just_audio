import 'package:maestro/maestro.dart';
import 'package:maestro_just_audio/src/maestro_just_audio.dart';

/// Create a maestro for an app.
/// One should create a single instance for the app.
Maestro createMaestro() {
  return MaestroJustAudio();
}

/// Create additional [AudioPlayer] designed for voices.
/// eg: to be able to compute duration in parallel of another voice.
AudioPlayer createVoicePlayer() {
  return AudioPlayerImpl.voice();
}

/// Create additional [AudioPlayer] designed for music.
/// eg: to be able to compute duration in parallel of another music.
AudioPlayer createMusicPlayer() {
  return AudioPlayerImpl.music();
}