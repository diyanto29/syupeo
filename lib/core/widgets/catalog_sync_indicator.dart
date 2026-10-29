import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/services/product_catalog_sync_service.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';

class CatalogSyncIndicator extends ConsumerWidget {
  const CatalogSyncIndicator({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(productCatalogSyncProvider);
    final bootstrap = ref.watch(homeBootstrapProvider).valueOrNull;
    final businessId = bootstrap?.business?.id;
    final outletId = bootstrap?.outlets.firstOrNull?.id;

    if (businessId == null) return const SizedBox.shrink();

    // 1. Kondisi Sedang Sinkronisasi / Download Background
    if (syncState.isSyncing) {
      if (compact) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${syncState.progressPercent}% (${syncState.downloadedCount}/${syncState.totalCount})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBFDBFE)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    syncState.currentStep,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                ),
                Text(
                  '${syncState.progressPercent}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: syncState.progress,
                minHeight: 4,
                backgroundColor: const Color(0xFFDBEAFE),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Kondisi Database Siap / Selesai
    if (syncState.isCompleted && syncState.downloadedCount > 0) {
      return Container(
        margin: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF16A34A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Offline Siap (${syncState.downloadedCount} produk)',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF15803D),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () {
                ref.read(productCatalogSyncProvider.notifier).syncCatalog(
                      businessId,
                      outletId: outletId,
                      forceFull: true,
                    );
              },
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(2.0),
                child: Icon(
                  Icons.sync,
                  size: 13,
                  color: Color(0xFF16A34A),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 3. Kondisi Error
    if (syncState.isError) {
      return InkWell(
        onTap: () {
          ref.read(productCatalogSyncProvider.notifier).syncCatalog(
                businessId,
                outletId: outletId,
                forceFull: true,
              );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 13, color: Color(0xFFDC2626)),
              const SizedBox(width: 6),
              const Text(
                'Gagal sinkron • Ketuk untuk coba lagi',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB91C1C),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
