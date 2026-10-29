import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class EmbeddedScanner extends StatefulWidget {
  const EmbeddedScanner({
    super.key,
    required this.controller,
    required this.onDetect,
    required this.onClose,
  });

  final MobileScannerController controller;
  final ValueChanged<String> onDetect;
  final VoidCallback onClose;

  @override
  State<EmbeddedScanner> createState() => _EmbeddedScannerState();
}

class _EmbeddedScannerState extends State<EmbeddedScanner> {
  bool _isClosing = false;

  void _handleClose() {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            MobileScanner(
              controller: widget.controller,
              onDetect: (capture) {
                if (_isClosing) return;
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String? raw = barcodes.first.rawValue;
                  if (raw != null) {
                    final trimmed = raw.trim();
                    if (trimmed.isNotEmpty) {
                      widget.onDetect(trimmed);
                    }
                  }
                }
              },
            ),
            // Scanning reticle overlay
            const Center(child: _ScanningReticle()),
            // Live scanning indicator
            const Positioned(
              top: 16,
              left: 16,
              child: _LiveIndicator(),
            ),
            // Bottom control overlay
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ScannerControlBtn(
                    icon: Icons.flash_on_rounded,
                    label: 'Flash',
                    onTap: () => widget.controller.toggleTorch(),
                  ),
                  _ScannerControlBtn(
                    icon: Icons.flip_camera_ios_rounded,
                    label: 'Kamera',
                    onTap: () => widget.controller.switchCamera(),
                  ),
                  _ScannerControlBtn(
                    icon: Icons.close_rounded,
                    label: 'Tutup',
                    onTap: _handleClose,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scanner Helper Widgets ─────────────────────────────────────

class _ScanningReticle extends StatefulWidget {
  const _ScanningReticle();

  @override
  State<_ScanningReticle> createState() => _ScanningReticleState();
}

class _ScanningReticleState extends State<_ScanningReticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 180,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Corner brackets
          // Top Left
          Positioned(
            top: -2,
            left: -2,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFF98B35), width: 4),
                  left: BorderSide(color: Color(0xFFF98B35), width: 4),
                ),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
              ),
            ),
          ),
          // Top Right
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFF98B35), width: 4),
                  right: BorderSide(color: Color(0xFFF98B35), width: 4),
                ),
                borderRadius: BorderRadius.only(topRight: Radius.circular(12)),
              ),
            ),
          ),
          // Bottom Left
          Positioned(
            bottom: -2,
            left: -2,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF98B35), width: 4),
                  left: BorderSide(color: Color(0xFFF98B35), width: 4),
                ),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12)),
              ),
            ),
          ),
          // Bottom Right
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF98B35), width: 4),
                  right: BorderSide(color: Color(0xFFF98B35), width: 4),
                ),
                borderRadius: BorderRadius.only(bottomRight: Radius.circular(12)),
              ),
            ),
          ),
          // Animated Scanning Line
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                top: 168 * _controller.value + 4,
                left: 8,
                right: 8,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF98B35),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF98B35).withValues(alpha: 0.8),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LiveIndicator extends StatefulWidget {
  const _LiveIndicator();

  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _controller.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            'LIVE SCANNING ACTIVE',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerControlBtn extends StatelessWidget {
  const _ScannerControlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
