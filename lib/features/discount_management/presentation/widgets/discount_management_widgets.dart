import 'package:dpos/core/utils/rupiah_input_helper.dart';
import 'package:dpos/features/discount_management/domain/discount_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DiscountFilter {
  all('Semua'),
  active('Aktif'),
  scheduled('Terjadwal'),
  inactive('Nonaktif');

  const DiscountFilter(this.label);

  final String label;
}

bool _isMobileLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600;

class DiscountSearchField extends StatelessWidget {
  const DiscountSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Cari nama discount, kode, atau deskripsi',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            );
          },
        ),
      ),
    );
  }
}

class DiscountFilterChips extends StatelessWidget {
  const DiscountFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onSelected,
  });

  final DiscountFilter selectedFilter;
  final ValueChanged<DiscountFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: DiscountFilter.values.map((filter) {
          final selected = filter == selectedFilter;
          return Padding(
            padding: EdgeInsets.only(
              right: filter == DiscountFilter.values.last ? 0 : 8,
            ),
            child: ChoiceChip(
              label: Text(filter.label),
              selected: selected,
              onSelected: (_) => onSelected(filter),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class DiscountListSection extends StatelessWidget {
  const DiscountListSection({
    super.key,
    required this.discountsAsync,
    required this.discounts,
    required this.filteredDiscounts,
    required this.canManage,
    required this.hasSearch,
    required this.onRefresh,
    this.onAddDiscount,
    this.onEditDiscount,
    this.onDeleteDiscount,
  });

  final AsyncValue<List<DiscountDefinition>> discountsAsync;
  final List<DiscountDefinition> discounts;
  final List<DiscountDefinition> filteredDiscounts;
  final bool canManage;
  final bool hasSearch;
  final Future<void> Function() onRefresh;
  final VoidCallback? onAddDiscount;
  final Future<void> Function(DiscountDefinition discount)? onEditDiscount;
  final Future<void> Function(DiscountDefinition discount)? onDeleteDiscount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return discountsAsync.when(
      data: (_) {
        if (filteredDiscounts.isEmpty) {
          return EmptyDiscountState(
            hasSearch: hasSearch,
            hasAnyData: discounts.isNotEmpty,
            canManage: canManage,
            onAddDiscount: onAddDiscount,
          );
        }

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filteredDiscounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final discount = filteredDiscounts[index];
              return _DiscountCard(
                discount: discount,
                canManage: canManage,
                onTap: canManage && onEditDiscount != null
                    ? () => onEditDiscount!(discount)
                    : null,
                onEdit: canManage && onEditDiscount != null
                    ? () => onEditDiscount!(discount)
                    : null,
                onDelete: canManage && onDeleteDiscount != null
                    ? () => onDeleteDiscount!(discount)
                    : null,
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_tethering_error_rounded,
                size: 42,
                color: scheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                'Gagal memuat discount',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.66),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiscountHeaderCard extends StatelessWidget {
  const DiscountHeaderCard({super.key, required this.discounts});

  final List<DiscountDefinition> discounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = _isMobileLayout(context);
    final activeCount = discounts
        .where((discount) => discount.isAvailableNow)
        .length;
    final percentageCount = discounts
        .where((discount) => discount.type == DiscountType.percentage)
        .length;
    final fixedCount = discounts
        .where((discount) => discount.type == DiscountType.fixedAmount)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1800), Color(0xFF6B3C00), Color(0xFFBC6C25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'MASTER DISCOUNT',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Kelola metadata discount untuk dipakai fleksibel di item, cart, atau total transaksi.',
            style:
                (isMobile
                        ? theme.textTheme.bodySmall
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                      height: 1.45,
                    ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeaderStatPill(label: 'TOTAL', value: '${discounts.length}'),
              _HeaderStatPill(label: 'AKTIF', value: '$activeCount'),
              _HeaderStatPill(label: '%', value: '$percentageCount'),
              _HeaderStatPill(label: 'RUPIAH', value: '$fixedCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStatPill extends StatelessWidget {
  const _HeaderStatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = _isMobileLayout(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
              fontWeight: FontWeight.w700,
              fontSize: isMobile ? 11 : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: isMobile ? 15 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscountCard extends StatelessWidget {
  const _DiscountCard({
    required this.discount,
    required this.canManage,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final DiscountDefinition discount;
  final bool canManage;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMobile = _isMobileLayout(context);
    final status = _discountStatus(discount);
    final statusColor = switch (status) {
      _DiscountStatus.activeNow => const Color(0xFF1E8E5A),
      _DiscountStatus.scheduled => const Color(0xFF1A73E8),
      _DiscountStatus.expired => const Color(0xFFB3261E),
      _DiscountStatus.inactive => const Color(0xFF6B7280),
    };

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      discount.type == DiscountType.percentage
                          ? Icons.percent_rounded
                          : Icons.payments_outlined,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          discount.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: isMobile ? 16 : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _CardChip(
                              label: _discountValueLabel(discount),
                              color: const Color(0xFFEFF6FF),
                              textColor: const Color(0xFF1D4ED8),
                            ),
                            _CardChip(
                              label: _discountStatusLabel(status),
                              color: statusColor.withValues(alpha: 0.12),
                              textColor: statusColor,
                            ),
                            if ((discount.code ?? '').isNotEmpty)
                              _CardChip(
                                label: discount.code!,
                                color: scheme.secondaryContainer,
                                textColor: scheme.onSecondaryContainer,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (canManage)
                    PopupMenuButton<_DiscountCardAction>(
                      onSelected: (action) {
                        switch (action) {
                          case _DiscountCardAction.edit:
                            onEdit?.call();
                          case _DiscountCardAction.delete:
                            onDelete?.call();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _DiscountCardAction.edit,
                          child: Text('Edit'),
                        ),
                        PopupMenuItem(
                          value: _DiscountCardAction.delete,
                          child: Text('Hapus'),
                        ),
                      ],
                    ),
                ],
              ),
              if ((discount.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  discount.description!,
                  style:
                      (isMobile
                              ? theme.textTheme.bodySmall
                              : theme.textTheme.bodyMedium)
                          ?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.68),
                            height: 1.45,
                          ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetaPill(
                    icon: Icons.sell_outlined,
                    label: discount.type.label,
                  ),
                  if (discount.usesMaxDiscount)
                    _MetaPill(
                      icon: Icons.shield_outlined,
                      label:
                          'Maks ${RupiahInputHelper.formatWithPrefix(discount.maxDiscountAmount!)}',
                    ),
                  if (discount.hasSchedule)
                    _MetaPill(
                      icon: Icons.event_outlined,
                      label: _scheduleLabel(context, discount),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DiscountCardAction { edit, delete }

class _CardChip extends StatelessWidget {
  const _CardChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobileLayout(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: isMobile ? 11 : null,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMobile = _isMobileLayout(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: isMobile ? 12 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyDiscountState extends StatelessWidget {
  const EmptyDiscountState({
    super.key,
    required this.hasSearch,
    required this.hasAnyData,
    required this.canManage,
    this.onAddDiscount,
  });

  final bool hasSearch;
  final bool hasAnyData;
  final bool canManage;
  final VoidCallback? onAddDiscount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMobile = _isMobileLayout(context);

    final title = hasSearch
        ? 'Discount tidak ditemukan'
        : hasAnyData
        ? 'Tidak ada discount pada filter ini'
        : 'Belum ada discount';
    final detail = hasSearch
        ? 'Coba ubah kata kunci atau ganti filter untuk melihat discount lain.'
        : hasAnyData
        ? 'Beberapa discount ada, tapi tidak cocok dengan filter yang sedang aktif.'
        : 'Mulai dari discount percentage dengan batas maksimal rupiah, atau potongan rupiah langsung.';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_offer_outlined,
                size: 34,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: isMobile ? 20 : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style:
                  (isMobile
                          ? theme.textTheme.bodySmall
                          : theme.textTheme.bodyMedium)
                      ?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.66),
                        height: 1.45,
                      ),
            ),
            if (!hasSearch &&
                !hasAnyData &&
                canManage &&
                onAddDiscount != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAddDiscount,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah Discount'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _DiscountStatus { activeNow, scheduled, expired, inactive }

_DiscountStatus _discountStatus(DiscountDefinition discount) {
  if (!discount.isActive) {
    return _DiscountStatus.inactive;
  }
  if (discount.isUpcoming) {
    return _DiscountStatus.scheduled;
  }
  if (discount.isExpired) {
    return _DiscountStatus.expired;
  }
  return _DiscountStatus.activeNow;
}

String _discountStatusLabel(_DiscountStatus status) {
  switch (status) {
    case _DiscountStatus.activeNow:
      return 'Aktif';
    case _DiscountStatus.scheduled:
      return 'Terjadwal';
    case _DiscountStatus.expired:
      return 'Kedaluwarsa';
    case _DiscountStatus.inactive:
      return 'Nonaktif';
  }
}

String _discountValueLabel(DiscountDefinition discount) {
  switch (discount.type) {
    case DiscountType.percentage:
      return '${discount.configuredValue.toStringAsFixed(discount.configuredValue == discount.configuredValue.roundToDouble() ? 0 : 2)}%';
    case DiscountType.fixedAmount:
      return RupiahInputHelper.formatWithPrefix(discount.configuredValue);
  }
}

String _scheduleLabel(BuildContext context, DiscountDefinition discount) {
  final localizations = MaterialLocalizations.of(context);
  final start = discount.startsAt == null
      ? 'Sekarang'
      : localizations.formatShortDate(discount.startsAt!);
  final end = discount.endsAt == null
      ? 'Tanpa batas'
      : localizations.formatShortDate(discount.endsAt!);
  return '$start - $end';
}
