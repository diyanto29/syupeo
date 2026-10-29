part of '../auth_repository.dart';

extension AuthRepositoryOwnerContext on AuthRepository {
  Future<List<Outlet>> fetchBusinessOutlets(
    String businessId, {
    bool includeInactive = false,
  }) async {
    final query = _client
        .from('outlets')
        .select()
        .eq('business_id', businessId);

    final response =
        await (includeInactive ? query : query.eq('is_active', true)).order(
          'created_at',
          ascending: true,
        );

    return response
        .map((item) => Outlet.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<Outlet>> fetchAccessibleOutlets(String businessId) {
    return fetchBusinessOutlets(businessId);
  }

  Future<Outlet> createOutlet({
    required String businessId,
    required String name,
    String? code,
    String? address,
    String? phone,
    double? latitude,
    double? longitude,
    int? geofenceRadius,
    bool isGeofenceActive = true,
    required String timezone,
    bool isActive = true,
  }) async {
    final userId = _currentUserIdOrThrow;

    final insertData = <String, dynamic>{
      'business_id': businessId,
      'name': name.trim(),
      'code': _normalizeOutletCode(code),
      'address': _nullableText(address),
      'phone': _nullableText(phone),
      'timezone': timezone,
      'is_active': isActive,
    };
    if (latitude != null) insertData['latitude'] = latitude;
    if (longitude != null) insertData['longitude'] = longitude;
    if (geofenceRadius != null) insertData['geofence_radius'] = geofenceRadius;
    insertData['is_geofence_active'] = isGeofenceActive;

    final outletJson = await _client
        .from('outlets')
        .insert(insertData)
        .select()
        .single();

    await _client.from('outlet_members').upsert({
      'outlet_id': outletJson['id'],
      'user_id': userId,
      'role': AppRole.owner.name,
      'status': 'active',
    });

    if (phone != null && phone.trim().isNotEmpty) {
      try {
        await _client
            .from('businesses')
            .update({'phone': phone.trim()})
            .eq('id', businessId)
            .or('phone.is.null,phone.eq.""');
      } catch (e) {
        debugPrint('[createOutlet] non-fatal business phone sync warning: $e');
      }
    }

    return Outlet.fromMap(Map<String, dynamic>.from(outletJson));
  }

  Future<Outlet> updateOutlet({
    required String outletId,
    required String businessId,
    required String name,
    String? code,
    String? address,
    String? phone,
    double? latitude,
    double? longitude,
    int? geofenceRadius,
    bool? isGeofenceActive,
    required String timezone,
    required bool isActive,
    bool? taxEnabled,
    String? taxName,
    double? taxRate,
    bool? isTaxInclusive,
  }) async {
    final updateData = <String, dynamic>{
      'name': name.trim(),
      'code': _normalizeOutletCode(code),
      'address': _nullableText(address),
      'phone': _nullableText(phone),
      'timezone': timezone,
      'is_active': isActive,
    };
    if (latitude != null) updateData['latitude'] = latitude;
    if (longitude != null) updateData['longitude'] = longitude;
    if (geofenceRadius != null) updateData['geofence_radius'] = geofenceRadius;
    if (isGeofenceActive != null) updateData['is_geofence_active'] = isGeofenceActive;
    if (taxEnabled != null) updateData['tax_enabled'] = taxEnabled;
    if (taxName != null) updateData['tax_name'] = taxName.trim();
    if (taxRate != null) updateData['tax_rate'] = taxRate;
    if (isTaxInclusive != null) updateData['is_tax_inclusive'] = isTaxInclusive;

    final outletJson = await _client
        .from('outlets')
        .update(updateData)
        .eq('id', outletId)
        .eq('business_id', businessId)
        .select()
        .single();

    if (phone != null && phone.trim().isNotEmpty) {
      try {
        await _client
            .from('businesses')
            .update({'phone': phone.trim()})
            .eq('id', businessId)
            .or('phone.is.null,phone.eq.""');
      } catch (e) {
        debugPrint('[updateOutlet] non-fatal business phone sync warning: $e');
      }
    }

    return Outlet.fromMap(Map<String, dynamic>.from(outletJson));
  }

  Future<Outlet> updateOutletTaxSettings({
    required String outletId,
    required String businessId,
    required bool taxEnabled,
    required String taxName,
    required double taxRate,
    required bool isTaxInclusive,
  }) async {
    final outletJson = await _client
        .from('outlets')
        .update({
          'tax_enabled': taxEnabled,
          'tax_name': taxName.trim().isEmpty ? 'PB1' : taxName.trim(),
          'tax_rate': taxRate,
          'is_tax_inclusive': isTaxInclusive,
        })
        .eq('id', outletId)
        .eq('business_id', businessId)
        .select()
        .single();

    return Outlet.fromMap(Map<String, dynamic>.from(outletJson));
  }

  Future<Business> createOwnerBusiness({
    required String businessName,
    required String slug,
    String? businessPhone,
    String? businessEmail,
    String? businessAddress,
    double? latitude,
    double? longitude,
    int? geofenceRadius,
    bool? isGeofenceActive,
    String? businessType,
    List<String>? enabledFeatures,
  }) async {
    final user = _currentUserOrThrow;

    // Fetch the template to initialize full configuration if businessType is provided
    Map<String, dynamic>? templateJson;
    if (businessType != null) {
      try {
        templateJson = await _client
            .from('business_type_templates')
            .select()
            .eq('code', businessType)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[createOwnerBusiness] failed to fetch template: $e');
      }
    }

    // Safety check: jika owner ini ternyata sudah memiliki bisnis di database
    // (misal karena retry, double click, atau koneksi sempat putus),
    // jangan buat bisnis baru. Perbarui bisnis yang sudah ada dan pastikan outlet & member lengkap.
    final existingBizData = await _client
        .from('businesses')
        .select()
        .eq('owner_user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    final Map<String, dynamic> businessJson;
    if (existingBizData != null) {
      final updatedBiz = await _client
          .from('businesses')
          .update({
            'name': businessName,
            'phone': businessPhone,
            'email': businessEmail,
            if (businessAddress != null) 'address': businessAddress,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
            if (geofenceRadius != null) 'geofence_radius': geofenceRadius,
            if (isGeofenceActive != null) 'is_geofence_active': isGeofenceActive,
            if (businessType != null) 'business_type': businessType,
            if (enabledFeatures != null) 'enabled_features': enabledFeatures,
          })
          .eq('id', existingBizData['id'])
          .select()
          .single()
          .timeout(const Duration(seconds: 10));
      businessJson = updatedBiz;
    } else {
      // Pastikan slug tidak bentrok dengan bisnis lain
      String targetSlug = slug;
      try {
        final existingSlug = await _client
            .from('businesses')
            .select('id')
            .eq('slug', targetSlug)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
        if (existingSlug != null) {
          targetSlug = '$targetSlug-${DateTime.now().millisecondsSinceEpoch % 10000}';
        }
      } catch (_) {
        // Abaikan jika query check slug gagal, biarkan insert mencoba
      }

      businessJson = await _client
          .from('businesses')
          .insert({
            'owner_user_id': user.id,
            'name': businessName,
            'slug': targetSlug,
            'phone': businessPhone,
            'email': businessEmail,
            'address': businessAddress,
            'latitude': latitude,
            'longitude': longitude,
            'geofence_radius': geofenceRadius ?? 5000,
            'is_geofence_active': isGeofenceActive ?? true,
            'currency_code': 'IDR',
            'timezone': 'Asia/Jakarta',
            'business_type': businessType,
            'enabled_features': enabledFeatures ?? templateJson?['default_enabled_features'] ?? const [],
            'features_config': templateJson?['features_config'] ?? const {},
            'limits_config': templateJson?['limits_config'] ?? const {'free': {}, 'pro': {}},
            'role_labels': templateJson?['role_labels'] ?? const {},
            'max_transactions': templateJson?['max_transactions'] ?? 100,
            'max_products': templateJson?['max_products'] ?? 50,
            'max_outlets': templateJson?['max_outlets'] ?? 1,
          })
          .select()
          .single()
          .timeout(const Duration(seconds: 15));
    }

    final business = Business.fromMap(Map<String, dynamic>.from(businessJson));

    // Upsert business_members dengan onConflict eksplisit
    await _client.from('business_members').upsert({
      'business_id': business.id,
      'user_id': user.id,
      'role': AppRole.owner.name,
      'status': 'active',
    }, onConflict: 'business_id,user_id').timeout(const Duration(seconds: 10));

    // Cek apakah outlet sudah ada untuk bisnis ini
    final existingOutlet = await _client
        .from('outlets')
        .select()
        .eq('business_id', business.id)
        .limit(1)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    final Map<String, dynamic> outletJson;
    if (existingOutlet != null) {
      if (businessAddress != null || latitude != null || longitude != null || geofenceRadius != null || isGeofenceActive != null) {
        outletJson = await _client
            .from('outlets')
            .update({
              if (businessAddress != null) 'address': businessAddress,
              if (latitude != null) 'latitude': latitude,
              if (longitude != null) 'longitude': longitude,
              if (geofenceRadius != null) 'geofence_radius': geofenceRadius,
              if (isGeofenceActive != null) 'is_geofence_active': isGeofenceActive,
            })
            .eq('id', existingOutlet['id'])
            .select()
            .single()
            .timeout(const Duration(seconds: 10));
      } else {
        outletJson = existingOutlet;
      }
    } else {
      outletJson = await _client
          .from('outlets')
          .upsert({
            'business_id': business.id,
            'name': businessName,
            'code': 'main',
            'phone': businessPhone,
            'address': businessAddress,
            'latitude': latitude,
            'longitude': longitude,
            'geofence_radius': geofenceRadius ?? 5000,
            'is_geofence_active': isGeofenceActive ?? true,
            'timezone': 'Asia/Jakarta',
            'is_active': true,
          }, onConflict: 'business_id,code')
          .select()
          .single()
          .timeout(const Duration(seconds: 15));
    }

    // Upsert outlet_members dengan onConflict eksplisit
    await _client.from('outlet_members').upsert({
      'outlet_id': outletJson['id'],
      'user_id': user.id,
      'role': AppRole.owner.name,
      'status': 'active',
    }, onConflict: 'outlet_id,user_id').timeout(const Duration(seconds: 10));

    await _client
        .from('profiles')
        .update({'onboarding_completed': true, 'default_role': 'owner'})
        .eq('id', user.id)
        .timeout(const Duration(seconds: 10));

    await setCurrentOutletId(outletJson['id'] as String);

    // Langsung buat dan simpan snapshot bootstrap terkini ke cache lokal
    try {
      final profile = await fetchCurrentProfile();
      final outlet = Outlet.fromMap(Map<String, dynamic>.from(outletJson));
      final membership = await fetchOwnerMembership(business.id);
      final freshBootstrap = OwnerBootstrap(
        profile: profile,
        business: business,
        membership: membership,
        outlets: [outlet],
        currentOutletId: outlet.id,
      );
      await _writeCachedBootstrap(freshBootstrap);
    } catch (e) {
      debugPrint('[createOwnerBusiness] non-fatal cache write warning: $e');
    }

    return business;
  }

  Future<void> setCurrentOutletId(String outletId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${AuthRepository._selectedOutletPrefix}$userId',
      outletId,
    );

    final cached = await _readCachedBootstrap(userId);
    if (cached != null) {
      await _writeCachedBootstrap(cached.copyWith(currentOutletId: outletId));
    }
  }

  Future<Business> updateOwnerBusinessProfile({
    required String businessId,
    required String businessName,
    required String slug,
    required String timezone,
    String? businessPhone,
    String? businessEmail,
    String? businessAddress,
    double? latitude,
    double? longitude,
    int? geofenceRadius,
    bool? isGeofenceActive,
    String? ownerName,
    String? businessType,
  }) async {
    final user = _currentUserOrThrow;

    final pendingUpdate = _PendingBusinessProfileUpdate(
      businessId: businessId,
      businessName: businessName,
      slug: slug,
      timezone: timezone,
      businessPhone: businessPhone,
      businessEmail: businessEmail,
      ownerName: ownerName,
      updatedAt: DateTime.now().toUtc(),
    );
    await _writePendingBusinessUpdate(user.id, pendingUpdate);
    await _applyPendingToCachedBootstrap(user.id, pendingUpdate);

    try {
      final businessJson = await _client
          .from('businesses')
          .update({
            'name': businessName,
            'slug': slug,
            'phone': businessPhone,
            'email': businessEmail,
            'timezone': timezone,
            if (businessAddress != null) 'address': businessAddress,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
            if (geofenceRadius != null) 'geofence_radius': geofenceRadius,
            if (isGeofenceActive != null) 'is_geofence_active': isGeofenceActive,
            'business_type': businessType,
          })
          .eq('id', businessId)
          .eq('owner_user_id', user.id)
          .select()
          .single();

      await _client
          .from('profiles')
          .update({'full_name': ownerName})
          .eq('id', user.id);

      // Sync address and geofence to outlets if provided
      if (businessAddress != null || latitude != null || longitude != null || geofenceRadius != null || isGeofenceActive != null) {
        try {
          await _client
              .from('outlets')
              .update({
                if (businessAddress != null) 'address': businessAddress,
                if (latitude != null) 'latitude': latitude,
                if (longitude != null) 'longitude': longitude,
                if (geofenceRadius != null) 'geofence_radius': geofenceRadius,
                if (isGeofenceActive != null) 'is_geofence_active': isGeofenceActive,
              })
              .eq('business_id', businessId);
        } catch (e) {
          debugPrint('[updateOwnerBusinessProfile] non-fatal outlet location sync warning: $e');
        }
      }

      if (businessPhone != null && businessPhone.trim().isNotEmpty) {
        try {
          await _client
              .from('outlets')
              .update({'phone': businessPhone.trim()})
              .eq('business_id', businessId)
              .or('phone.is.null,phone.eq.""');
        } catch (e) {
          debugPrint('[updateOwnerBusinessProfile] non-fatal outlet phone sync warning: $e');
        }
      }

      await _clearPendingBusinessUpdate(user.id);

      final business = Business.fromMap(
        Map<String, dynamic>.from(businessJson),
      );
      await _updateCachedBootstrapAfterSync(user.id, business, ownerName);
      return business;
    } catch (error) {
      if (_isLikelyOfflineError(error)) {
        return _buildOptimisticBusiness(user.id, pendingUpdate);
      }
      rethrow;
    }
  }

  Future<List<BusinessTypeTemplate>> fetchBusinessTypeTemplates() async {
    final response = await _client.from('business_type_templates').select();
    return (response as List)
        .map((e) => BusinessTypeTemplate.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> applyBusinessTypeTemplate({
    required String businessId,
    required String templateCode,
  }) async {
    final templateResponse = await _client
        .from('business_type_templates')
        .select()
        .eq('code', templateCode)
        .single();

    final template =
        BusinessTypeTemplate.fromMap(Map<String, dynamic>.from(templateResponse));

    await _client.from('businesses').update({
      'business_type': template.code,
      'enabled_features': template.defaultEnabledFeatures,
      'max_transactions': template.maxTransactions,
      'max_products': template.maxProducts,
      'max_outlets': template.maxOutlets,
      'features_config': template.featuresConfig,
      'limits_config': template.limitsConfig,
      'role_labels': template.roleLabels,
    }).eq('id', businessId).eq('owner_user_id', _currentUserIdOrThrow);
  }

  Future<List<Business>> fetchAllBusinesses() async {
    final response = await _client
        .from('businesses')
        .select('*, subscription_plans(*)');
    
    return response
        .map((item) => Business.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> updateBusinessTemplateAdmin({
    required String businessId,
    required String templateCode,
  }) async {
    // 1. Get template
    final templateResponse = await _client
        .from('business_type_templates')
        .select()
        .eq('code', templateCode)
        .single();

    final template = BusinessTypeTemplate.fromMap(Map<String, dynamic>.from(templateResponse));

    // 2. Update business (Admin bypass owner check)
    await _client.from('businesses').update({
      'business_type': template.code,
      'enabled_features': template.defaultEnabledFeatures,
      'max_transactions': template.maxTransactions,
      'max_products': template.maxProducts,
      'max_outlets': template.maxOutlets,
      'features_config': template.featuresConfig,
      'limits_config': template.limitsConfig,
      'role_labels': template.roleLabels,
    }).eq('id', businessId);
  }

  Future<void> createBusinessTypeTemplate(BusinessTypeTemplate template) async {
    await _client.from('business_type_templates').insert({
      'name': template.name,
      'code': template.code,
      'description': template.description,
      'icon_name': template.iconName,
      'default_enabled_features': template.defaultEnabledFeatures,
      'features_config': template.featuresConfig,
      'limits_config': template.limitsConfig,
      'max_transactions': template.maxTransactions,
      'max_products': template.maxProducts,
      'max_outlets': template.maxOutlets,
      'show_ads': template.showAds,
      'role_labels': template.roleLabels,
    });
  }

  Future<void> updateBusinessTypeTemplate(BusinessTypeTemplate template) async {
    // 1. Update the template itself
    await _client.from('business_type_templates').update({
      'name': template.name,
      'description': template.description,
      'icon_name': template.iconName,
      'default_enabled_features': template.defaultEnabledFeatures,
      'features_config': template.featuresConfig,
      'limits_config': template.limitsConfig,
      'max_transactions': template.maxTransactions,
      'max_products': template.maxProducts,
      'max_outlets': template.maxOutlets,
      'show_ads': template.showAds,
      'role_labels': template.roleLabels,
    }).eq('id', template.id);

    // 2. Cascade changes to all businesses using this template type
    await _client.from('businesses').update({
      'enabled_features': template.defaultEnabledFeatures,
      'features_config': template.featuresConfig,
      'limits_config': template.limitsConfig,
      'role_labels': template.roleLabels,
      'max_transactions': template.maxTransactions,
      'max_products': template.maxProducts,
      'max_outlets': template.maxOutlets,
    }).eq('business_type', template.code);
  }

  Future<void> deleteBusinessTypeTemplate(String templateId) async {
    await _client.from('business_type_templates').delete().eq('id', templateId);
  }

  Future<void> updateBusinessFeatures({
    required String businessId,
    required List<String> features,
  }) async {
    await _client
        .from('businesses')
        .update({'enabled_features': features})
        .eq('id', businessId)
        .eq('owner_user_id', _currentUserIdOrThrow);
  }
}
