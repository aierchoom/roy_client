import 'package:flutter/foundation.dart';

String defaultSyncServerUrlForCurrentPlatform() {
  if (kIsWeb) return '';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return '';
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return 'http://127.0.0.1:8080';
    case TargetPlatform.fuchsia:
      return '';
  }
}
