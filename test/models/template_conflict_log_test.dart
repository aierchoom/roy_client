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
  });
}
