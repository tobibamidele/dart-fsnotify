/// dartnotify — cross-platform filesystem notifications for Dart.
///
/// Inspired by [fsnotify](https://github.com/fsnotify/fsnotify) for Go.
///
/// ## Quickstart
///
/// ```dart
/// import 'package:dartnotify/dartnotify.dart';
///
/// void main() async {
///   final watcher = await Watcher.create();
///
///   await watcher.add('/tmp/watch-me');
///
///   watcher.events.listen((event) {
///     print('[${event.op}] ${event.name}');
///   });
///
///   watcher.errors.listen((err) {
///     print('Error: $err');
///   });
///
///   // Keep alive for 30 seconds, then shut down.
///   await Future.delayed(const Duration(seconds: 30));
///   await watcher.close();
/// }
/// ```
library dartnotify;

export 'src/event.dart';
export 'src/watcher.dart' show Watcher;
