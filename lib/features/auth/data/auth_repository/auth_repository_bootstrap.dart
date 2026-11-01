part of '../auth_repository.dart';

extension AuthRepositoryBootstrapContext on AuthRepository {
  Future<OwnerBootstrap> loadBootstrap() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      return const OwnerBootstrap();
    }
    final userId = currentUser.id;
    final cached = await _readCachedBootstrap(userId);

    // 1. Cek offline lebih dulu: jika sedang offline dan ada cache, langsung return dalam 0ms tanpa timeout!
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none) && cached != null) {
      debugPrint('[offline-bootstrap] Offline mode: loaded cached bootstrap immediately in 0ms');
      return _applyPending(cached);
    }

    var pendingUpdate = await _readPendingBusinessUpdate(userId);
    if (pendingUpdate != null) {
      try {
        await _syncPendingBusinessUpdate(pendingUpdate);
        pendingUpdate = null;
      } catch (error) {
        if (!_isLikelyOfflineError(error)) {
          debugPrint('[offline-sync] pending sync failed: $error');
        }
      }
    }

    try {
      if (_client.auth.currentSession?.isExpired == true) {
        await SupabaseService.ensureFreshSession();
      }

      final timeoutDuration = cached != null
          ? const Duration(seconds: 5)
          : const Duration(seconds: 15);

      final onlineBootstrap = await SupabaseService.withAutoRefresh(
        () => () async {
          var profile = await fetchCurrentProfile();
        if (profile == null) {
          if (cached != null) {
            return cached;
          }
          // Fallback profile darurat agar status login tetap valid dan alur onboarding tidak tertolak GoRouter
          final fullName = currentUser.userMetadata?['full_name'] as String? ??
              currentUser.userMetadata?['name'] as String? ??
              currentUser.email?.split('@').first ??
              'User';
          profile = AppProfile(
            id: userId,
            email: currentUser.email,
            fullName: fullName,
            phone: currentUser.phone,
            avatarUrl: currentUser.userMetadata?['avatar_url'] as String?,
            defaultRole: AppRole.owner,
            isActive: true,
            onboardingCompleted: false,
          );
        }

        Business? business = await fetchOwnedBusiness();
        BusinessMember? membership;
        if (business != null) {
          membership = await fetchOwnerMembership(business.id);
        } else {
          membership = await fetchActiveMembership();
          if (membership != null) {
            business = await fetchBusinessById(membership.businessId);
          }
        }

        var outlets = business == null
            ? const <Outlet>[]
            : await fetchAccessibleOutlets(business.id);

        // AUTO-HEAL: Jika toko sudah ada tapi belum memiliki outlet di database,
        // buatkan outlet default 'main' secara otomatis agar kasir dan outlet langsung aktif
        if (business != null && outlets.isEmpty) {
          try {
            final autoOutlet = await ensureDefaultOutlet(business);
            if (autoOutlet != null) {
              outlets = [autoOutlet];
            }
          } catch (e) {
            debugPrint('[loadBootstrap] Auto-heal default outlet note: $e');
          }
        }

        final currentOutletId = await _resolveSelectedOutletId(
          userId: userId,
          outlets: outlets,
        );

        return OwnerBootstrap(
          profile: profile,
          business: business,
          membership: membership,
          outlets: outlets,
          currentOutletId: currentOutletId,
        );
      }().timeout(timeoutDuration),
      );

      final mergedBootstrap = await _applyPending(onlineBootstrap);
      await _writeCachedBootstrap(mergedBootstrap);
      return mergedBootstrap;
    } catch (error) {
      if (cached != null) {
        debugPrint('[offline-bootstrap] Online fetch failed/timed out ($error), returning cached bootstrap');
        return _applyPending(cached);
      }
      debugPrint('[offline-bootstrap] Online fetch failed without cache ($error), returning emergency fallback bootstrap');
      final fullName = currentUser.userMetadata?['full_name'] as String? ??
          currentUser.userMetadata?['name'] as String? ??
          currentUser.email?.split('@').first ??
          'User';
      final emergencyProfile = AppProfile(
        id: userId,
        email: currentUser.email,
        fullName: fullName,
        phone: currentUser.phone,
        avatarUrl: currentUser.userMetadata?['avatar_url'] as String?,
        defaultRole: AppRole.owner,
        isActive: true,
        onboardingCompleted: false,
      );
      return OwnerBootstrap(
        profile: emergencyProfile,
        business: null,
        membership: null,
        outlets: const <Outlet>[],
        currentOutletId: null,
      );
    }
  }

  Future<void> _syncPendingBusinessUpdate(
    _PendingBusinessProfileUpdate pending,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }

    final businessJson = await _client
        .from('businesses')
        .update({
          'name': pending.businessName,
          'slug': pending.slug,
          'phone': pending.businessPhone,
          'email': pending.businessEmail,
        })
        .eq('id', pending.businessId)
        .eq('owner_user_id', user.id)
        .select()
        .single();

    await _client
        .from('profiles')
        .update({'full_name': pending.ownerName})
        .eq('id', user.id);

    await _clearPendingBusinessUpdate(user.id);
    await _updateCachedBootstrapAfterSync(
      user.id,
      Business.fromMap(Map<String, dynamic>.from(businessJson)),
      pending.ownerName,
    );
  }

  Future<void> _writeCachedBootstrap(OwnerBootstrap bootstrap) async {
    final userId = bootstrap.profile?.id ?? _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${AuthRepository._bootstrapCachePrefix}$userId',
      jsonEncode(bootstrap.toMap()),
    );
  }

  Future<String?> _resolveSelectedOutletId({
    required String userId,
    required List<Outlet> outlets,
  }) async {
    if (outlets.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(
      '${AuthRepository._selectedOutletPrefix}$userId',
    );
    if (stored != null && outlets.any((item) => item.id == stored)) {
      return stored;
    }

    // Jika belum tersimpan atau tidak cocok, otomatis gunakan outlet aktif pertama (atau outlet pertama)
    final target = outlets.firstWhere(
      (item) => item.isActive,
      orElse: () => outlets.first,
    );
    final selectedId = target.id;
    await prefs.setString(
      '${AuthRepository._selectedOutletPrefix}$userId',
      selectedId,
    );
    return selectedId;
  }

  Future<OwnerBootstrap?> _readCachedBootstrap(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      '${AuthRepository._bootstrapCachePrefix}$userId',
    );
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return OwnerBootstrap.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (error) {
      debugPrint('[offline-cache] failed to parse bootstrap cache: $error');
      return null;
    }
  }

  Future<void> _writePendingBusinessUpdate(
    String userId,
    _PendingBusinessProfileUpdate update,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${AuthRepository._pendingBusinessUpdatePrefix}$userId',
      jsonEncode(update.toMap()),
    );
  }

  Future<_PendingBusinessProfileUpdate?> _readPendingBusinessUpdate(
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      '${AuthRepository._pendingBusinessUpdatePrefix}$userId',
    );
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return _PendingBusinessProfileUpdate.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (error) {
      debugPrint('[offline-cache] failed to parse pending update: $error');
      return null;
    }
  }

  Future<void> _clearPendingBusinessUpdate(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${AuthRepository._pendingBusinessUpdatePrefix}$userId');
  }

  Future<OwnerBootstrap> _applyPending(OwnerBootstrap bootstrap) async {
    final userId = bootstrap.profile?.id ?? _client.auth.currentUser?.id;
    if (userId == null) {
      return bootstrap;
    }

    final pending = await _readPendingBusinessUpdate(userId);
    if (pending == null) {
      return bootstrap;
    }

    return bootstrap.copyWith(
      profile: bootstrap.profile?.copyWith(fullName: pending.ownerName),
      business:
          (bootstrap.business ??
                  Business(
                    id: pending.businessId,
                    ownerUserId: userId,
                    name: pending.businessName,
                    slug: pending.slug,
                    phone: pending.businessPhone,
                    email: pending.businessEmail,
                    currencyCode: 'IDR',
                    timezone: pending.timezone,
                    updatedAt: pending.updatedAt,
                  ))
              .copyWith(
                name: pending.businessName,
                slug: pending.slug,
                phone: pending.businessPhone,
                email: pending.businessEmail,
                timezone: pending.timezone,
                updatedAt: pending.updatedAt,
              ),
    );
  }

  Future<void> _applyPendingToCachedBootstrap(
    String userId,
    _PendingBusinessProfileUpdate pending,
  ) async {
    final cached = await _readCachedBootstrap(userId);
    if (cached == null) {
      return;
    }

    final updated = cached.copyWith(
      profile: cached.profile?.copyWith(fullName: pending.ownerName),
      business: cached.business?.copyWith(
        name: pending.businessName,
        slug: pending.slug,
        phone: pending.businessPhone,
        email: pending.businessEmail,
        timezone: pending.timezone,
        updatedAt: pending.updatedAt,
      ),
    );
    await _writeCachedBootstrap(updated);
  }

  Future<void> _updateCachedBootstrapAfterSync(
    String userId,
    Business business,
    String? ownerName,
  ) async {
    final cached = await _readCachedBootstrap(userId);
    if (cached == null) {
      return;
    }

    final updated = cached.copyWith(
      profile: cached.profile?.copyWith(fullName: ownerName),
      business: business,
    );
    await _writeCachedBootstrap(updated);
  }

  Future<Business> _buildOptimisticBusiness(
    String userId,
    _PendingBusinessProfileUpdate pending,
  ) async {
    final cached = await _readCachedBootstrap(userId);
    final fallback = cached?.business;

    return (fallback ??
            Business(
              id: pending.businessId,
              ownerUserId: userId,
              name: pending.businessName,
              slug: pending.slug,
              phone: pending.businessPhone,
              email: pending.businessEmail,
              currencyCode: 'IDR',
              timezone: pending.timezone,
              updatedAt: pending.updatedAt,
            ))
        .copyWith(
          name: pending.businessName,
          slug: pending.slug,
          phone: pending.businessPhone,
          email: pending.businessEmail,
          timezone: pending.timezone,
          updatedAt: pending.updatedAt,
        );
  }

  bool _isLikelyOfflineError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('clientexception') ||
        message.contains('connection closed') ||
        message.contains('network is unreachable') ||
        message.contains('timed out') ||
        message.contains('xmlhttprequest error');
  }
}

class _PendingBusinessProfileUpdate {
  const _PendingBusinessProfileUpdate({
    required this.businessId,
    required this.businessName,
    required this.slug,
    required this.timezone,
    required this.updatedAt,
    this.businessPhone,
    this.businessEmail,
    this.ownerName,
  });

  final String businessId;
  final String businessName;
  final String slug;
  final String timezone;
  final String? businessPhone;
  final String? businessEmail;
  final String? ownerName;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'business_id': businessId,
      'business_name': businessName,
      'slug': slug,
      'timezone': timezone,
      'business_phone': businessPhone,
      'business_email': businessEmail,
      'owner_name': ownerName,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory _PendingBusinessProfileUpdate.fromMap(Map<String, dynamic> json) {
    return _PendingBusinessProfileUpdate(
      businessId: json['business_id'] as String,
      businessName: json['business_name'] as String,
      slug: json['slug'] as String,
      timezone: json['timezone'] as String,
      businessPhone: json['business_phone'] as String?,
      businessEmail: json['business_email'] as String?,
      ownerName: json['owner_name'] as String?,
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}
