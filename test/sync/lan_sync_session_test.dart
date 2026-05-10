import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/sync/lan_sync_session.dart';

void main() {
  group('LanSyncPhase', () {
    test('isActive returns true for active phases', () {
      expect(LanSyncPhase.connecting.isActive, isTrue);
      expect(LanSyncPhase.receiving.isActive, isTrue);
      expect(LanSyncPhase.merging.isActive, isTrue);
      expect(LanSyncPhase.resolving.isActive, isTrue);
      expect(LanSyncPhase.pushing.isActive, isTrue);
      expect(LanSyncPhase.committing.isActive, isTrue);
    });

    test('isActive returns false for terminal and idle phases', () {
      expect(LanSyncPhase.idle.isActive, isFalse);
      expect(LanSyncPhase.completed.isActive, isFalse);
      expect(LanSyncPhase.interrupted.isActive, isFalse);
      expect(LanSyncPhase.failed.isActive, isFalse);
    });

    test('isTerminal returns true for terminal phases', () {
      expect(LanSyncPhase.completed.isTerminal, isTrue);
      expect(LanSyncPhase.interrupted.isTerminal, isTrue);
      expect(LanSyncPhase.failed.isTerminal, isTrue);
    });

    test('isTerminal returns false for non-terminal phases', () {
      expect(LanSyncPhase.idle.isTerminal, isFalse);
      expect(LanSyncPhase.connecting.isTerminal, isFalse);
      expect(LanSyncPhase.receiving.isTerminal, isFalse);
      expect(LanSyncPhase.merging.isTerminal, isFalse);
      expect(LanSyncPhase.resolving.isTerminal, isFalse);
      expect(LanSyncPhase.pushing.isTerminal, isFalse);
      expect(LanSyncPhase.committing.isTerminal, isFalse);
    });
  });

  group('LanSyncSessionState', () {
    test('copyWith updates only specified fields', () {
      final original = LanSyncSessionState(
        sessionId: 'test_session',
        phase: LanSyncPhase.connecting,
        startedAt: DateTime(2024, 1, 1),
        expiresAt: DateTime(2024, 1, 2),
      );

      final updated = original.copyWith(phase: LanSyncPhase.merging);

      expect(updated.sessionId, 'test_session');
      expect(updated.phase, LanSyncPhase.merging);
      expect(updated.startedAt, DateTime(2024, 1, 1));
      expect(updated.expiresAt, DateTime(2024, 1, 2));
    });

    test('copyWith preserves all fields when no overrides', () {
      final original = LanSyncSessionState(
        sessionId: 'test_session',
        phase: LanSyncPhase.pushing,
        startedAt: DateTime(2024, 6, 15),
      );

      final copy = original.copyWith();

      expect(copy.sessionId, original.sessionId);
      expect(copy.phase, original.phase);
      expect(copy.startedAt, original.startedAt);
      expect(copy.expiresAt, original.expiresAt);
    });
  });

  group('LanSyncConfig', () {
    test('has default values', () {
      const config = LanSyncConfig();
      expect(config.sessionTtl, const Duration(minutes: 3));
      expect(config.pageSize, 100);
    });

    test('accepts custom values', () {
      const config = LanSyncConfig(
        sessionTtl: Duration(minutes: 5),
        pageSize: 50,
      );
      expect(config.sessionTtl, const Duration(minutes: 5));
      expect(config.pageSize, 50);
    });
  });

  group('LanSyncResult', () {
    test('success result has default counts', () {
      final result = LanSyncResult(success: true);
      expect(result.pushedItems, 0);
      expect(result.pulledItems, 0);
      expect(result.conflictCount, 0);
      expect(result.error, isNull);
    });

    test('failure result carries error message', () {
      final result = LanSyncResult(
        success: false,
        error: 'Connection failed',
      );
      expect(result.success, isFalse);
      expect(result.error, 'Connection failed');
    });
  });

  group('LanSyncException', () {
    test('toString includes code and message', () {
      const ex = LanSyncException('TEST_CODE', 'test message');
      expect(ex.toString(), 'LanSyncException(TEST_CODE: test message)');
    });

    test('predefined constants have correct codes', () {
      expect(kLanSyncTimeout.code, 'TIMEOUT');
      expect(kLanSyncSessionExpired.code, 'SESSION_EXPIRED');
      expect(kLanSyncDataCorrupted.code, 'DATA_CORRUPTED');
      expect(kLanSyncHostBusy.code, 'HOST_BUSY');
      expect(kLanSyncChannelConflict.code, 'CHANNEL_CONFLICT');
    });
  });

  group('generateLanSyncSessionId', () {
    test('generates unique IDs', () {
      final id1 = generateLanSyncSessionId();
      final id2 = generateLanSyncSessionId();
      expect(id1, isNot(equals(id2)));
    });

    test('generates IDs with lan_ prefix', () {
      final id = generateLanSyncSessionId();
      expect(id.startsWith('lan_'), isTrue);
    });
  });
}
