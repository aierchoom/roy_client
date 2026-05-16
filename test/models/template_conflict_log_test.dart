import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/template_conflict_log.dart';

void main() {
  group('TemplateConflictLog', () {
    final localHlc = Hlc.now('dev1');
    final remoteHlc = Hlc.now('dev2');

    test('constructs with defaults', () {
      final log = TemplateConflictLog(
        templateId: 't1',
        fieldKey: 'f1',
        attributeName: 'label',
        localValue: 'local',
        remoteValue: 'remote',
        localHlc: localHlc,
        remoteHlc: remoteHlc,
      );
      expect(log.templateId, 't1');
      expect(log.fieldKey, 'f1');
      expect(log.attributeName, 'label');
      expect(log.localValue, 'local');
      expect(log.remoteValue, 'remote');
      expect(log.id, isNotEmpty);
      expect(log.savedAt, greaterThan(0));
    });

    test('fromJson/toJson roundtrip', () {
      final original = TemplateConflictLog(
        id: 'log-1',
        templateId: 't2',
        fieldKey: 'f2',
        attributeName: 'type',
        localValue: 'text',
        remoteValue: 'password',
        localHlc: localHlc,
        remoteHlc: remoteHlc,
        savedAt: 1234567890,
      );
      final json = original.toJson();
      final restored = TemplateConflictLog.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.templateId, original.templateId);
      expect(restored.fieldKey, original.fieldKey);
      expect(restored.attributeName, original.attributeName);
      expect(restored.localValue, original.localValue);
      expect(restored.remoteValue, original.remoteValue);
      expect(restored.localHlc.toString(), original.localHlc.toString());
      expect(restored.remoteHlc.toString(), original.remoteHlc.toString());
      expect(restored.savedAt, original.savedAt);
    });

    test('generates unique ids', () {
      final log1 = TemplateConflictLog(
        templateId: 't',
        fieldKey: 'f',
        attributeName: 'a',
        localValue: 'l',
        remoteValue: 'r',
        localHlc: localHlc,
        remoteHlc: remoteHlc,
      );
      final log2 = TemplateConflictLog(
        templateId: 't',
        fieldKey: 'f',
        attributeName: 'a',
        localValue: 'l',
        remoteValue: 'r',
        localHlc: localHlc,
        remoteHlc: remoteHlc,
      );
      expect(log1.id, isNot(log2.id));
    });

    test('fromJson tolerates missing fields', () {
      final restored = TemplateConflictLog.fromJson({});
      expect(restored.id, isNotEmpty);
      expect(restored.templateId, '');
      expect(restored.fieldKey, '');
      expect(restored.attributeName, '');
      expect(restored.localValue, '');
      expect(restored.remoteValue, '');
      expect(restored.localHlc, Hlc.zero('local'));
      expect(restored.remoteHlc, Hlc.zero('local'));
      expect(restored.savedAt, greaterThan(0));
    });

    test('fromJson tolerates wrong types', () {
      final restored = TemplateConflictLog.fromJson({
        'id': 123,
        'templateId': 456,
        'fieldKey': true,
        'attributeName': null,
        'localValue': [],
        'remoteValue': {},
        'localHlc': 123,
        'remoteHlc': 456,
        'savedAt': 'not-an-int',
      });
      expect(restored.id, isNotEmpty);
      expect(restored.templateId, '');
      expect(restored.fieldKey, '');
      expect(restored.attributeName, '');
      expect(restored.localValue, '');
      expect(restored.remoteValue, '');
      expect(restored.localHlc, Hlc.zero('local'));
      expect(restored.remoteHlc, Hlc.zero('local'));
      expect(restored.savedAt, greaterThan(0));
    });

    test('copyWith returns same values when no args provided', () {
      final original = TemplateConflictLog(
        id: 'log-1',
        templateId: 't1',
        fieldKey: 'f1',
        attributeName: 'label',
        localValue: 'local',
        remoteValue: 'remote',
        localHlc: localHlc,
        remoteHlc: remoteHlc,
        savedAt: 1234567890,
      );
      final copied = original.copyWith();
      expect(copied.id, original.id);
      expect(copied.templateId, original.templateId);
      expect(copied.fieldKey, original.fieldKey);
      expect(copied.attributeName, original.attributeName);
      expect(copied.localValue, original.localValue);
      expect(copied.remoteValue, original.remoteValue);
      expect(copied.localHlc.toString(), original.localHlc.toString());
      expect(copied.remoteHlc.toString(), original.remoteHlc.toString());
      expect(copied.savedAt, original.savedAt);
    });

    test('copyWith overrides specified fields', () {
      final original = TemplateConflictLog(
        id: 'log-1',
        templateId: 't1',
        fieldKey: 'f1',
        attributeName: 'label',
        localValue: 'local',
        remoteValue: 'remote',
        localHlc: localHlc,
        remoteHlc: remoteHlc,
        savedAt: 1234567890,
      );
      final newLocalHlc = Hlc.now('dev3');
      final newRemoteHlc = Hlc.now('dev4');
      final copied = original.copyWith(
        id: 'log-2',
        templateId: 't2',
        fieldKey: 'f2',
        attributeName: 'type',
        localValue: 'new-local',
        remoteValue: 'new-remote',
        localHlc: newLocalHlc,
        remoteHlc: newRemoteHlc,
        savedAt: 9876543210,
      );
      expect(copied.id, 'log-2');
      expect(copied.templateId, 't2');
      expect(copied.fieldKey, 'f2');
      expect(copied.attributeName, 'type');
      expect(copied.localValue, 'new-local');
      expect(copied.remoteValue, 'new-remote');
      expect(copied.localHlc.toString(), newLocalHlc.toString());
      expect(copied.remoteHlc.toString(), newRemoteHlc.toString());
      expect(copied.savedAt, 9876543210);
    });

    test('copyWith preserves unmodified fields', () {
      final original = TemplateConflictLog(
        id: 'log-1',
        templateId: 't1',
        fieldKey: 'f1',
        attributeName: 'label',
        localValue: 'local',
        remoteValue: 'remote',
        localHlc: localHlc,
        remoteHlc: remoteHlc,
        savedAt: 1234567890,
      );
      final copied = original.copyWith(localValue: 'updated');
      expect(copied.id, original.id);
      expect(copied.templateId, original.templateId);
      expect(copied.fieldKey, original.fieldKey);
      expect(copied.attributeName, original.attributeName);
      expect(copied.localValue, 'updated');
      expect(copied.remoteValue, original.remoteValue);
      expect(copied.localHlc.toString(), original.localHlc.toString());
      expect(copied.remoteHlc.toString(), original.remoteHlc.toString());
      expect(copied.savedAt, original.savedAt);
    });
  });
}
