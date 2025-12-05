import 'dart:async';
import 'dart:collection';
import 'package:heart/heart.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:maestro/maestro.dart';
import 'package:pausable_timer/pausable_timer.dart';

class JustAudioSourceVisitor
    implements AudioSourceVisitor<FutureOr<ja.AudioSource>> {
  const JustAudioSourceVisitor();

  @override
  ja.AudioSource visitAssetSource(AssetAudioSource source) {
    return ja.AudioSource.asset(source.path);
  }

  @override
  ja.AudioSource visitFilepathSource(FilepathAudioSource source) {
    return ja.AudioSource.file(source.path);
  }

  @override
  ja.AudioSource visitNetworkSource(NetworkAudioSource source) {
    return ja.AudioSource.uri(Uri.parse(source.url));
  }

  @override
  Future<ja.AudioSource> visitPlaylistSource(PlaylistSource source) async {
    final paths = source.list;
    if (paths.length == 1) return paths.first.accept(this);
    final z = await Future.wait(paths.map((e) => Future.value(e.accept(this))));
    return ja.ConcatenatingAudioSource(children: z);
  }

  @override
  Future<ja.AudioSource> visitBytesSource(
    FutureBytesAudioSource bytesAudioSource,
  ) async {
    final bytes = await bytesAudioSource.bytesFuture;
    return ja.AudioSource.uri(Uri.dataFromBytes(bytes));
  }
}

extension JaLoopModeAdaptor on LoopMode {
  ja.LoopMode toJa() {
    return switch (this) {
      LoopMode.off => ja.LoopMode.off,
      LoopMode.one => ja.LoopMode.one,
      LoopMode.all => ja.LoopMode.all,
    };
  }
}

class AudioPlayerImpl implements AudioPlayer {
  AudioPlayerImpl(this._delegate);

  factory AudioPlayerImpl.music() {
    return AudioPlayerImpl(ja.AudioPlayer())
      ..setVolume(AudioConstants.musicVolume)
      ..setLoopMode(LoopMode.all);
  }

  factory AudioPlayerImpl.vfx() {
    return AudioPlayerImpl(ja.AudioPlayer())
      ..setVolume(AudioConstants.vfxVolume);
  }

  factory AudioPlayerImpl.voice() {
    return AudioPlayerImpl(ja.AudioPlayer())
      ..setVolume(AudioConstants.voiceVolume);
  }

  final ja.AudioPlayer _delegate;

  @override
  Future<void>? resourceSetFuture;

  @override
  Future<void> dispose() {
    return _delegate.dispose();
  }

  @override
  Future<void> pause() {
    return _delegate.pause();
  }

  @override
  Future<void> play() {
    return _delegate.play();
  }

  @override
  Future<void> seek(Duration? duration, {int? index}) {
    return _delegate.seek(duration, index: index);
  }

  @override
  Future<void> stop() {
    return _delegate.stop();
  }

  @override
  Duration? get duration => _delegate.duration;

  @override
  Future<void> move(Duration duration) {
    return _delegate.seek(_delegate.position + duration);
  }

  @override
  Duration? get position => _delegate.position;

  @override
  Stream<bool> get playingStream => _delegate.playingStream;

  @override
  Future<void> setVolume(double volume) {
    return _delegate.setVolume(volume);
  }

  @override
  bool get playing => _delegate.playing;

  @override
  Future<Duration?> setFilepath(String path) {
    return resourceSetFuture = _delegate.setFilePath(path);
  }

  @override
  Future<void> setLoopMode(LoopMode mode) {
    return _delegate.setLoopMode(mode.toJa());
  }

  @override
  Stream<void> get completedStream {
    return _delegate.processingStateStream.where(
      (event) => event == ja.ProcessingState.completed,
    );
  }

  @override
  Future<Duration?> setAsset(String path) async {
    return resourceSetFuture = _delegate.setAsset(path);
  }

