import 'package:maestro/maestro.dart';
import 'package:maestro_just_audio/src/maestro_just_audio.dart';

/// Creates a [Maestro] instance for the application.
///
/// It is recommended to create a single instance of [Maestro] for the entire
/// application.
Maestro createMaestro() {
  return MaestroJustAudio();
}

/// Creates an additional [AudioPlayer] specifically designed for voice
/// playback.
///
/// This can be used, for example, to compute the duration of a voice track in
/// parallel with another voice.
AudioPlayer createVoicePlayer() {
  return AudioPlayerImpl.voice();
}

/// Creates an additional [AudioPlayer] specifically designed for music
/// playback.
///
/// This can be used, for example, to compute the duration of a music track in
/// parallel with another music track.
AudioPlayer createMusicPlayer() {
  return AudioPlayerImpl.music();
}
