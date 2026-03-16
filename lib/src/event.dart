/// Filesystem event operation flags.
///
/// Multiple operations can be set on a single [FsEvent] using bitwise OR.
/// For example, a file renamed and written at the same time would have
/// `Op.create | Op.write`.
class Op {
  final int _value;

  const Op._(this._value);

  static const Op create = Op._(1 << 0);
  static const Op write  = Op._(1 << 1);
  static const Op remove = Op._(1 << 2);
  static const Op rename = Op._(1 << 3);
  static const Op chmod  = Op._(1 << 4);

  /// Combines two [Op] values via bitwise OR.
  Op operator |(Op other) => Op._(_value | other._value);

  /// Returns true if this [Op] contains the given operation flag.
  bool has(Op other) => (_value & other._value) != 0;

  @override
  bool operator ==(Object other) => other is Op && _value == other._value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() {
    final parts = <String>[];
    if (has(create)) parts.add('CREATE');
    if (has(write))  parts.add('WRITE');
    if (has(remove)) parts.add('REMOVE');
    if (has(rename)) parts.add('RENAME');
    if (has(chmod))  parts.add('CHMOD');
    return parts.isEmpty ? 'NONE' : parts.join('|');
  }
}

/// Represents a single filesystem event emitted by a [Watcher].
///
/// Each event has a [name] (the absolute path of the affected file) and an
/// [op] describing what happened.
///
/// Example:
/// ```dart
/// watcher.events.listen((event) {
///   print('${event.op} → ${event.name}');
/// });
/// ```
class FsEvent {
  /// The absolute path of the file or directory affected.
  final String name;

  /// The operation(s) that triggered this event.
  final Op op;

  const FsEvent({required this.name, required this.op});

  @override
  String toString() => 'FsEvent(op: $op, name: "$name")';
}

/// Thrown when an error occurs inside the watcher.
class WatcherError implements Exception {
  final String message;
  final String? path;

  const WatcherError(this.message, {this.path});

  @override
  String toString() =>
      path != null ? 'WatcherError: $message (path: $path)' : 'WatcherError: $message';
}