  @override
  Future<Duration?> setAudioSource(AudioSource source) async {
    const visitor = JustAudioSourceVisitor();
    final jaAudioSource = await source.accept(visitor);
    return resourceSetFuture = _delegate.setAudioSource(jaAudioSource);
  }

  @override
  Stream<int?> get currentIndexStream {
    return _delegate.currentIndexStream;
  }

  //todo improve
  @override
  Duration getTrackDuration(int index) {
    final sequence = _delegate.sequence;
    if (sequence == null || sequence.length < 2) {
      final duration = _delegate.duration;
      if (duration == null) throw Exception('Duration = null');
      return duration;
    }
    final duration = sequence[index].duration;
    if (duration == null) throw Exception('Duration = null');
    return duration;
  }
}

class DisabledAudioPlayer implements AudioPlayer {
  DisabledAudioPlayer(this._delegate)
    : _processingStateSubject = StreamController.broadcast();

  final ja.AudioPlayer _delegate;
  final StreamController<ja.ProcessingState> _processingStateSubject;
  PausableTimer? _timer;

  @override
  Future<void>? resourceSetFuture;

  @override
  Future<void> dispose() {
    _timer?.cancel();
    return Future.wait([_processingStateSubject.close(), _delegate.dispose()]);
  }

  @override
  Future<void> pause() async {
    return _timer?.pause();
  }

  @override
  Future<void> play() async {
    final duration = _delegate.duration;
    if (duration == null) return;
    _timer ??= PausableTimer(duration, () {
      _processingStateSubject.add(ja.ProcessingState.completed);
      _timer?.cancel();
      _timer = null;
    })..start();
  }

  @override
  Future<void> seek(Duration? duration, {int? index}) async {
    if (duration == Duration.zero) {
      return _timer?.reset();
    }
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Duration? get duration => _delegate.duration;

  @override
  Future<void> move(Duration duration) async {}

  @override
  Duration? get position => _delegate.position;

  @override
  Stream<bool> get playingStream => const Stream.empty();

  @override
  Future<void> setVolume(double volume) {
    return Future.value();
  }

  @override
  bool get playing => _timer?.isActive ?? false;

  @override
  Future<Duration?> setFilepath(String path) {
    return resourceSetFuture = _delegate.setFilePath(path);
  }

  @override
  Future<void> setLoopMode(LoopMode mode) {
    return _delegate.setLoopMode(mode.toJa());
  }

  @override
  Stream<void> get completedStream {
    return _processingStateSubject.stream.where(
      (event) => event == ja.ProcessingState.completed,
    );
  }

  @override
  Future<Duration?> setAsset(String path) async {
    return resourceSetFuture = _delegate.setAsset(path);
  }

  @override
  Future<Duration?> setAudioSource(AudioSource source) async {
    const visitor = JustAudioSourceVisitor();
    final jaAudioSource = await source.accept(visitor);
    return resourceSetFuture = _delegate.setAudioSource(jaAudioSource);
  }

  @override
  Stream<int?> get currentIndexStream {
    return _delegate.currentIndexStream;
  }

  @override
  Duration getTrackDuration(int index) {
    final duration = _delegate.sequence?[index].duration;
    if (duration == null) throw Exception('Duration = null');
    return duration;
  }
}

class MusicPlayerImpl implements MusicPlayer {
  MusicPlayerImpl(this._playerQueue);

  MusicPlayerImpl.direct() : this(Queue());

  final Queue<AudioPlayer> _playerQueue;

  @override
  Stream<int?>? get currentIndexStream {
    return _playerQueue.lastOrNull?.currentIndexStream;
  }

  @override
  Future<void> pop() async {
    if (_playerQueue.isEmpty) throw Exception('Player queue is empty.');
    final last = _playerQueue.removeLast();
    await last.stop();
    await last.dispose();
    unawaited(_playerQueue.lastOrNull?.play());
  }

