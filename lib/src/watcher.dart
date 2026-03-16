import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'event.dart';

export 'event.dart';

/// A cross-platform filesystem watcher.
///
/// [Watcher] wraps Dart's `dart:io` watch streams and exposes a unified stream of
/// [FsEvent] objects, matching the ergonomics of Go's fsnotify package.
///
/// Use [Watcher.create] to instantiate and start watching:
///
/// ```dart
/// final watcher = await Watcher.create();
/// await watcher.add('/tmp/mydir');
///
/// watcher.events.listen((event) {
///   print(event);
/// });
///
/// watcher.errors.listen((err) {
///   print('Watch error: $err');
/// });
///
/// // Later...
/// await watcher.close();
/// ```
class Watcher {
  final StreamController<FsEvent> _eventController;
  final StreamController<WatcherError> _errorController;

  // Map from watched path → subscription to its FileSystemWatcher stream.
  final Map<String, StreamSubscription<FileSystemEvent>> _subs = {};

  bool _closed = false;

  Watcher._()
      : _eventController = StreamController<FsEvent>.broadcast(),
        _errorController = StreamController<WatcherError>.broadcast();

  /// Creates a new [Watcher] instance.
  ///
  /// The watcher is ready to use immediately; call [add] to start watching
  /// paths.
  static Future<Watcher> create() async {
    return Watcher._();
  }

  /// A broadcast stream of [FsEvent]s emitted for all watched paths.
  ///
  /// Subscribe before calling [add] to avoid missing early events.
  Stream<FsEvent> get events => _eventController.stream;

  /// A broadcast stream of [WatcherError]s from all watched paths.
  ///
  /// Errors here are non-fatal; the watcher continues running.
  Stream<WatcherError> get errors => _errorController.stream;

  /// Returns the set of paths currently being watched.
  Set<String> get watchList => Set.unmodifiable(_subs.keys);

  /// Adds [path] to the watch list.
  ///
  /// [path] may be a file or a directory. If [path] is a directory, all
  /// direct children are watched (non-recursive by default). Pass
  /// [recursive] as `true` to watch subdirectories as well.
  ///
  /// Throws [WatcherError] if:
  /// - The watcher has been closed.
  /// - [path] does not exist.
  /// - [path] is already being watched.
  ///
  /// ```dart
  /// await watcher.add('/var/log');
  /// await watcher.add('/etc/hosts');
  /// await watcher.add('/srv/data', recursive: true);
  /// ```
  Future<void> add(String path, {bool recursive = false}) async {
    if (_closed) throw const WatcherError('Watcher is closed');

    final resolved = p.canonicalize(path);

    if (_subs.containsKey(resolved)) {
      throw WatcherError('Already watching path', path: resolved);
    }

    final type = FileSystemEntity.typeSync(resolved, followLinks: true);
    if (type == FileSystemEntityType.notFound) {
      throw WatcherError('No such file or directory', path: resolved);
    }

    // dart:io exposes watch() on Directory and File, not a standalone class.
    final Stream<FileSystemEvent> watchStream;
    if (type == FileSystemEntityType.directory) {
      watchStream = Directory(resolved).watch(recursive: recursive);
    } else {
      // Files don't support the recursive flag.
      watchStream = File(resolved).watch();
    }

    final sub = watchStream.listen(
      (fse) => _dispatch(fse),
      onError: (Object err) {
        _errorController.add(WatcherError(err.toString(), path: resolved));
      },
      cancelOnError: false,
    );

    _subs[resolved] = sub;
  }

  /// Removes [path] from the watch list and stops watching it.
  ///
  /// Throws [WatcherError] if [path] is not currently being watched.
  ///
  /// ```dart
  /// await watcher.remove('/var/log');
  /// ```
  Future<void> remove(String path) async {
    final resolved = p.canonicalize(path);
    final sub = _subs.remove(resolved);
    if (sub == null) {
      throw WatcherError('Path is not being watched', path: resolved);
    }
    await sub.cancel();
  }

  /// Closes the watcher and releases all resources.
  ///
  /// After calling [close], the [events] and [errors] streams are closed and
  /// the watcher cannot be reused.
  ///
  /// ```dart
  /// await watcher.close();
  /// ```
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final sub in _subs.values) {
      await sub.cancel();
    }
    _subs.clear();
    await _eventController.close();
    await _errorController.close();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Internal helpers
  // ────────────────────────────────────────────────────────────────────────────

  void _dispatch(FileSystemEvent fse) {
    if (_closed) return;

    final op = _toOp(fse);
    if (op == null) return;

    _eventController.add(FsEvent(name: fse.path, op: op));

    // If a rename/move event carries a destination, emit a CREATE for it.
    if (fse is FileSystemMoveEvent && fse.destination != null) {
      _eventController.add(FsEvent(name: fse.destination!, op: Op.create));
    }
  }

  Op? _toOp(FileSystemEvent fse) {
    if (fse is FileSystemCreateEvent) return Op.create;
    if (fse is FileSystemModifyEvent) return Op.write;
    if (fse is FileSystemDeleteEvent) return Op.remove;
    if (fse is FileSystemMoveEvent)   return Op.rename;
    return null;
  }
}
