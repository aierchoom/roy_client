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
      '123456',
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
      '123456',
      clearAfter: const Duration(milliseconds: 10),
    );

    clipboardText = 'manual-copy';

    await tester.pump(const Duration(milliseconds: 11));
    await tester.pump();

    expect(clipboardText, 'manual-copy');
  });
}