  Future<void> _push(Future<void> Function(AudioPlayer player) setAudio) async {
    if (_playerQueue.isNotEmpty) await _playerQueue.last.pause();
    final nextPlayer = AudioPlayerImpl.music();
    _playerQueue.add(nextPlayer);
    await setAudio(nextPlayer);
    unawaited(nextPlayer.play());
  }

  @override
  Future<void> pushAsset(String path) {
    return _push((player) => player.setAsset(path));
  }

  @override
  Future<void> pushAudioSource(AudioSource source) {
    return _push((player) => player.setAudioSource(source));
  }

  Future<void> _replace(
    Future<void> Function(AudioPlayer player) setAudio,
  ) async {
    if (_playerQueue.isEmpty) throw Exception('No player to replace.');
    final player = _playerQueue.last;
    unawaited(player.pause());
    await setAudio(player);
    unawaited(player.play());
  }

  @override
  Future<void> replaceAsset(String path) async {
    return _replace((player) => player.setAsset(path));
  }

  @override
  Future<void> replaceAudioSource(AudioSource source) {
    return _replace((player) => player.setAudioSource(source));
  }

  @override
  Future<void> dispose() {
    return Future.wait(_playerQueue.map((e) => e.dispose()));
  }

  @override
  Future<void> pause() async {
    await _playerQueue.last.pause();
  }

  @override
  Future<void> play() async {
    await _playerQueue.lastOrNull?.play();
  }

  @override
  Duration getTrackDuration(int index) {
    final currentPlayer = _playerQueue.lastOrNull;
    if (currentPlayer == null) throw Exception('There is no player atm.');
    return currentPlayer.getTrackDuration(index);
  }

  @override
  Future<void> restart() {
    final currentPlayer = _playerQueue.lastOrNull;
    if (currentPlayer == null) throw Exception('There is no player atm.');
    return currentPlayer.seek(Duration.zero);
  }

  @override
  Future<void> seek(Duration duration, {int? index}) {
    final currentPlayer = _playerQueue.lastOrNull;
    if (currentPlayer == null) throw Exception('There is no player atm.');
    return currentPlayer.seek(duration, index: index);
  }
}

class VfxPlayerImpl implements VfxPlayer {
  VfxPlayerImpl(this._pool);

  VfxPlayerImpl.direct()
    : this(
        PoolImpl(
          buildItem: AudioPlayerImpl.vfx,
          releaseItem: (value) => value.dispose(),
        ),
      );

  final Pool<AudioPlayer> _pool;

  @override
  Future<void> playAsset(String path) async {
    final player = await _pool.acquire();
    await player.setAsset(path);
    await player.play();
    StreamSubscription<void>? subscription;
    subscription = player.completedStream.listen((_) {
      unawaited(_pool.release(player));
      unawaited(subscription?.cancel());
    });
  }

  @override
  Future<void> dispose() {
    return _pool.disposeAll();
  }
}

class MaestroJustAudio implements Maestro {
  VfxPlayer? _vfxPlayer;
  AudioPlayer? _voicePlayer;
  MusicPlayer? _musicPlayer;

  @override
  VfxPlayer get vfxPlayer {
    return _vfxPlayer ??= VfxPlayerImpl.direct();
  }

  @override
  AudioPlayer get voicePlayer {
    return _voicePlayer ??= AudioPlayerImpl.voice();
  }

  @override
  MusicPlayer get musicPlayer {
    return _musicPlayer ??= MusicPlayerImpl.direct();
  }

  @override
  Future<void> dispose() {
    return Future.wait([
      vfxPlayer.dispose(),
      voicePlayer.dispose(),
      musicPlayer.dispose(),
    ]);
  }

  @override
  Future<void> pause() {
    return Future.wait([
      voicePlayer.pause(),
      Future.value(musicPlayer.pause()),
    ]);
  }

  @override
  Future<void> resume() {
    return Future.wait([voicePlayer.play(), Future.value(musicPlayer.play())]);
  }
}
