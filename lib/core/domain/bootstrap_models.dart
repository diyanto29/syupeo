import 'package:dpos/features/auth/domain/auth_models.dart' show AppProfile;

import 'app_enums.dart';
import 'business_models.dart';
import 'outlet_models.dart';

class OwnerBootstrap {
  static const _unset = Object();

  const OwnerBootstrap({
    this.profile,
    this.business,
    this.membership,
    this.outlets = const [],
    this.currentOutletId,
  });

  final AppProfile? profile;
  final Business? business;
  final BusinessMember? membership;
  final List<Outlet> outlets;
  final String? currentOutletId;

  bool get isLoggedIn => profile != null;
  AppRole? get effectiveRole => membership?.role ?? profile?.defaultRole;
  bool get canManageCatalog => effectiveRole?.canManageCatalog ?? false;
  bool get needsOwnerOnboarding => profile != null && profile?.defaultRole == AppRole.owner && business == null;
  Outlet? get currentOutlet {
    final id = currentOutletId;
    if (id == null) {
      return outlets.length == 1 ? outlets.first : null;
    }
    for (final outlet in outlets) {
      if (outlet.id == id) {
        return outlet;
      }
    }
    return outlets.length == 1 ? outlets.first : null;
  }

  bool get needsOutletSelection =>
      business != null && outlets.length > 1 && currentOutlet == null;

  Map<String, dynamic> toMap() {
    return {
      'profile': profile?.toMap(),
      'business': business?.toMap(),
      'membership': membership?.toMap(),
      'outlets': outlets.map((item) => item.toMap()).toList(),
      'current_outlet_id': currentOutletId,
    };
  }

  factory OwnerBootstrap.fromMap(Map<String, dynamic> json) {
    return OwnerBootstrap(
      profile: json['profile'] == null
          ? null
          : AppProfile.fromMap(
              Map<String, dynamic>.from(json['profile'] as Map),
            ),
      business: json['business'] == null
          ? null
          : Business.fromMap(
              Map<String, dynamic>.from(json['business'] as Map),
            ),
      membership: json['membership'] == null
          ? null
          : BusinessMember.fromMap(
              Map<String, dynamic>.from(json['membership'] as Map),
            ),
      outlets: (json['outlets'] as List<dynamic>? ?? const [])
          .map((item) => Outlet.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      currentOutletId: json['current_outlet_id'] as String?,
    );
  }

  OwnerBootstrap copyWith({
    AppProfile? profile,
    Business? business,
    BusinessMember? membership,
    List<Outlet>? outlets,
    Object? currentOutletId = _unset,
  }) {
    return OwnerBootstrap(
      profile: profile ?? this.profile,
      business: business ?? this.business,
      membership: membership ?? this.membership,
      outlets: outlets ?? this.outlets,
      currentOutletId: identical(currentOutletId, _unset)
          ? this.currentOutletId
          : currentOutletId as String?,
    );
  }
}
