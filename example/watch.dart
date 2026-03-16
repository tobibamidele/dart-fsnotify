import 'dart:io';

import 'package:dart_fsnotify/dart_fsnotify.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: watch <path> [--recursive]');
    exit(1);
  }

  final path      = args[0];
  final recursive = args.contains('--recursive');

  print('dartnotify — watching: $path (recursive: $recursive)');
  print('Press Ctrl-C to stop.\n');

  final watcher = await Watcher.create();

  // Subscribe BEFORE calling add() to guarantee no events are missed.
  watcher.events.listen((FsEvent event) {
    final tag = event.op.toString().padRight(8);
    print('[$tag] ${event.name}');
  });

  watcher.errors.listen((WatcherError err) {
    stderr.writeln('ERROR: $err');
  });

  try {
    await watcher.add(path, recursive: recursive);
  } on WatcherError catch (e) {
    stderr.writeln('Failed to add watch: $e');
    await watcher.close();
    exit(1);
  }

  // Run until interrupted.
  await ProcessSignal.sigint.watch().first;
  print('\nShutting down...');
  await watcher.close();
}
