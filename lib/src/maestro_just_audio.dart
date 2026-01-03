import 'dart:async';
import 'dart:collection';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:maestro/maestro.dart';
import 'package:rxdart/rxdart.dart';
import 'package:synchronized/synchronized.dart';

/// A visitor that converts an [AudioSource] into a [ja.AudioSource].
class JustAudioSourceVisitor
    implements AudioSourceVisitor<FutureOr<ja.AudioSource>> {
  /// Creates a [JustAudioSourceVisitor].
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
    final children = await Future.wait(
      paths.map((e) => Future.value(e.accept(this))),
    );
    return ja.ConcatenatingAudioSource(children: children);
  }

  @override
  Future<ja.AudioSource> visitBytesSource(
    FutureBytesAudioSource bytesAudioSource,
  ) async {
    final bytes = await bytesAudioSource.bytesFuture;
    return ja.AudioSource.uri(Uri.dataFromBytes(bytes));
  }
}

/// An extension that converts a [LoopMode] into a [ja.LoopMode].
extension JaLoopModeAdaptor on LoopMode {
  /// Converts a [LoopMode] into a [ja.LoopMode].
  ja.LoopMode toJa() {
    return switch (this) {
      LoopMode.off => ja.LoopMode.off,
      LoopMode.one => ja.LoopMode.one,
      LoopMode.all => ja.LoopMode.all,
    };
  }
}

/// An implementation of [AudioPlayer] that uses the `just_audio` package.
class AudioPlayerImpl implements AudioPlayer {
  /// Creates an [AudioPlayerImpl] with the given [ja.AudioPlayer].
  AudioPlayerImpl(this._delegate);

  /// Creates an [AudioPlayerImpl] for music playback.
  factory AudioPlayerImpl.music() {
    return AudioPlayerImpl(ja.AudioPlayer())
      ..setVolume(AudioConstants.musicVolume)
      ..setLoopMode(LoopMode.all);
  }

  /// Creates an [AudioPlayerImpl] for visual effects playback.
  factory AudioPlayerImpl.vfx() {
    return AudioPlayerImpl(ja.AudioPlayer())
      ..setVolume(AudioConstants.vfxVolume);
  }

  /// Creates an [AudioPlayerImpl] for voice playback.
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
  Future<Duration?> setAudioSource(
    AudioSource source, {
    int? initialIndex,
  }) async {
    const visitor = JustAudioSourceVisitor();
    final jaAudioSource = await source.accept(visitor);
    return resourceSetFuture = _delegate.setAudioSource(
      jaAudioSource,
      initialIndex: initialIndex,
    );
  }

  @override
  Stream<int?> get currentIndexStream {
    return _delegate.currentIndexStream;
  }

  @override
  Stream<Duration?> durationStreamByIndex(int index) {
    return Rx.combineLatest2<int?, Duration?, Duration?>(
      _delegate.currentIndexStream,
      _delegate.durationStream.where((e) => e != null && e != Duration.zero),
      (currentIndex, currentDuration) {
        if (currentIndex == index) {
          return currentDuration;
        }
        return null;
      },
    ).distinct();
  }
}

/// An implementation of [MusicPlayer] that uses a queue of [AudioPlayer]s.
class MusicPlayerImpl implements MusicPlayer {
  /// Creates a [MusicPlayerImpl] with the given queue of [AudioPlayer]s.
  MusicPlayerImpl(this._playerQueue);

  /// Creates a [MusicPlayerImpl] with an empty queue.
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
  Future<void> pushAudioSource(AudioSource source, {int? initialIndex}) {
    return _push(
      (player) => player.setAudioSource(source, initialIndex: initialIndex),
    );
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
  Future<void> replaceAudioSource(AudioSource source, {int? initialIndex}) {
    return _replace(
      (player) => player.setAudioSource(source, initialIndex: initialIndex),
    );
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
  Future<void> seek(Duration duration, {int? index}) {
    final currentPlayer = _playerQueue.lastOrNull;
    if (currentPlayer == null) throw Exception('There is no player atm.');
    return currentPlayer.seek(duration, index: index);
  }

  @override
  Stream<Duration?> durationStreamByIndex(int index) {
    final currentPlayer = _playerQueue.lastOrNull;
    if (currentPlayer == null) throw Exception('There is no player atm.');
    return currentPlayer.durationStreamByIndex(index);
  }
}

/// An implementation of [VfxPlayer] that uses a pool of [AudioPlayer]s.
class VfxPlayerImpl implements VfxPlayer {
  /// Creates a [VfxPlayerImpl] with the given pool of [AudioPlayer]s.
  VfxPlayerImpl(this._pool);

  /// Creates a [VfxPlayerImpl] with a default pool.
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

/// An implementation of [Maestro] that uses `just_audio`.
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

/// A pool of objects of type [T].
abstract class Pool<T> {
  /// Acquires an object from the pool.
  Future<T> acquire();

  /// Releases an object back to the pool.
  Future<void> release(T value);

  /// Disposes all the objects in the pool.
  Future<void> disposeAll();
}

/// An implementation of [Pool].
class PoolImpl<T> implements Pool<T> {
  /// Creates a [PoolImpl] with the given [buildItem] and [releaseItem]
  /// functions.
  PoolImpl({required this.buildItem, required this.releaseItem}) {
    _freeResource = buildItem();
  }

  /// A function that builds an object of type [T].
  final T Function() buildItem;

  /// A function that releases an object of type [T].
  final Future<void> Function(T value) releaseItem;
  T? _freeResource;
  final Set<T> _busyResources = {};
  final _lock = Lock();

  @override
  Future<T> acquire() async {
    final resource = await _lock.synchronized(
      () {
        final next = _freeResource ?? buildItem();
        _busyResources.add(next);
        _freeResource = null;
        return next;
      },
    );
    return resource;
  }

  @override
  Future<void> release(T res) async {
    T? toDispose;
    await _lock.synchronized(
      () async {
        if (!_busyResources.contains(res)) return;
        if (_freeResource != null) toDispose = res;
        _freeResource ??= res;
        _busyResources.remove(res);
      },
    );
    if (toDispose != null) unawaited(releaseItem(res));
  }

  @override
  Future<void> disposeAll() async {
    return _lock.synchronized(
      () async {
        await Future.wait([
          if (_freeResource != null) releaseItem(_freeResource as T),
          ..._busyResources.map(releaseItem),
        ]);
        _busyResources.clear();
        _freeResource = null;
      },
    );
  }
}
