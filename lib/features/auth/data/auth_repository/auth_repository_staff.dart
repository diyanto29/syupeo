part of '../auth_repository.dart';

extension AuthRepositoryStaffContext on AuthRepository {
  Future<bool> isStaffCodeTaken(String staffCode) async {
    final code = staffCode.trim();
    if (code.isEmpty) return false;

    // Check staff_invitations
    final invitation = await _client
        .from('staff_invitations')
        .select('id')
        .eq('staff_code', code)
        .maybeSingle();

    if (invitation != null) return true;

    // Check profiles
    final profile = await _client
        .from('profiles')
        .select('id')
        .eq('staff_code', code)
        .maybeSingle();

    return profile != null;
  }

  Future<List<AppProfile>> searchProfiles(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    // Search by full_name, email, or staff_code
    final response = await _client
        .from('profiles')
        .select()
        .or('full_name.ilike.%$trimmedQuery%,email.ilike.%$trimmedQuery%,staff_code.ilike.%$trimmedQuery%')
        .limit(10);

    return (response as List)
        .map((item) => AppProfile.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<BusinessUser>> fetchBusinessUsers(String businessId) async {
    final memberResponse = await _client
        .from('business_members')
        .select('id, business_id, user_id, role, status, profiles:user_id(*)')
        .eq('business_id', businessId)
        .order('created_at', ascending: true);

    final users = memberResponse.map((item) {
      final json = Map<String, dynamic>.from(item as Map);
      final profileJson = json['profiles'];
      return BusinessUser.member(
        membership: BusinessMember.fromMap(json),
        profile: profileJson == null
            ? null
            : AppProfile.fromMap(Map<String, dynamic>.from(profileJson as Map)),
      );
    }).toList();

    final invitationResponse = await _client
        .from('staff_invitations')
        .select()
        .eq('business_id', businessId)
        .order('created_at', ascending: true);

    users.addAll(
      invitationResponse.map(
        (item) => BusinessUser.invitation(
          invitation: StaffInvitation.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
    );

    return users;
  }

  Future<Map<String, dynamic>> upsertBusinessStaffEntry({
    required String businessId,
    required String identifier,
    required AppRole role,
    required String status,
    String? fullName,
    String? avatarUrl,
    String? staffCode,
    String? initialPassword,
  }) async {
    final response = await _client.rpc(
      'upsert_business_staff_entry',
      params: {
        'target_business_id': businessId,
        'target_identifier': identifier.trim(),
        'target_role': role.name,
        'target_status': status,
        'target_full_name': fullName,
        'target_avatar_url': avatarUrl,
        'target_staff_code': staffCode?.trim(),
        'target_initial_password': initialPassword,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> updateBusinessStaffEntry({
    required String businessId,
    required String entryId,
    required bool isInvitation,
    required AppRole role,
    required String status,
    String? fullName,
    String? avatarUrl,
    String? staffCode,
    String? initialPassword,
  }) async {
    final response = await _client.rpc(
      'update_business_staff_entry',
      params: {
        'target_business_id': businessId,
        'target_entry_id': entryId,
        'target_kind': isInvitation ? 'invitation' : 'member',
        'target_role': role.name,
        'target_status': status,
        'target_full_name': fullName,
        'target_avatar_url': avatarUrl,
        'target_staff_code': staffCode?.trim(),
        'target_initial_password': initialPassword,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> deleteBusinessStaffEntry({
    required String businessId,
    required String entryId,
    required bool isInvitation,
  }) async {
    await _client.rpc(
      'delete_business_staff_entry',
      params: {
        'target_business_id': businessId,
        'target_entry_id': entryId,
        'target_kind': isInvitation ? 'invitation' : 'member',
      },
    );
  }

  Future<String> uploadStaffAvatar({
    required String identifier,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final sanitizedIdentifier = identifier.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '_',
    );
    final mimeType =
        lookupMimeType(fileName, headerBytes: bytes) ??
        'application/octet-stream';
    final extension = _extractFileExtension(fileName, mimeType);
    final objectPath =
        '$sanitizedIdentifier/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage
        .from('staff-avatars')
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: mimeType),
        );

    return _client.storage.from('staff-avatars').getPublicUrl(objectPath);
  }

  String _extractFileExtension(String fileName, String mimeType) {
    final normalized = fileName.toLowerCase().trim();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < normalized.length - 1) {
      return normalized.substring(dotIndex + 1);
    }

    switch (mimeType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/heic':
        return 'heic';
      case 'image/heif':
        return 'heif';
      case 'image/gif':
        return 'gif';
      case 'image/bmp':
        return 'bmp';
      case 'image/tiff':
        return 'tiff';
      case 'image/jpeg':
      default:
        return 'jpg';
    }
  }
}
