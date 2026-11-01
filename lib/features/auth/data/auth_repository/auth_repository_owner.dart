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

    final list = response
        .map((item) => Outlet.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    if (list.isEmpty) {
      try {
        final bizData = await _client
            .from('businesses')
            .select()
            .eq('id', businessId)
            .maybeSingle();
        if (bizData != null) {
          final biz = Business.fromMap(Map<String, dynamic>.from(bizData));
          final autoOutlet = await ensureDefaultOutlet(biz);
          if (autoOutlet != null) {
            return [autoOutlet];
          }
        }
      } catch (e) {
        debugPrint('[fetchBusinessOutlets] auto-heal note: $e');
      }
    }

    return list;
  }

  Future<Outlet?> ensureDefaultOutlet(Business business) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    // 1. Cek apakah di database sudah ada outlet
    try {
      final existing = await _client
          .from('outlets')
          .select()
          .eq('business_id', business.id)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 3));
      if (existing != null) {
        final outlet = Outlet.fromMap(Map<String, dynamic>.from(existing));
        try {
          await _client.from('outlet_members').upsert({
            'outlet_id': outlet.id,
            'user_id': userId,
            'role': AppRole.owner.name,
            'status': 'active',
          }, onConflict: 'outlet_id,user_id');
        } catch (_) {}
        return outlet;
      }
    } catch (e) {
      debugPrint('[ensureDefaultOutlet] query existing note: $e');
    }

    // 2. Coba via RPC ensure_business_default_outlet jika tersedia
    try {
      final rpcRes = await _client.rpc(
        'ensure_business_default_outlet',
        params: {'p_business_id': business.id},
      ).timeout(const Duration(seconds: 4));
      if (rpcRes is Map && rpcRes['success'] == true) {
        final outletId = rpcRes['outlet_id'] as String?;
        if (outletId != null) {
          final res = await _client.from('outlets').select().eq('id', outletId).maybeSingle().timeout(const Duration(seconds: 3));
          if (res != null) {
            return Outlet.fromMap(Map<String, dynamic>.from(res));
          }
        }
      }
    } catch (e) {
      debugPrint('[ensureDefaultOutlet] rpc note: $e');
    }

    // 3. Fallback direct insert
    try {
      final payload = <String, dynamic>{
        'business_id': business.id,
        'name': business.name.trim().isNotEmpty ? business.name.trim() : 'Outlet Utama',
        'code': 'main',
        if (business.address != null) 'address': business.address,
        if (business.phone != null) 'phone': business.phone,
        if (business.latitude != null) 'latitude': business.latitude,
        if (business.longitude != null) 'longitude': business.longitude,
        'is_active': true,
      };

      final res = await _client
          .from('outlets')
          .insert(payload)
          .select()
          .timeout(const Duration(seconds: 4));

      if (res.isNotEmpty) {
        final outletMap = Map<String, dynamic>.from(res.first as Map);
        final outlet = Outlet.fromMap(outletMap);
        try {
          await _client.from('outlet_members').upsert({
            'outlet_id': outlet.id,
            'user_id': userId,
            'role': AppRole.owner.name,
            'status': 'active',
          }, onConflict: 'outlet_id,user_id');
        } catch (_) {}
        return outlet;
      }
    } catch (e) {
      debugPrint('[ensureDefaultOutlet] direct insert note: $e');
    }

    // 4. Memory fallback so the user is never stuck with 0 outlets
    return Outlet(
      id: business.id,
      businessId: business.id,
      name: business.name.trim().isNotEmpty ? business.name.trim() : 'Outlet Utama',
      code: 'main',
      address: business.address,
      phone: business.phone,
      latitude: business.latitude,
      longitude: business.longitude,
      timezone: 'Asia/Jakarta',
      isActive: true,
    );
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
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (geofenceRadius != null) 'geofence_radius': geofenceRadius,
      'is_geofence_active': isGeofenceActive,
      'timezone': timezone,
      'is_active': isActive,
    };

    Map<String, dynamic>? outletJson;
    try {
      final res = await _client
          .from('outlets')
          .insert(insertData)
          .select()
          .timeout(const Duration(seconds: 12));
      if (res.isNotEmpty) {
        outletJson = Map<String, dynamic>.from(res.first as Map);
      }
    } catch (e) {
      debugPrint('[createOutlet] insert note: $e');
    }

    if (outletJson == null) {
      try {
        final reQuery = await _client
            .from('outlets')
            .select()
            .eq('business_id', businessId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (reQuery != null) {
          outletJson = Map<String, dynamic>.from(reQuery);
        }
      } catch (_) {}
    }

    outletJson ??= {
      'id': businessId,
      ...insertData,
      'timezone': timezone,
      'created_at': DateTime.now().toIso8601String(),
    };

    if (outletJson['id'] != null) {
      try {
        await _client.from('outlet_members').upsert({
          'outlet_id': outletJson['id'],
          'user_id': userId,
          'role': AppRole.owner.name,
          'status': 'active',
        }, onConflict: 'outlet_id,user_id');
      } catch (_) {}
    }

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
    String? ownerName,
    String? province,
    String? city,
    String? district,
    String? village,
    String? starterKitId,
    String? starterKitName,
    String? orderCode,
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

    Map<String, dynamic>? businessJson;
    if (existingBizData != null) {
      final updatePayload = <String, dynamic>{
        'name': businessName,
        'phone': businessPhone,
        'email': businessEmail,
        if (businessAddress != null) 'address': businessAddress,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (businessType != null) 'business_type': businessType,
        if (enabledFeatures != null) 'enabled_features': enabledFeatures,
        if (province != null) 'province': province,
        if (city != null) 'city': city,
        if (district != null) 'district': district,
        if (village != null) 'village': village,
        if (starterKitId != null) 'starter_kit_id': starterKitId,
        if (starterKitId != null) 'status': 'pending',
      };
      try {
        final res = await _client
            .from('businesses')
            .update(updatePayload)
            .eq('id', existingBizData['id'])
            .select()
            .timeout(const Duration(seconds: 10));
        if (res.isNotEmpty) {
          businessJson = Map<String, dynamic>.from(res.first as Map);
        }
      } catch (e) {
        debugPrint('[createOwnerBusiness] business update note: $e');
      }
      businessJson ??= {
        ...existingBizData,
        ...updatePayload,
      };
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

      final insertPayload = <String, dynamic>{
        'owner_user_id': user.id,
        'name': businessName,
        'slug': targetSlug,
        'phone': businessPhone,
        'email': businessEmail,
        'address': businessAddress,
        'latitude': latitude,
        'longitude': longitude,
        'business_type': businessType,
        'enabled_features': enabledFeatures ?? templateJson?['default_enabled_features'] ?? const [],
        'features_config': templateJson?['features_config'] ?? const {},
        'limits_config': templateJson?['limits_config'] ?? const {'free': {}, 'pro': {}},
        'role_labels': templateJson?['role_labels'] ?? const {},
        'max_transactions': templateJson?['max_transactions'] ?? 100,
        'max_products': templateJson?['max_products'] ?? 50,
        'max_outlets': templateJson?['max_outlets'] ?? 1,
        if (province != null) 'province': province,
        if (city != null) 'city': city,
        if (district != null) 'district': district,
        if (village != null) 'village': village,
        if (starterKitId != null) 'starter_kit_id': starterKitId,
        if (starterKitId != null) 'status': 'pending',
      };

      try {
        final res = await _client
            .from('businesses')
            .insert(insertPayload)
            .select()
            .timeout(const Duration(seconds: 15));
        if (res.isNotEmpty) {
          businessJson = Map<String, dynamic>.from(res.first as Map);
        }
      } catch (e) {
        debugPrint('[createOwnerBusiness] business insert note: $e');
      }

      if (businessJson == null) {
        final reQuery = await _client
            .from('businesses')
            .select()
            .eq('owner_user_id', user.id)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
        if (reQuery != null) {
          businessJson = Map<String, dynamic>.from(reQuery);
        } else {
          businessJson = {
            'id': user.id,
            ...insertPayload,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
        }
      }
    }

    final business = Business.fromMap(businessJson);

    // Upsert business_members dengan onConflict eksplisit
    try {
      await _client.from('business_members').upsert({
        'business_id': business.id,
        'user_id': user.id,
        'role': AppRole.owner.name,
        'status': 'active',
      }, onConflict: 'business_id,user_id').timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[createOwnerBusiness] business_members upsert note: $e');
    }

    // Cek apakah outlet sudah ada untuk bisnis ini
    final existingOutlet = await _client
        .from('outlets')
        .select()
        .eq('business_id', business.id)
        .limit(1)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    Map<String, dynamic>? outletJson;
    if (existingOutlet != null) {
      if (businessAddress != null) {
        try {
          final res = await _client
              .from('outlets')
              .update({'address': businessAddress})
              .eq('id', existingOutlet['id'])
              .select()
              .timeout(const Duration(seconds: 10));
          if (res.isNotEmpty) {
            outletJson = Map<String, dynamic>.from(res.first as Map);
          }
        } catch (e) {
          debugPrint('[createOwnerBusiness] outlet update note: $e');
        }
      }
      outletJson ??= Map<String, dynamic>.from(existingOutlet);
    } else {
      final outletPayload = <String, dynamic>{
        'business_id': business.id,
        'name': businessName,
        'code': 'main',
        'phone': businessPhone,
        'address': businessAddress,
        'is_active': true,
      };
      try {
        final res = await _client
            .from('outlets')
            .insert(outletPayload)
            .select()
            .timeout(const Duration(seconds: 15));
        if (res.isNotEmpty) {
          outletJson = Map<String, dynamic>.from(res.first as Map);
        }
      } catch (e) {
        debugPrint('[createOwnerBusiness] outlet insert note: $e');
      }

      if (outletJson == null) {
        final reQuery = await _client
            .from('outlets')
            .select()
            .eq('business_id', business.id)
            .limit(1)
            .maybeSingle()
            .timeout(const Duration(seconds: 10));
        if (reQuery != null) {
          outletJson = Map<String, dynamic>.from(reQuery);
        } else {
          outletJson = {
            'id': business.id,
            ...outletPayload,
            'created_at': DateTime.now().toIso8601String(),
          };
        }
      }
    }

    // Upsert outlet_members dengan onConflict eksplisit
    if (outletJson['id'] != null) {
      try {
        await _client.from('outlet_members').upsert({
          'outlet_id': outletJson['id'],
          'user_id': user.id,
          'role': AppRole.owner.name,
        }, onConflict: 'outlet_id,user_id').timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[createOwnerBusiness] outlet_members upsert note: $e');
      }
    }

    try {
      await _client
          .from('profiles')
          .update({
            'role': 'owner',
            if (businessPhone != null) 'phone': businessPhone,
            if (ownerName != null) 'full_name': ownerName,
          })
          .eq('id', user.id)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[createOwnerBusiness] profiles update note: $e');
    }

    // Auto-seed produk starter kit jika dipilih
    if (starterKitId != null) {
      try {
        await _client.rpc('apply_starter_kit_to_business', params: {
          'p_business_id': business.id,
          'p_starter_kit_id': starterKitId,
        }).timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('[createOwnerBusiness] apply_starter_kit_to_business note: $e');
      }

      // Terbitkan tiket pemesanan starter kit ke package_fulfillment_orders
      final finalOrderCode = orderCode ??
          'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      try {
        await _client.from('package_fulfillment_orders').insert({
          'order_code': finalOrderCode,
          'starter_kit_id': starterKitId,
          'kit_name': starterKitName ?? 'Paket Usaha Retail',
          'recipient_name': '${ownerName ?? 'Owner'} ($businessName)',
          'recipient_phone': businessPhone ?? '',
          'shipping_address': businessAddress ?? '-',
          'shipping_city': city ?? 'Indonesia',
          'recipient_lat': latitude,
          'recipient_lng': longitude,
          'status': 'pending_dispatch',
          'fulfillment_mode': 'agent_direct',
          'sender_alias': 'Syupeo Official',
          'notes': 'Pemesanan paket kemitraan via aplikasi Syupeo.',
        });
      } catch (e) {
        debugPrint('[createOwnerBusiness] package_fulfillment_orders note: $e');
      }
    }

    if (outletJson['id'] != null) {
      await setCurrentOutletId(outletJson['id'] as String);
    }

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
            if (businessAddress != null) 'address': businessAddress,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
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

      // Sync address to outlets if provided
      if (businessAddress != null) {
        try {
          await _client
              .from('outlets')
              .update({
                'address': businessAddress,
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
