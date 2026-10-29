import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dpos/core/domain/business_template_models.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';

final businessTypeTemplatesProvider = FutureProvider<List<BusinessTypeTemplate>>((ref) {
  return ref.read(authRepositoryProvider).fetchBusinessTypeTemplates();
});
