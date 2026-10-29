enum BuyXGetYMode {
  sameProduct,
  crossProduct;

  static BuyXGetYMode fromDb(String? value) {
    return switch (value) {
      'cross_product' => BuyXGetYMode.crossProduct,
      _ => BuyXGetYMode.sameProduct,
    };
  }

  String get dbValue => switch (this) {
    BuyXGetYMode.sameProduct => 'same_product',
    BuyXGetYMode.crossProduct => 'cross_product',
  };

  String get label => switch (this) {
    BuyXGetYMode.sameProduct => 'Produk Sama',
    BuyXGetYMode.crossProduct => 'Beda Produk',
  };
}

class BuyXGetYPromo {
  const BuyXGetYPromo({
    required this.id,
    required this.businessId,
    required this.name,
    required this.mode,
    required this.triggerMenuItemId,
    required this.minBuyQty,
    this.rewardMenuItemId,
    required this.rewardQty,
    this.isMultipleAllowed = true,
    this.maxRewardPerTransaction = 1,
    required this.startDate,
    required this.endDate,
    this.activeDays,
    this.isActive = true,
    this.triggerItemName,
    this.rewardItemName,
  });

  final String id;
  final String businessId;
  final String name;
  final BuyXGetYMode mode;
  final String triggerMenuItemId;
  final int minBuyQty;
  final String? rewardMenuItemId;
  final int rewardQty;
  final bool isMultipleAllowed;
  final int maxRewardPerTransaction;
  final DateTime startDate;
  final DateTime endDate;
  final List<int>? activeDays;
  final bool isActive;
  final String? triggerItemName;
  final String? rewardItemName;

  String get effectiveRewardItemId =>
      (mode == BuyXGetYMode.sameProduct || rewardMenuItemId == null)
          ? triggerMenuItemId
          : rewardMenuItemId!;

  bool isCurrentlyActive() {
    if (!isActive) return false;
    final now = DateTime.now();
    final startLocal = startDate.toLocal();
    final endLocal = endDate.toLocal();

    // Safe comparison: if today's calendar date is on or after start date, promo is active
    final today = DateTime(now.year, now.month, now.day);
    final promoStartDay = DateTime(startLocal.year, startLocal.month, startLocal.day);
    if (today.isBefore(promoStartDay) && now.isBefore(startLocal)) {
      return false;
    }

    final promoEndDay = DateTime(endLocal.year, endLocal.month, endLocal.day, 23, 59, 59);
    if (now.isAfter(promoEndDay) && now.isAfter(endLocal)) {
      return false;
    }

    if (activeDays != null && activeDays!.isNotEmpty) {
      if (!activeDays!.contains(now.weekday)) return false;
    }
    return true;
  }

  /// Menghitung berapa unit hadiah yang berhak didapat berdasarkan total qty trigger di keranjang
  int calculateRewardUnits(int triggerQtyInCart, {int rewardQtyInCart = 0}) {
    if (!isCurrentlyActive() || triggerQtyInCart < minBuyQty) return 0;

    if (mode == BuyXGetYMode.sameProduct) {
      final groupSize = minBuyQty + rewardQty;
      if (triggerQtyInCart >= groupSize) {
        final eligibleMultipliers =
            isMultipleAllowed ? (triggerQtyInCart ~/ groupSize) : 1;
        final totalRewards = eligibleMultipliers * rewardQty;
        if (maxRewardPerTransaction > 0) {
          return totalRewards.clamp(0, maxRewardPerTransaction);
        }
        return totalRewards;
      }
      return 0;
    } else {
      int eligibleMultipliers;
      if (isMultipleAllowed) {
        eligibleMultipliers = triggerQtyInCart ~/ minBuyQty;
      } else {
        eligibleMultipliers = 1;
      }

      final totalRewards = eligibleMultipliers * rewardQty;
      if (maxRewardPerTransaction > 0) {
        return totalRewards.clamp(0, maxRewardPerTransaction);
      }
      return totalRewards;
    }
  }

