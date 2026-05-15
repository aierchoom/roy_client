import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/vault_health_report.dart';

void main() {
  group('VaultHealthReport', () {
    test('constructs with required fields', () {
      final now = DateTime.now();
      final report = VaultHealthReport(
        score: 85,
        grade: VaultHealthGrade.good,
        items: const [],
        calculatedAt: now,
      );
      expect(report.score, 85);
      expect(report.grade, VaultHealthGrade.good);
      expect(report.items, isEmpty);
      expect(report.calculatedAt, now);
    });

    test('failedItems filters non-passing items', () {
      final report = VaultHealthReport(
        score: 70,
        grade: VaultHealthGrade.warning,
        items: [
          const VaultHealthItem(
            id: 'pass',
            title: 'Passing',
            riskLevel: VaultHealthRiskLevel.low,
            isPass: true,
            description: 'All good',
          ),
          const VaultHealthItem(
            id: 'fail',
            title: 'Failing',
            riskLevel: VaultHealthRiskLevel.high,
            isPass: false,
            description: 'Problem found',
          ),
        ],
        calculatedAt: DateTime.now(),
      );
      expect(report.items.length, 2);
      final failed = report.items.where((i) => !i.isPass).toList();
      expect(failed.length, 1);
      expect(failed.first.id, 'fail');
    });

    test('VaultHealthAction carries target ids', () {
      const action = VaultHealthAction(
        type: VaultHealthActionType.navigateToAccountEdit,
        targetIds: ['acc_1', 'acc_2'],
      );
      expect(action.type, VaultHealthActionType.navigateToAccountEdit);
      expect(action.targetIds, ['acc_1', 'acc_2']);
      expect(action.targetId, null);
    });
  });
}
