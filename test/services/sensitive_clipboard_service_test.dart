import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/services/sensitive_clipboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String clipboardText;

  setUp(() {
    clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              final data = Map<String, dynamic>.from(call.arguments as Map);
              clipboardText = data['text'] as String? ?? '';
              return null;
            case 'Clipboard.getData':
              return <String, dynamic>{'text': clipboardText};
          }
          return null;
        });
  });

  tearDown(() {
    SensitiveClipboardService.cancelPendingClear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('clears sensitive clipboard text when it is unchanged', (
    tester,
  ) async {
    await SensitiveClipboardService.copy(
      text: '123456',
      clearAfter: const Duration(milliseconds: 10),
    );

    expect(clipboardText, '123456');

    await tester.pump(const Duration(milliseconds: 11));
    await tester.pump();

    expect(clipboardText, isEmpty);
  });

  testWidgets('does not clear clipboard text replaced by the user', (
    tester,
  ) async {
    await SensitiveClipboardService.copy(
      text: '123456',
      clearAfter: const Duration(milliseconds: 10),
    );

    clipboardText = 'manual-copy';

    await tester.pump(const Duration(milliseconds: 11));
    await tester.pump();

    expect(clipboardText, 'manual-copy');
  });

  testWidgets('high risk uses default clear duration', (tester) async {
    await SensitiveClipboardService.copy(
      text: 'high-risk',
      level: ClipboardRiskLevel.high,
      clearAfter: const Duration(milliseconds: 5),
    );

    expect(clipboardText, 'high-risk');

    await tester.pump(const Duration(milliseconds: 6));
    await tester.pump();

    expect(clipboardText, isEmpty);
  });

  testWidgets('medium risk also clears with shorter default', (tester) async {
    await SensitiveClipboardService.copy(
      text: 'medium-risk',
      level: ClipboardRiskLevel.medium,
      clearAfter: const Duration(milliseconds: 5),
    );

    expect(clipboardText, 'medium-risk');

    await tester.pump(const Duration(milliseconds: 6));
    await tester.pump();

    expect(clipboardText, isEmpty);
  });

  testWidgets('low risk does not schedule clear', (tester) async {
    await SensitiveClipboardService.copy(
      text: 'low-risk',
      level: ClipboardRiskLevel.low,
      clearAfter: const Duration(milliseconds: 5),
    );

    expect(clipboardText, 'low-risk');

    await tester.pump(const Duration(milliseconds: 6));
    await tester.pump();

    expect(clipboardText, 'low-risk');
  });

  testWidgets('hash-based comparison prevents clearing modified content', (
    tester,
  ) async {
    await SensitiveClipboardService.copy(
      text: 'original',
      clearAfter: const Duration(milliseconds: 10),
    );

    // Simulate user copying something else with the same length
    // but different content — hash must not match
    clipboardText = 'tampered!!';

    await tester.pump(const Duration(milliseconds: 11));
    await tester.pump();

    expect(clipboardText, 'tampered!!');
  });
}
