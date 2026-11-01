import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/domain/business_template_models.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/features/subscription/presentation/providers/business_template_provider.dart';
import 'package:dpos/core/routes/routes_name.dart';
import 'package:go_router/go_router.dart';

class BusinessTemplateManagementScreen extends ConsumerWidget {
  const BusinessTemplateManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(businessTypeTemplatesProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isTablet
          ? AppTabletHeader(
              title: const Text('Kelola Template Bisnis'),
              badge: const AppTabletBadge(label: 'Syupeo'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Tambah Template'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => context.pushNamed(RouteNames.businessTemplateEdit),
                  ),
                ),
              ],
            )
          : AppBar(
              title: const Text('Kelola Template Bisnis'),
              centerTitle: false,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton.filledTonal(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () => context.pushNamed(RouteNames.businessTemplateEdit),
                  ),
                ),
              ],
            ),
      body: templatesAsync.when(
        data: (templates) => templates.isEmpty
            ? _buildEmptyState(context)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: templates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return _buildTemplateItem(context, ref, template);
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_center_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('Belum ada template', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.pushNamed(RouteNames.businessTemplateEdit),
            child: const Text('Buat Template Pertama'),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateItem(BuildContext context, WidgetRef ref, BusinessTypeTemplate template) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(_getIconData(template.iconName), color: scheme.primary),
        ),
        title: Text(template.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${template.code} • ${template.defaultEnabledFeatures.length} Fitur Aktif',
              style: TextStyle(fontSize: 12, color: scheme.onSurface.withOpacity(0.6)),
            ),
            if (template.description != null && template.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                template.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: scheme.onSurface.withOpacity(0.4)),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => context.pushNamed(RouteNames.businessTemplateEdit, extra: template),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
              onPressed: () => _confirmDelete(context, ref, template),
            ),
          ],
        ),
        onTap: () => context.pushNamed(RouteNames.businessTemplateEdit, extra: template),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, BusinessTypeTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Template?'),
        content: Text('Yakin ingin menghapus "${template.name}"? Bisnis yang sudah menggunakan template ini tidak akan terpengaruh secara otomatis.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await ref.read(authRepositoryProvider).deleteBusinessTypeTemplate(template.id);
              if (context.mounted) Navigator.pop(context);
              ref.invalidate(businessTypeTemplatesProvider);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'restaurant_rounded': return Icons.restaurant_rounded;
      case 'shopping_bag_rounded': return Icons.shopping_bag_rounded;
      case 'handyman_rounded': return Icons.handyman_rounded;
      case 'apps_rounded': return Icons.apps_rounded;
      case 'motorcycle_rounded': return Icons.motorcycle_rounded;
      case 'local_laundry_service_rounded': return Icons.local_laundry_service_rounded;
      default: return Icons.business_center_rounded;
    }
  }
}
