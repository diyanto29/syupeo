import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dpos/core/services/offline_sync_service.dart';

class OfflineSyncBanner extends ConsumerStatefulWidget {
  const OfflineSyncBanner({super.key});

  @override
  ConsumerState<OfflineSyncBanner> createState() => _OfflineSyncBannerState();
}

class _OfflineSyncBannerState extends ConsumerState<OfflineSyncBanner> {
  bool _isSyncing = false;

  void _showFeedback({
    required String title,
    required String message,
    required Color backgroundColor,
    required IconData icon,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 6,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        fontSize: 11.5,
                      ),
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

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    _showFeedback(
      title: 'Memeriksa & Menyinkronkan...',
      message: 'Menghubungkan ke server dan mengunggah data offline...',
      backgroundColor: const Color(0xFF2563EB),
      icon: Icons.sync_rounded,
    );

    try {
      final result = await OfflineSyncService.instance.syncPendingOrders(ref);
      if (!mounted) return;

      final pendingCount = ref.read(pendingSyncCountProvider);

      switch (result.status) {
        case SyncStatus.offline:
          _showFeedback(
            title: 'Perangkat Masih Offline',
            message: result.errorMessage ??
                'Tidak ada koneksi internet. $pendingCount transaksi tersimpan aman di HP & kasir tetap bisa bertransaksi.',
            backgroundColor: const Color(0xFFD97706),
            icon: Icons.wifi_off_rounded,
          );
          break;

        case SyncStatus.success:
          _showFeedback(
            title: 'Sinkronisasi Berhasil!',
            message: '${result.syncedCount} transaksi offline berhasil diunggah ke cloud Supabase.',
            backgroundColor: const Color(0xFF16A34A),
            icon: Icons.check_circle_rounded,
          );
          break;

        case SyncStatus.noPending:
          _showFeedback(
            title: 'Sudah Tersinkronkan',
            message: 'Semua transaksi offline telah tersimpan di cloud Supabase.',
            backgroundColor: const Color(0xFF2563EB),
            icon: Icons.cloud_done_rounded,
          );
          break;

        case SyncStatus.partialSuccess:
          _showFeedback(
            title: 'Sinkronisasi Sebagian',
            message:
                '${result.syncedCount} transaksi berhasil diunggah, ${result.failedCount} tertunda (${result.errorMessage ?? 'Coba lagi'}).',
            backgroundColor: const Color(0xFFD97706),
            icon: Icons.warning_amber_rounded,
          );
          break;

        case SyncStatus.failed:
          _showFeedback(
            title: 'Sinkronisasi Gagal',
            message:
                '${result.errorMessage ?? 'Gagal mengunggah data'}. Silakan periksa koneksi internet Anda.',
            backgroundColor: const Color(0xFFDC2626),
            icon: Icons.error_outline_rounded,
          );
          break;
      }
    } catch (e) {
      if (!mounted) return;
      _showFeedback(
        title: 'Gagal Menyinkronkan',
        message: OfflineSyncService.humanizeError(e),
        backgroundColor: const Color(0xFFDC2626),
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnlineAsync = ref.watch(isOnlineProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);

    final isOnline = isOnlineAsync.value ?? true;

    // Sembunyikan banner jika online dan tidak ada transaksi tertunda
    if (isOnline && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    if (!isOnline) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7), // Amber 100
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)), // Amber 500
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mode Offline Aktif',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                  Text(
                    pendingCount > 0
                        ? '$pendingCount transaksi tersimpan di memori HP. Kasir tetap bisa transaksi lancar!'
                        : 'Kasir tetap bisa catat transaksi & cetak struk tanpa internet.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _handleSync,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync_rounded, size: 14),
              label: Text(
                _isSyncing ? 'Cek...' : 'Cek & Sync',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD97706).withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                minimumSize: const Size(60, 32),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              ),
            ),
          ],
        ),
      );
    }

    // Jika online tapi ada transaksi offline yang belum tersinkron
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Blue 50
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)), // Blue 500
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Internet Terhubung',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E40AF),
                  ),
                ),
                Text(
                  'Ada $pendingCount transaksi offline yang siap diunggah ke cloud.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isSyncing ? null : _handleSync,
            icon: _isSyncing
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync_rounded, size: 14),
            label: Text(
              _isSyncing ? 'Syncing...' : 'Sync',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(60, 32),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
            ),
          ),
        ],
      ),
    );
  }
}
