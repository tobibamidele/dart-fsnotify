import 'dart:io';

import 'package:dart_fsnotify/dart_fsnotify.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;
  late Watcher watcher;

  setUp(() async {
    tmpDir  = await Directory.systemTemp.createTemp('dartnotify_test_');
    watcher = await Watcher.create();
  });

  tearDown(() async {
    await watcher.close();
    await tmpDir.delete(recursive: true);
  });

  group('Watcher', () {
    test('emits CREATE event when a file is created', () async {
      final events = <FsEvent>[];
      watcher.events.listen(events.add);
      await watcher.add(tmpDir.path);

      final file = File('${tmpDir.path}/hello.txt');
      await file.create();

      await Future.delayed(const Duration(milliseconds: 200));

      expect(events, isNotEmpty);
      expect(events.any((e) => e.op.has(Op.create) && e.name.endsWith('hello.txt')), isTrue);
    });

    test('emits WRITE event when a file is modified', () async {
      final file = await File('${tmpDir.path}/data.txt').create();

      final events = <FsEvent>[];
      watcher.events.listen(events.add);
      await watcher.add(tmpDir.path);

      await file.writeAsString('updated content');
      await Future.delayed(const Duration(milliseconds: 200));

      expect(events.any((e) => e.op.has(Op.write) && e.name.endsWith('data.txt')), isTrue);
    });

    test('emits REMOVE event when a file is deleted', () async {
      final file = await File('${tmpDir.path}/temp.txt').create();

      final events = <FsEvent>[];
      watcher.events.listen(events.add);
      await watcher.add(tmpDir.path);

      await file.delete();
      await Future.delayed(const Duration(milliseconds: 200));

      expect(events.any((e) => e.op.has(Op.remove) && e.name.endsWith('temp.txt')), isTrue);
    });

    test('watchList reflects added paths', () async {
      await watcher.add(tmpDir.path);
      expect(watcher.watchList, contains(tmpDir.path));
    });

    test('remove() stops watching a path', () async {
      await watcher.add(tmpDir.path);
      await watcher.remove(tmpDir.path);
      expect(watcher.watchList, isEmpty);
    });

    test('add() throws WatcherError for non-existent path', () async {
      expect(
        () => watcher.add('/non/existent/path/xyz'),
        throwsA(isA<WatcherError>()),
      );
    });

    test('add() throws WatcherError when already watching', () async {
      await watcher.add(tmpDir.path);
      expect(
        () => watcher.add(tmpDir.path),
        throwsA(isA<WatcherError>()),
      );
    });

    test('remove() throws WatcherError for unwatched path', () async {
      expect(
        () => watcher.remove(tmpDir.path),
        throwsA(isA<WatcherError>()),
      );
    });

    test('add() throws WatcherError after close()', () async {
      await watcher.close();
      expect(
        () => watcher.add(tmpDir.path),
        throwsA(isA<WatcherError>()),
      );
    });

    test('close() is idempotent', () async {
      await watcher.add(tmpDir.path);
      await watcher.close();
      await watcher.close(); // second call must not throw
    });
  });

  group('Op', () {
    test('has() works for single flags', () {
      expect(Op.create.has(Op.create), isTrue);
      expect(Op.create.has(Op.write), isFalse);
    });

    test('bitwise OR combines flags', () {
      final combined = Op.create | Op.write;
      expect(combined.has(Op.create), isTrue);
      expect(combined.has(Op.write),  isTrue);
      expect(combined.has(Op.remove), isFalse);
    });

    test('toString() renders flag names', () {
      expect(Op.create.toString(), 'CREATE');
      expect((Op.create | Op.write).toString(), 'CREATE|WRITE');
    });
  });

  group('FsEvent', () {
    test('toString includes op and name', () {
      final event = FsEvent(name: '/tmp/foo.txt', op: Op.write);
      expect(event.toString(), contains('WRITE'));
      expect(event.toString(), contains('/tmp/foo.txt'));
    });
  });
}
