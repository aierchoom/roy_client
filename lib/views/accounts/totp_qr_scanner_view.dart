import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/totp_import_service.dart';
import '../../theme/app_design_tokens.dart';

class TotpQrScannerView extends StatefulWidget {
  final String title;
  final String helpText;
  final String invalidMessage;
  final String torchTooltip;
  final String switchCameraTooltip;

  const TotpQrScannerView({
    super.key,
    required this.title,
    required this.helpText,
    required this.invalidMessage,
    required this.torchTooltip,
    required this.switchCameraTooltip,
  });

  @override
  State<TotpQrScannerView> createState() => _TotpQrScannerViewState();
}

class _TotpQrScannerViewState extends State<TotpQrScannerView> {
  late final MobileScannerController _controller;
  bool _handledResult = false;
  bool _showingInvalidHint = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_handledResult) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;

      try {
        TotpImportService.normalizeImportValue(raw);
        _handledResult = true;
        Navigator.of(context).pop(raw);
        return;
      } catch (_) {
        // Invalid QR code: user feedback is handled by _showInvalidHint.
        _showInvalidHint();
      }
    }
  }

  void _showInvalidHint() {
    if (_showingInvalidHint || !mounted) return;
    _showingInvalidHint = true;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(widget.invalidMessage)))
        .closed
        .whenComplete(() {
          if (mounted) {
            _showingInvalidHint = false;
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: widget.torchTooltip,
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on_outlined),
          ),
          IconButton(
            tooltip: widget.switchCameraTooltip,
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _handleDetect),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.black.withAlpha(36)),
              child: Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.panel),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(AppAlphas.surface),
                  borderRadius: BorderRadius.circular(AppRadii.panel),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Text(
                    widget.helpText,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
