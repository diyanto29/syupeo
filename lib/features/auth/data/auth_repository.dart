import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dpos/core/supabase/supabase_config.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import '../domain/auth_models.dart';
import 'package:dpos/core/domain/business_template_models.dart';

part 'auth_repository/auth_repository_auth.dart';
part 'auth_repository/auth_repository_bootstrap.dart';
part 'auth_repository/auth_repository_owner.dart';
part 'auth_repository/auth_repository_staff.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    client: SupabaseService.client,
    googleSignIn: GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: SupabaseConfig.googleWebClientId.isEmpty
          ? null
          : SupabaseConfig.googleWebClientId,
      clientId:
          defaultTargetPlatform == TargetPlatform.iOS &&
              SupabaseConfig.googleIosClientId.isNotEmpty
          ? SupabaseConfig.googleIosClientId
          : null,
    ),
  );
});

class AuthRepository {
  static const _bootstrapCachePrefix = 'owner_bootstrap_cache_v1_';
  static const _pendingBusinessUpdatePrefix = 'pending_business_update_v1_';
  static const _selectedOutletPrefix = 'selected_outlet_v1_';

  AuthRepository({
    required SupabaseClient client,
    required GoogleSignIn googleSignIn,
  }) : _client = client,
       _googleSignIn = googleSignIn;

  final SupabaseClient _client;
  final GoogleSignIn _googleSignIn;

  User get _currentUserOrThrow {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('User belum login.');
    }
    return user;
  }

  String get _currentUserIdOrThrow => _currentUserOrThrow.id;

  String _normalizedStaffIdentifier(String input) {
    return input.trim().toLowerCase();
  }

  String _staffSyntheticEmail(String identifier) {
    final normalized = _normalizedStaffIdentifier(
      identifier,
    ).replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return '$normalized@mudahkan.online';
  }

  String? _nullableText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String? _normalizeOutletCode(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final normalized = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), '')
        .replaceAll(RegExp(r'-+'), '-');

    return normalized.isEmpty ? null : normalized;
  }
}
