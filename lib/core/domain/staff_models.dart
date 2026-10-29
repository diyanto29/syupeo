import 'package:dpos/core/domain/app_enums.dart';
import 'package:dpos/core/domain/business_models.dart';
import 'package:dpos/features/auth/domain/auth_models.dart' show AppProfile;

class BusinessUser {
  const BusinessUser.member({required this.membership, this.profile})
    : invitation = null;

  const BusinessUser.invitation({required this.invitation, this.profile})
    : membership = null;

  final BusinessMember? membership;
  final StaffInvitation? invitation;
  final AppProfile? profile;

  String get entryId => membership?.id ?? invitation!.id;

  String get businessId => membership?.businessId ?? invitation!.businessId;

  AppRole get role => membership?.role ?? invitation!.role;

  String get status => membership?.status ?? invitation!.status;

  String? get fullName => profile?.fullName ?? invitation?.fullName;

  String? get staffCode => profile?.staffCode ?? invitation?.staffCode;

  String get displayName {
    final profileName = profile?.fullName?.trim();
    if (profileName != null && profileName.isNotEmpty) {
      return profileName;
    }
    final invitationName = invitation?.fullName?.trim();
    if (invitationName != null && invitationName.isNotEmpty) {
      return invitationName;
    }
    final email = profile?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }
    final invitationEmail = invitation?.email?.trim();
    if (invitationEmail != null && invitationEmail.isNotEmpty) {
      return invitationEmail;
    }
    final sourceId = membership?.userId ?? invitation?.staffCode ?? 'user';
    final shortId = sourceId.length >= 6 ? sourceId.substring(0, 6) : sourceId;
    return 'User ${shortId.toUpperCase()}';
  }

  String get identityLabel {
    final staffCode = profile?.staffCode?.trim();
    if (staffCode != null && staffCode.isNotEmpty) {
      return 'ID: ${staffCode.toUpperCase()}';
    }

    final invitationStaffCode = invitation?.staffCode.trim();
    if (invitationStaffCode != null && invitationStaffCode.isNotEmpty) {
      return 'ID: ${invitationStaffCode.toUpperCase()}';
    }

    final userId = membership?.userId ?? '';
    final shortId = userId.length >= 8
        ? userId.substring(0, 8).toUpperCase()
        : userId.toUpperCase();
    return 'ID: $shortId';
  }

  String? get email => profile?.email ?? invitation?.email;

  String? get avatarUrl => profile?.avatarUrl ?? invitation?.avatarUrl;

  bool get isActive => status == 'active';

  bool get isInvitation => invitation != null;

  bool get isOwner => role == AppRole.owner;
}

class StaffInvitation {
  const StaffInvitation({
    required this.id,
    required this.businessId,
    required this.staffCode,
    this.fullName,
    this.email,
    this.avatarUrl,
    required this.role,
    required this.status,
  });

  final String id;
  final String businessId;
  final String staffCode;
  final String? fullName;
  final String? email;
  final String? avatarUrl;
  final AppRole role;
  final String status;

  factory StaffInvitation.fromMap(Map<String, dynamic> json) {
    return StaffInvitation(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      staffCode: json['staff_code'] as String,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: AppRole.fromValue(json['role'] as String?),
      status: (json['status'] as String?) ?? 'invited',
    );
  }
}
