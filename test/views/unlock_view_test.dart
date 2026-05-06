import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/views/unlock_view.dart';

void main() {
  group('UnlockView', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: UnlockView()),
      );
      // Should show loading or auth form
      expect(find.byType(UnlockView), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: UnlockView()),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
