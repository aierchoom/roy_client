import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/hlc.dart';

void main() {
  group('Hlc', () {
    test('constructs with values', () {
      const hlc = Hlc(1000, 5, 'node_a');
      expect(hlc.time, 1000);
      expect(hlc.counter, 5);
      expect(hlc.nodeId, 'node_a');
    });

    test('zero factory creates origin clock', () {
      const hlc = Hlc(0, 0, 'node_a');
      expect(hlc.time, 0);
      expect(hlc.counter, 0);
      expect(hlc.nodeId, 'node_a');
    });

    test('now factory uses current time', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final hlc = Hlc.now('node_b');
      final after = DateTime.now().millisecondsSinceEpoch;
      expect(hlc.time, greaterThanOrEqualTo(before));
      expect(hlc.time, lessThanOrEqualTo(after));
      expect(hlc.counter, 0);
      expect(hlc.nodeId, 'node_b');
    });

    test('parse recovers from string', () {
      const original = Hlc(1234, 7, 'device_x');
      final recovered = Hlc.parse(original.toString());
      expect(recovered, original);
    });

    test('parse returns corrupted sentinel on invalid input', () {
      final corrupted = Hlc.parse('invalid');
      expect(corrupted.isCorrupted, isTrue);
      expect(corrupted.time, 0);
      expect(corrupted.counter, 0);
    });

    test('parse handles nodeId with multiple hyphens', () {
      const original = Hlc(1000, 1, 'a-b-c-d');
      final recovered = Hlc.parse(original.toString());
      expect(recovered, original);
    });

    test('comparison uses time then counter then nodeId', () {
      const a = Hlc(10, 0, 'a');
      const b = Hlc(10, 1, 'a');
      const c = Hlc(10, 1, 'b');
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(c), lessThan(0));
      expect(a.compareTo(a), 0);
    });

    test('equality and hashCode', () {
      const a = Hlc(10, 5, 'node');
      const b = Hlc(10, 5, 'node');
      const c = Hlc(10, 5, 'other');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('toString formats as time-counter-nodeId', () {
      const hlc = Hlc(1000, 3, 'n1');
      expect(hlc.toString(), '1000-3-n1');
    });
  });

  group('SyncClock', () {
    test('send advances time when physical time is ahead', () {
      final clock = SyncClock('node');
      final before = DateTime.now().millisecondsSinceEpoch;
      final hlc = clock.send();
      expect(hlc.time, greaterThanOrEqualTo(before));
      expect(hlc.counter, 0);
    });

    test('send increments counter when time is same', () {
      final clock = SyncClock(
        'node',
        initialClock: Hlc(
          DateTime.now().millisecondsSinceEpoch + 10000,
          0,
          'node',
        ),
      );
      final first = clock.send();
      expect(first.counter, 1);
      final second = clock.send();
      expect(second.counter, 2);
    });

    test(
      'receive advances to remote time when remote is ahead of physical time',
      () {
        final future = DateTime.now().millisecondsSinceEpoch + 10000;
        final clock = SyncClock('node', initialClock: Hlc(future, 0, 'node'));
        clock.receive(Hlc(future + 100, 5, 'remote'));
        expect(clock.current.time, future + 100);
        expect(clock.current.counter, 6);
      },
    );

    test(
      'receive increments counter on same time when ahead of physical time',
      () {
        final future = DateTime.now().millisecondsSinceEpoch + 10000;
        final clock = SyncClock('node', initialClock: Hlc(future, 0, 'node'));
        clock.receive(Hlc(future, 5, 'remote'));
        expect(clock.current.time, future);
        expect(clock.current.counter, 6);
      },
    );
  });

  group('SyncValue', () {
    test('toJson serializes value and hlc', () {
      const value = SyncValue('hello', Hlc(10, 0, 'n'));
      expect(value.toJson(), {'v': 'hello', 'hlc': '10-0-n'});
    });

    test('fromJson deserializes with converter', () {
      final value = SyncValue.fromJson({
        'v': 'world',
        'hlc': '20-1-m',
      }, (v) => v as String);
      expect(value.value, 'world');
      expect(value.hlc, const Hlc(20, 1, 'm'));
    });

    test('fromPrimitiveJson casts primitive types', () {
      final value = SyncValue<int>.fromPrimitiveJson({'v': 42, 'hlc': '5-0-x'});
      expect(value.value, 42);
      expect(value.hlc, const Hlc(5, 0, 'x'));
    });
  });
}
