import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum BluetoothPromptType {
  enableBluetooth,
  permission,
}

enum BluetoothPromptAction {
  primaryAction,
  openSettings,
  dismiss,
}

class BluetoothPromptSheet extends StatefulWidget {
  const BluetoothPromptSheet({
    super.key,
    this.type = BluetoothPromptType.enableBluetooth,
    this.canRequestPermission = true,
  });

  final BluetoothPromptType type;
  final bool canRequestPermission;

  /// Tampilkan modal prompt Bluetooth (bottom sheet di mobile, dialog di tablet/layar lebar)
  static Future<BluetoothPromptAction?> show(
    BuildContext context, {
    BluetoothPromptType type = BluetoothPromptType.enableBluetooth,
    bool canRequestPermission = true,
  }) {
    HapticFeedback.mediumImpact();
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    if (isWide) {
      return showDialog<BluetoothPromptAction>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Material(
                color: Theme.of(context).cardColor,
                child: BluetoothPromptSheet(
                  type: type,
                  canRequestPermission: canRequestPermission,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet<BluetoothPromptAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Material(
          color: Theme.of(context).cardColor,
          child: SafeArea(
            top: false,
            child: BluetoothPromptSheet(
              type: type,
              canRequestPermission: canRequestPermission,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<BluetoothPromptSheet> createState() => _BluetoothPromptSheetState();
}

class _BluetoothPromptSheetState extends State<BluetoothPromptSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _pulseScale = Tween<double>(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOutCubic,
      ),
    );

    _pulseOpacity = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEnableType = widget.type == BluetoothPromptType.enableBluetooth;

    final title = isEnableType
        ? 'Aktifkan Bluetooth Anda'
        : 'Izin Bluetooth Dibutuhkan';

    final subtitle = isEnableType
        ? 'Aplikasi membutuhkan Bluetooth yang aktif agar dapat menemukan dan mencetak struk langsung ke printer kasir.'
        : 'Berikan izin Nearby devices/Bluetooth agar aplikasi dapat memindai printer termal kasir di sekitar Anda.';

    final primaryLabel = isEnableType
        ? 'Nyalakan Bluetooth Sekarang'
        : (widget.canRequestPermission ? 'Izinkan Akses Bluetooth' : 'Buka Pengaturan HP');

    final primaryIcon = isEnableType
        ? Icons.bluetooth_searching_rounded
        : Icons.security_rounded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag Handle
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 24),

          // Pulsing Glow Avatar / Badge
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse waves
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseScale.value,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2563EB).withValues(
                            alpha: _pulseOpacity.value,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Soft background ring
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFDBEAFE).withValues(alpha: 0.8),
                  ),
                ),
                // Center gradient circle
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2563EB),
                        Color(0xFF1D4ED8),
                        Color(0xFF1E40AF),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.bluetooth_audio_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
                // Small status dot
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.cardColor,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),

          const SizedBox(height: 20),

          // Highlight info cards
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                _buildBenefitRow(
                  context,
                  icon: Icons.print_rounded,
                  iconColor: const Color(0xFF2563EB),
                  iconBg: const Color(0xFFEFF6FF),
                  title: 'Deteksi Printer Otomatis',
                  desc: 'Mencari dan mengenali printer thermal kasir di sekitar',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, thickness: 0.6),
                ),
                _buildBenefitRow(
                  context,
                  icon: Icons.bolt_rounded,
                  iconColor: const Color(0xFF059669),
                  iconBg: const Color(0xFFECFDF5),
                  title: 'Cetak Cepat Tanpa Kabel',
                  desc: 'Struk belanja langsung tercetak seketika saat bayar',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Primary CTA Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop(BluetoothPromptAction.primaryAction);
              },
              icon: Icon(primaryIcon, size: 20),
              label: Text(
                primaryLabel,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Secondary Action (Open Settings)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop(BluetoothPromptAction.openSettings);
              },
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: Text(
                'Buka Pengaturan HP',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.onSurface,
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Dismiss text button
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(BluetoothPromptAction.dismiss);
            },
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: Text(
              'Nanti Saja',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String desc,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