  /// Menghitung sisa unit hadiah yang berhak diklaim (belum masuk keranjang)
  int pendingRewardUnits(int triggerQtyInCart, {int rewardQtyInCart = 0}) {
    if (!isCurrentlyActive() || triggerQtyInCart < minBuyQty) return 0;

    if (mode == BuyXGetYMode.sameProduct) {
      final eligibleMultipliers =
          isMultipleAllowed ? (triggerQtyInCart ~/ minBuyQty) : 1;
      final maxEligible = (eligibleMultipliers * rewardQty);
      final alreadyDiscounted = calculateRewardUnits(triggerQtyInCart);
      final remaining = maxEligible - alreadyDiscounted;
      if (maxRewardPerTransaction > 0) {
        return remaining.clamp(0, maxRewardPerTransaction);
      }
      return remaining.clamp(0, rewardQty);
    } else {
      final eligibleMultipliers =
          isMultipleAllowed ? (triggerQtyInCart ~/ minBuyQty) : 1;
      final maxEligible = (eligibleMultipliers * rewardQty);
      final cappedEligible = maxRewardPerTransaction > 0
          ? maxEligible.clamp(0, maxRewardPerTransaction)
          : maxEligible;
      final remaining = cappedEligible - rewardQtyInCart;
      return remaining.clamp(0, cappedEligible);
    }
  }

