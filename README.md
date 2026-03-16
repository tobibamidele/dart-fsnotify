# dartnotify

Cross-platform filesystem notifications for Dart — inspired by
[fsnotify/fsnotify](https://github.com/fsnotify/fsnotify).

Watch files and directories for `CREATE`, `WRITE`, `REMOVE`, `RENAME`, and
`CHMOD` events through a single, unified stream API.

---

## Features

- Watch individual **files** or entire **directories**
- Optional **recursive** directory watching
- Unified `Stream<FsEvent>` — no callbacks, fully `async`/`await` compatible
- Separate `Stream<WatcherError>` for non-fatal errors
- Bitfield `Op` type — compose and test event kinds with `|` and `has()`
- Clean `close()` lifecycle — releases all OS handles in one call

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dartnotify: ^0.1.0
```

Then run:

```sh
dart pub get
```

---

## Quickstart

```dart
import 'package:dartnotify/dartnotify.dart';

void main() async {
  final watcher = await Watcher.create();

  // Subscribe BEFORE add() — never miss an early event.
  watcher.events.listen((FsEvent event) {
    print('[${event.op}] ${event.name}');
  });

  watcher.errors.listen((WatcherError err) {
    print('Error: $err');
  });

  await watcher.add('/tmp/my-dir');

  // Keep running for 30 s, then clean up.
  await Future.delayed(const Duration(seconds: 30));
  await watcher.close();
}
```

---

## API Reference

### `Watcher`

The central class. One instance manages any number of watched paths.

#### `static Future<Watcher> Watcher.create()`

Creates and returns a new `Watcher`. No paths are watched yet.

```dart
final watcher = await Watcher.create();
```

---

#### `Future<void> add(String path, {bool recursive = false})`

Adds `path` to the watch list.

| Parameter   | Type     | Default | Description                                      |
|-------------|----------|---------|--------------------------------------------------|
| `path`      | `String` | —       | Absolute or relative path to a file or directory |
| `recursive` | `bool`   | `false` | Also watch subdirectories recursively            |

Throws `WatcherError` if:
- `path` does not exist
- `path` is already being watched
- The watcher has been closed

```dart
await watcher.add('/var/log/app');                     // directory
await watcher.add('/etc/hosts');                       // single file
await watcher.add('/srv/data', recursive: true);       // recursive
```

---

#### `Future<void> remove(String path)`

Removes `path` from the watch list and cancels its underlying OS subscription.

Throws `WatcherError` if `path` is not currently being watched.

```dart
await watcher.remove('/var/log/app');
```

---

#### `Stream<FsEvent> get events`

A broadcast stream of `FsEvent` objects emitted whenever any watched path
changes.

```dart
watcher.events.listen((event) {
  if (event.op.has(Op.write)) {
    print('File written: ${event.name}');
  }
});
```

---

#### `Stream<WatcherError> get errors`

A broadcast stream of non-fatal `WatcherError`s (e.g. permission denied on a
subdirectory). The watcher continues running after an error.

```dart
watcher.errors.listen((err) {
  print('Watch error on ${err.path}: ${err.message}');
});
```

---

#### `Set<String> get watchList`

Returns an unmodifiable snapshot of the paths currently being watched.

```dart
print(watcher.watchList); // {/etc/hosts, /var/log/app}
```

---

#### `Future<void> close()`

Cancels all watches and closes both streams. Safe to call multiple times. The
watcher cannot be reused after closing.

```dart
await watcher.close();
```

---

### `FsEvent`

Represents a single filesystem event.

| Field  | Type     | Description                           |
|--------|----------|---------------------------------------|
| `name` | `String` | Absolute path of the affected file    |
| `op`   | `Op`     | The operation(s) that triggered this  |

```dart
watcher.events.listen((FsEvent event) {
  print('${event.op} → ${event.name}');
  // CREATE → /tmp/my-dir/newfile.txt
});
```

---

### `Op`

Bitfield type representing one or more filesystem operations.

| Constant    | Meaning                              |
|-------------|--------------------------------------|
| `Op.create` | File or directory was created        |
| `Op.write`  | File content or metadata was updated |
| `Op.remove` | File or directory was deleted        |
| `Op.rename` | File or directory was moved/renamed  |
| `Op.chmod`  | Permissions were changed             |

#### `Op operator |(Op other)` — combine flags

```dart
final mask = Op.create | Op.write;
```

#### `bool has(Op flag)` — test for a flag

```dart
if (event.op.has(Op.create)) {
  print('New file: ${event.name}');
}
```

#### `String toString()`

Returns a human-readable pipe-separated string, e.g. `CREATE|WRITE`.

---

### `WatcherError`

A non-fatal exception describing a watch error.

| Field     | Type      | Description                              |
|-----------|-----------|------------------------------------------|
| `message` | `String`  | Human-readable error description         |
| `path`    | `String?` | The path associated with the error, if any |

---

## Patterns

### Watch multiple paths

```dart
final watcher = await Watcher.create();
watcher.events.listen((e) => print(e));

await watcher.add('/etc');
await watcher.add('/tmp');
await watcher.add('/var/log', recursive: true);
```

### Filter by operation

```dart
watcher.events
    .where((e) => e.op.has(Op.remove))
    .listen((e) => print('Deleted: ${e.name}'));
```

### React only to specific files

```dart
watcher.events
    .where((e) => e.name.endsWith('.json'))
    .listen((e) => reloadConfig(e.name));
```

### Graceful shutdown on SIGINT

```dart
import 'dart:io';

await ProcessSignal.sigint.watch().first;
await watcher.close();
```

---

## Running the example

```sh
dart run example/watch.dart /tmp/my-dir
dart run example/watch.dart /tmp/my-dir --recursive
```

---

## Running tests

```sh
dart test
```

---

## Platform support

| Platform | Backend                        |
|----------|-------------------------------|
| Linux    | `inotify` (via `dart:io`)     |
| macOS    | `kqueue` / FSEvents           |
| Windows  | `ReadDirectoryChangesW`       |

> `chmod` events are only available on Unix-like systems. On Windows,
> `Op.chmod` is never emitted.

---

## License

MIT. See [LICENSE](LICENSE).