  factory BuyXGetYPromo.fromJson(Map<String, dynamic> json) {
    final triggerItem = json['trigger_item'] is Map<String, dynamic>
        ? json['trigger_item'] as Map<String, dynamic>
        : null;
    final rewardItem = json['reward_item'] is Map<String, dynamic>
        ? json['reward_item'] as Map<String, dynamic>
        : null;

    final rawDays = json['active_days'];
    List<int>? activeDays;
    if (rawDays is List) {
      activeDays = rawDays.map((e) => (e as num).toInt()).toList();
    }

    return BuyXGetYPromo(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      mode: BuyXGetYMode.fromDb(json['mode'] as String?),
      triggerMenuItemId: json['trigger_menu_item_id'] as String,
      minBuyQty: (json['min_buy_qty'] as num? ?? 1).toInt(),
      rewardMenuItemId: json['reward_menu_item_id'] as String?,
      rewardQty: (json['reward_qty'] as num? ?? 1).toInt(),
      isMultipleAllowed: json['is_multiple_allowed'] as bool? ?? true,
      maxRewardPerTransaction:
          (json['max_reward_per_transaction'] as num? ?? 1).toInt(),
      startDate:
          DateTime.tryParse(json['start_date'] as String? ?? '') ??
          DateTime.now(),
      endDate:
          DateTime.tryParse(json['end_date'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      activeDays: activeDays,
      isActive: json['is_active'] as bool? ?? true,
      triggerItemName: triggerItem?['name'] as String?,
      rewardItemName: rewardItem?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'mode': mode.dbValue,
      'trigger_menu_item_id': triggerMenuItemId,
      'min_buy_qty': minBuyQty,
      'reward_menu_item_id': rewardMenuItemId,
      'reward_qty': rewardQty,
      'is_multiple_allowed': isMultipleAllowed,
      'max_reward_per_transaction': maxRewardPerTransaction,
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endDate.toUtc().toIso8601String(),
      'active_days': activeDays,
      'is_active': isActive,
    };
  }
}

enum TebusMurahMode {
  minSpend,
  productCombo;

  static TebusMurahMode fromDb(String? value) {
    return switch (value) {
      'product_combo' => TebusMurahMode.productCombo,
      _ => TebusMurahMode.minSpend,
    };
  }

  String get dbValue => switch (this) {
    TebusMurahMode.minSpend => 'min_spend',
    TebusMurahMode.productCombo => 'product_combo',
  };

  String get label => switch (this) {
    TebusMurahMode.minSpend => 'Minimal Belanja',
    TebusMurahMode.productCombo => 'Beli Menu Tertentu',
  };
}

class TebusMurahPromo {
  const TebusMurahPromo({
    required this.id,
    required this.businessId,
    required this.name,
    required this.mode,
    this.minSpendAmount,
    this.triggerMenuItemId,
    required this.rewardMenuItemId,
    required this.specialPrice,
    this.maxQtyPerTransaction = 1,
    required this.startDate,
    required this.endDate,
    this.activeDays,
    this.activeTimeStart,
    this.activeTimeEnd,
    this.quotaLimit,
    this.currentUsageCount = 0,
    this.isActive = true,
    this.triggerItemName,
    this.rewardItemName,
    this.rewardItemPrice,
  });

  final String id;
  final String businessId;
  final String name;
  final TebusMurahMode mode;
  final double? minSpendAmount;
  final String? triggerMenuItemId;
  final String rewardMenuItemId;
  final double specialPrice;
  final int maxQtyPerTransaction;
  final DateTime startDate;
  final DateTime endDate;
  final List<int>? activeDays;
  final String? activeTimeStart;
  final String? activeTimeEnd;
  final int? quotaLimit;
  final int currentUsageCount;
  final bool isActive;
  final String? triggerItemName;
  final String? rewardItemName;
  final double? rewardItemPrice;

  bool isCurrentlyActive() {
    if (!isActive) return false;
    final now = DateTime.now();
    final startLocal = startDate.toLocal();
    final endLocal = endDate.toLocal();

    // Safe comparison: if today's calendar date is on or after start date, promo is active
    final today = DateTime(now.year, now.month, now.day);
    final promoStartDay = DateTime(startLocal.year, startLocal.month, startLocal.day);
    if (today.isBefore(promoStartDay) && now.isBefore(startLocal)) {
      return false;
    }

    final promoEndDay = DateTime(endLocal.year, endLocal.month, endLocal.day, 23, 59, 59);
    if (now.isAfter(promoEndDay) && now.isAfter(endLocal)) {
      return false;
    }

    if (activeDays != null && activeDays!.isNotEmpty) {
      if (!activeDays!.contains(now.weekday)) return false;
    }
    if (quotaLimit != null && quotaLimit! > 0 && currentUsageCount >= quotaLimit!) {
      return false;
    }
    // Time check if defined (HH:mm)
    if (activeTimeStart != null && activeTimeEnd != null) {
      final currentMinutes = now.hour * 60 + now.minute;
      final startParts = activeTimeStart!.split(':');
      final endParts = activeTimeEnd!.split(':');
      if (startParts.length == 2 && endParts.length == 2) {
        final startMin = int.tryParse(startParts[0])! * 60 + int.tryParse(startParts[1])!;
        final endMin = int.tryParse(endParts[0])! * 60 + int.tryParse(endParts[1])!;
        if (currentMinutes < startMin || currentMinutes > endMin) return false;
      }
    }
    return true;
  }

  bool isEligible({
    required double cleanSubtotal,
    required List<String> cartMenuItemIds,
  }) {
    if (!isCurrentlyActive()) return false;
    if (mode == TebusMurahMode.minSpend) {
      final requiredAmount = minSpendAmount ?? 0;
      return cleanSubtotal >= requiredAmount;
    } else {
      // productCombo mode
      if (triggerMenuItemId == null) return false;
      return cartMenuItemIds.contains(triggerMenuItemId);
    }
  }

  factory TebusMurahPromo.fromJson(Map<String, dynamic> json) {
    final triggerItem = json['trigger_item'] is Map<String, dynamic>
        ? json['trigger_item'] as Map<String, dynamic>
        : null;
    final rewardItem = json['reward_item'] is Map<String, dynamic>
        ? json['reward_item'] as Map<String, dynamic>
        : null;

    final rawDays = json['active_days'];
    List<int>? activeDays;
    if (rawDays is List) {
      activeDays = rawDays.map((e) => (e as num).toInt()).toList();
    }

    return TebusMurahPromo(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String,
      mode: TebusMurahMode.fromDb(json['mode'] as String?),
      minSpendAmount: (json['min_spend_amount'] as num?)?.toDouble(),
      triggerMenuItemId: json['trigger_menu_item_id'] as String?,
      rewardMenuItemId: json['reward_menu_item_id'] as String,
      specialPrice: (json['special_price'] as num? ?? 0).toDouble(),
      maxQtyPerTransaction:
          (json['max_qty_per_transaction'] as num? ?? 1).toInt(),
      startDate:
          DateTime.tryParse(json['start_date'] as String? ?? '') ??
          DateTime.now(),
      endDate:
          DateTime.tryParse(json['end_date'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      activeDays: activeDays,
      activeTimeStart: json['active_time_start'] as String?,
      activeTimeEnd: json['active_time_end'] as String?,
      quotaLimit: (json['quota_limit'] as num?)?.toInt(),
      currentUsageCount: (json['current_usage_count'] as num? ?? 0).toInt(),
      isActive: json['is_active'] as bool? ?? true,
      triggerItemName: triggerItem?['name'] as String?,
      rewardItemName: rewardItem?['name'] as String?,
      rewardItemPrice: (rewardItem?['price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'mode': mode.dbValue,
      'min_spend_amount': minSpendAmount,
      'trigger_menu_item_id': triggerMenuItemId,
      'reward_menu_item_id': rewardMenuItemId,
      'special_price': specialPrice,
      'max_qty_per_transaction': maxQtyPerTransaction,
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endDate.toUtc().toIso8601String(),
      'active_days': activeDays,
      'active_time_start': activeTimeStart,
      'active_time_end': activeTimeEnd,
      'quota_limit': quotaLimit,
      'is_active': isActive,
    };
  }
}
