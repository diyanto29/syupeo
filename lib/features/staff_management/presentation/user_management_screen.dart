import 'dart:async';
import 'dart:developer';

import 'package:dpos/core/routes/routes_name.dart';
import 'package:dpos/core/theme/app_theme.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/widgets/app_tablet_nav.dart';
import 'package:dpos/core/widgets/syupeo_shimmer.dart';
import 'package:dpos/features/auth/data/auth_repository.dart';
import 'package:dpos/features/auth/domain/auth_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

final businessUsersProvider = FutureProvider.autoDispose<List<BusinessUser>>((
  ref,
) async {
  final bootstrap = await ref.watch(homeBootstrapProvider.future);
  final business = bootstrap.business;
  if (business == null) {
    return const [];
  }

  return ref.read(authRepositoryProvider).fetchBusinessUsers(business.id);
});

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppOwnerDrawer(),
      appBar: const _UserManagementAppBar(),
      body: const SafeArea(child: UserManagementView()),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await context.pushNamed<bool>(RouteNames.addUser);
          if (created == true) {
            ref.invalidate(businessUsersProvider);
          }
        },
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
    );
  }
}

class UserManagementView extends ConsumerStatefulWidget {
  const UserManagementView({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  ConsumerState<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends ConsumerState<UserManagementView> {
  final _searchController = TextEditingController();
  AppRole? _selectedRole;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final usersAsync = ref.watch(businessUsersProvider);

    return usersAsync.when(
      data: (users) {
        final filteredUsers = _filterUsers(users);
        final stats = _UserStats.fromUsers(users);

        return ListView(
          padding: widget.padding ?? const EdgeInsets.fromLTRB(14, 8, 14, 24),
          children: [
            _StatsCard(stats: stats),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari nama staf atau ID user...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _RoleFilterChip(
                    label: 'Semua',
                    selected: _selectedRole == null,
                    onTap: () => setState(() => _selectedRole = null),
                  ),
                  const SizedBox(width: 8),
                  for (final role in const [
                    AppRole.waiter,
                    AppRole.kitchen,
                    AppRole.cashier,
                    AppRole.admin,
                    AppRole.owner,
                  ]) ...[
                    _RoleFilterChip(
                      label: _roleLabel(role, ref),
                      selected: _selectedRole == role,
                      onTap: () => setState(() => _selectedRole = role),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (filteredUsers.isEmpty)
              _EmptyUserState(selectedRole: _selectedRole)
            else
              ...filteredUsers.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _UserCard(user: user),
                ),
              ),
            if (users.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Data role dan status diambil langsung dari membership bisnis aktif.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.64),
                ),
              ),
            ],
          ],
        );
      },
      error: (error, _) =>
          Center(child: Text('Gagal memuat anggota tim: $error')),
      loading: () => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: const [
          GeneralCardSkeleton(),
          GeneralCardSkeleton(),
          GeneralCardSkeleton(),
        ],
      ),
    );
  }

  List<BusinessUser> _filterUsers(List<BusinessUser> users) {
    final query = _searchController.text.trim().toLowerCase();

    return users.where((user) {
      final roleMatch = _selectedRole == null || user.role == _selectedRole;
      if (!roleMatch) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return user.displayName.toLowerCase().contains(query) ||
          user.identityLabel.toLowerCase().contains(query) ||
          _roleLabel(user.role, ref).toLowerCase().contains(query);
    }).toList();
  }
}

class _UserManagementAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _UserManagementAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.sizeOf(context).width >= 600;
    if (isTablet) {
      return const AppTabletHeader(
        title: Text('Manajemen Staf'),
        badge: AppTabletBadge(label: 'Syupeo'),
      );
    }
    return AppBar(
      title: const Text('Manajemen Staf'),
    );
  }
}

class AddUserPage extends ConsumerStatefulWidget {
  const AddUserPage({super.key, this.initialUser});

  final BusinessUser? initialUser;

  @override
  ConsumerState<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends ConsumerState<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _picker = ImagePicker();
  AppRole _selectedRole = AppRole.admin;
  String _selectedStatus = 'active';
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  XFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;
  bool _isPickingPhoto = false;

  final _staffIdFocusNode = FocusNode();
  bool _isStaffIdChecking = false;
  String? _staffIdRemoteError;
  bool? _isStaffIdAvailable;
  Timer? _staffIdDebounce;

  bool get _isEditMode => widget.initialUser != null;

  @override
  void initState() {
    super.initState();
    final user = widget.initialUser;
    if (user == null) {
      return;
    }

    _fullNameController.text = user.fullName ?? '';
    _emailController.text = user.staffCode ?? '';
    _selectedRole = user.role;
    _selectedStatus = user.status;

    _staffIdFocusNode.addListener(_onStaffIdFocusChange);
  }

  void _onStaffIdFocusChange() {
    if (!_staffIdFocusNode.hasFocus) {
      _checkStaffIdAvailability();
    }
  }

  Future<void> _checkStaffIdAvailability() async {
    final staffId = _emailController.text.trim();
    if (staffId.isEmpty || staffId.length < 3) {
      setState(() {
        _isStaffIdAvailable = null;
        _staffIdRemoteError = null;
      });
      return;
    }

    // Skip check if it's the same as initial user ID during edit
    if (_isEditMode && staffId == widget.initialUser?.staffCode) {
      setState(() {
        _isStaffIdAvailable = true;
        _staffIdRemoteError = null;
      });
      return;
    }

    setState(() {
      _isStaffIdChecking = true;
      _staffIdRemoteError = null;
      _isStaffIdAvailable = null;
    });

    try {
      final isTaken = await ref
          .read(authRepositoryProvider)
          .isStaffCodeTaken(staffId);
      if (!mounted) return;

      setState(() {
        _isStaffIdAvailable = !isTaken;
        if (isTaken) {
          _staffIdRemoteError = 'Staff ID sudah digunakan pada sistem ini';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _staffIdRemoteError = 'Gagal mengecek ketersediaan ID';
      });
    } finally {
      if (mounted) {
        setState(() => _isStaffIdChecking = false);
      }
    }
  }

  Future<void> _generateStaffId() async {
    setState(() => _isStaffIdChecking = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      String newId = '';
      bool isTaken = true;
      int attempts = 0;

      while (isTaken && attempts < 5) {
        final random = DateTime.now().millisecondsSinceEpoch
            .toString()
            .substring(8);
        newId = 'STF$random';
        isTaken = await repository.isStaffCodeTaken(newId);
        attempts++;
      }

      if (!mounted) return;
      _emailController.text = newId;
      setState(() {
        _isStaffIdAvailable = true;
        _staffIdRemoteError = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isStaffIdChecking = false);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _staffIdFocusNode.removeListener(_onStaffIdFocusChange);
    _staffIdFocusNode.dispose();
    _staffIdDebounce?.cancel();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_isPickingPhoto) {
      return;
    }

    setState(() => _isPickingPhoto = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) {
        return;
      }

      final length = await file.length();
      if (length > 2 * 1024 * 1024) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ukuran foto maksimal 2MB. Pilih file yang lebih kecil.',
            ),
          ),
        );
        return;
      }

      final bytes = await file.readAsBytes();

      if (!mounted) {
        return;
      }
      setState(() {
        _selectedPhoto = file;
        _selectedPhotoBytes = bytes;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memilih foto: $error')));
    } finally {
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Final check for Staff ID availability
      final staffId = _emailController.text.trim();
      if (_isStaffIdAvailable == null || _staffIdRemoteError != null) {
        final isTaken = await ref
            .read(authRepositoryProvider)
            .isStaffCodeTaken(staffId);
        if (isTaken &&
            !(_isEditMode && staffId == widget.initialUser?.staffCode)) {
          setState(() {
            _isStaffIdAvailable = false;
            _staffIdRemoteError = 'Staff ID sudah digunakan pada sistem ini';
            _isSubmitting = false;
          });
          if (_formKey.currentState!.validate()) {} // Trigger UI refresh
          return;
        }
      }

      final bootstrap = await ref.read(homeBootstrapProvider.future);
      final business = bootstrap.business;
      if (business == null) {
        throw StateError('Bisnis belum tersedia untuk tambah user.');
      }

      String? avatarUrl;
      if (_selectedPhoto != null && _selectedPhotoBytes != null) {
        avatarUrl = await ref
            .read(authRepositoryProvider)
            .uploadStaffAvatar(
              identifier: _emailController.text.trim(),
              bytes: _selectedPhotoBytes!,
              fileName: _selectedPhoto!.name,
            );
      }

      final repository = ref.read(authRepositoryProvider);
      if (_isEditMode) {
        await repository.updateBusinessStaffEntry(
          businessId: business.id,
          entryId: widget.initialUser!.entryId,
          isInvitation: widget.initialUser!.isInvitation,
          fullName: _fullNameController.text.trim(),
          role: _selectedRole,
          status: _selectedStatus,
          avatarUrl: avatarUrl,
          staffCode: _emailController.text.trim(),
          initialPassword: _passwordController.text.isEmpty
              ? null
              : _passwordController.text,
        );
      } else {
        await repository.upsertBusinessStaffEntry(
          businessId: business.id,
          identifier: _emailController.text.trim(),
          fullName: _fullNameController.text.trim(),
          role: _selectedRole,
          status: _selectedStatus,
          avatarUrl: avatarUrl,
          staffCode: _emailController.text.trim(),
          initialPassword: _passwordController.text.isEmpty
              ? null
              : _passwordController.text,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Perubahan staff berhasil disimpan.'
                : 'Data staff berhasil disimpan ke bisnis.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = _isEditMode
          ? _resolveStaffActionError(error)
          : _resolveAddUserError(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<ConciergeThemeTokens>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final isTablet = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const AppOwnerDrawer(),
      appBar: isTablet
          ? AppTabletHeader(
              title: Text(_isEditMode ? 'Edit Pengguna' : 'Tambah Pengguna Baru'),
              badge: const AppTabletBadge(label: 'Syupeo'),
            )
          : AppBar(
              title: Text(_isEditMode ? 'Edit Pengguna' : 'Tambah Pengguna Baru'),
            ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                _SheetSectionTitle(title: 'Informasi Personal'),
                const SizedBox(height: 18),
                Center(
                  child: Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _isSubmitting ? null : _pickPhoto,
                        child: Container(
                          width: 118,
                          height: 136,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: scheme.outline.withValues(alpha: 0.34),
                              style: BorderStyle.solid,
                            ),
                            image: _selectedPhotoBytes == null
                                ? widget.initialUser?.avatarUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            widget.initialUser!.avatarUrl!,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null
                                : DecorationImage(
                                    image: MemoryImage(_selectedPhotoBytes!),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          child:
                              _selectedPhotoBytes == null &&
                                  widget.initialUser?.avatarUrl == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      color: scheme.secondary,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      _isPickingPhoto
                                          ? 'MEMUAT...'
                                          : 'UNGGAH FOTO\nPROFIL',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: scheme.secondary,
                                            letterSpacing: 0.8,
                                          ),
                                    ),
                                  ],
                                )
                              : Stack(
                                  children: [
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.52,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.edit_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'FORMAT FOTO DIPROSES OTOMATIS (MAKS 2MB)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 0.9,
                          color: scheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _FieldLabel(label: 'Nama Lengkap', isRequired: true),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: Budi Santoso',
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(50),
                    FilteringTextInputFormatter.allow(
                      RegExp(r"[a-zA-Z\s\.\,\']"),
                    ),
                  ],
                  validator: (value) {
                    final trimmedValue = (value ?? '').trim();
                    if (trimmedValue.isEmpty) {
                      return 'Nama lengkap wajib diisi';
                    }
                    if (trimmedValue.length < 3) {
                      return 'Nama terlalu pendek (min. 3 karakter)';
                    }
                    // Basic SQL Injection / XSS prevention by character whitelisting via formatter,
                    // but we add a secondary check here for extra safety.
                    if (!RegExp(
                      r"^[a-zA-Z\s\.\,\']+$",
                    ).hasMatch(trimmedValue)) {
                      return 'Nama mengandung karakter yang tidak diizinkan';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9EFFD),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_rounded,
                        color: scheme.secondary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pastikan nama sesuai dengan tanda pengenal resmi untuk keperluan penggajian.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                _SheetSectionTitle(title: 'Detail Pekerjaan'),
                const SizedBox(height: 18),
                _FieldLabel(label: 'Pilih Peran (Role)'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final role in const [
                      AppRole.admin,
                      AppRole.cashier,
                    ]) ...[
                      Expanded(
                        child: _RoleOptionCard(
                          role: role,
                          selected: _selectedRole == role,
                          onTap: _isSubmitting
                              ? null
                              : () => setState(() => _selectedRole = role),
                        ),
                      ),
                      if (role != AppRole.cashier) const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final role in const [
                      AppRole.waiter,
                      AppRole.kitchen,
                    ]) ...[
                      Expanded(
                        child: _RoleOptionCard(
                          role: role,
                          selected: _selectedRole == role,
                          onTap: _isSubmitting
                              ? null
                              : () => setState(() => _selectedRole = role),
                        ),
                      ),
                      if (role != AppRole.kitchen) const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _FieldLabel(label: 'Staff ID'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  focusNode: _staffIdFocusNode,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Contoh: ID12345',
                    suffixIcon: _isStaffIdChecking
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _isStaffIdAvailable == true
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : _isStaffIdAvailable == false
                        ? const Icon(Icons.error, color: Colors.red)
                        : null,
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(20),
                    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9]")),
                  ],
                  onChanged: (val) {
                    if (_isStaffIdAvailable != null) {
                      setState(() => _isStaffIdAvailable = null);
                    }
                    _staffIdDebounce?.cancel();
                    _staffIdDebounce = Timer(
                      const Duration(milliseconds: 500),
                      () {
                        _checkStaffIdAvailability();
                      },
                    );
                  },
                  validator: (value) {
                    final staffId = (value ?? '').trim();
                    if (staffId.isEmpty) {
                      return 'Staff ID wajib diisi';
                    }
                    if (staffId.length < 3) {
                      return 'Staff ID minimal 3 karakter';
                    }
                    if (!RegExp(r"^[a-zA-Z0-9]+$").hasMatch(staffId)) {
                      return 'Staff ID hanya boleh berisi huruf dan angka';
                    }
                    if (_staffIdRemoteError != null) {
                      return _staffIdRemoteError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _isStaffIdChecking ? null : _generateStaffId,
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: const Text('Rekomendasi ID'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: scheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _isEditMode
                      ? 'Staff ID akan dipakai untuk memperbarui data staff yang dipilih.'
                      : 'Staff ID adalah identitas unik yang akan digunakan staff untuk masuk ke sistem.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 26),
                _SheetSectionTitle(title: 'Keamanan & Akses'),
                const SizedBox(height: 18),
                _FieldLabel(label: 'Kata Sandi Awal'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value != null && value.isNotEmpty && value.length < 6) {
                      return 'Password minimal 6 karakter';
                    }
                    if (!_isEditMode && (value == null || value.isEmpty)) {
                      return 'Password wajib diisi untuk user baru';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Min. 6 Karakter',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isEditMode
                      ? 'Isi password hanya jika ingin mengganti password invitation untuk staff yang belum claim akun.'
                      : 'Field password disiapkan untuk flow akun baru. Pada build ini, user tetap harus sudah terdaftar di sistem.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 14),
                _FieldLabel(label: 'Status Membership'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'invited', child: Text('Invited')),
                    DropdownMenuItem(
                      value: 'disabled',
                      child: Text('Disabled'),
                    ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() => _selectedStatus = value);
                        },
                ),
                const SizedBox(height: 26),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient:
                        tokens?.ctaGradient ??
                        const LinearGradient(
                          colors: [Color(0xFFFF8C00), Color(0xFFCE7000)],
                        ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          (_isSubmitting ||
                              _isStaffIdChecking ||
                              _isStaffIdAvailable == false)
                          ? null
                          : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                      ),
                      child: Text(
                        _isSubmitting
                            ? 'Menyimpan...'
                            : _isEditMode
                            ? 'Simpan Perubahan'
                            : 'Simpan Pengguna',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolveAddUserError(Object error) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();

    if (normalized.contains('target_identifier') ||
        normalized.contains('upsert_business_staff_entry') ||
        normalized.contains('staff_invitations') ||
        normalized.contains(
          'could not find the function public.upsert_business_staff_entry',
        )) {
      return 'Fitur staff invitation belum sinkron di database. Jalankan migration Supabase terbaru terlebih dahulu.';
    }

    if (normalized.contains('duplicate key') ||
        normalized.contains('profiles_staff_code_unique_idx')) {
      return 'Staff ID ini sudah dipakai user lain.';
    }

    if (normalized.contains('gen_salt') ||
        normalized.contains('crypt(') ||
        normalized.contains('pgcrypto')) {
      return 'Database staff auth belum sinkron. Jalankan migration Supabase terbaru untuk mengaktifkan hashing password staff.';
    }

    return 'Gagal menambahkan user: $raw';
  }
}

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: theme.textTheme.headlineSmall),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.isRequired = false});

  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          text: label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
            letterSpacing: -0.2,
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleOptionCard extends ConsumerWidget {
  const _RoleOptionCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final AppRole role;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (role) {
      AppRole.admin => Icons.admin_panel_settings_outlined,
      AppRole.waiter => Icons.room_service_outlined,
      AppRole.kitchen => Icons.soup_kitchen_outlined,
      AppRole.cashier => Icons.point_of_sale_outlined,
      _ => Icons.badge_outlined,
    };

    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? scheme.secondary : scheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(height: 8),
              Text(
                _roleLabel(role, ref).toUpperCase(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? scheme.secondary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final BusinessUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<ConciergeThemeTokens>();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (tokens?.tintedShadow ?? Colors.black12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.secondaryContainer,
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.displayName.characters.first.toUpperCase(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.secondary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      user.identityLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.58),
                      ),
                    ),
                    if (user.email != null &&
                        user.email!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.email!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionIcon(
                    icon: Icons.edit_outlined,
                    color: const Color(0xFF8A96AE),
                    onTap: user.isOwner
                        ? null
                        : () async {
                            final updated = await Navigator.of(context).push(
                              MaterialPageRoute<bool>(
                                builder: (_) => AddUserPage(initialUser: user),
                              ),
                            );
                            if (updated == true && context.mounted) {
                              ProviderScope.containerOf(
                                context,
                              ).invalidate(businessUsersProvider);
                            }
                          },
                  ),
                  const SizedBox(width: 4),
                  _ActionIcon(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFE08C84),
                    onTap: user.isOwner
                        ? null
                        : () => _confirmDeleteUser(context, user),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _RoleBadge(role: user.role),
              const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: user.isActive
                      ? const Color(0xFF76D672)
                      : const Color(0xFFE0A64B),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                user.isActive ? 'Aktif' : user.status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteUser(
    BuildContext context,
    BusinessUser user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Staff'),
          content: Text(
            'Hapus ${user.displayName} dari staff management? Tindakan ini akan menghapus ${user.isInvitation ? 'invitation' : 'membership'} dari bisnis.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const _StaffActionLoadingDialog(message: 'Menghapus staff...'),
    );

    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final bootstrap = await container.read(homeBootstrapProvider.future);
      final business = bootstrap.business;
      if (business == null) {
        throw StateError('Bisnis tidak ditemukan.');
      }

      await container
          .read(authRepositoryProvider)
          .deleteBusinessStaffEntry(
            businessId: business.id,
            entryId: user.entryId,
            isInvitation: user.isInvitation,
          );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        container.invalidate(businessUsersProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.displayName} berhasil dihapus dari bisnis.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_resolveStaffActionError(error, isDelete: true)),
          ),
        );
      }
    }
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? color.withValues(alpha: 0.35) : color,
        ),
      ),
    );
  }
}

class _StaffActionLoadingDialog extends StatelessWidget {
  const _StaffActionLoadingDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

String _resolveStaffActionError(Object error, {bool isDelete = false}) {
  final raw = error.toString();
  final normalized = raw.toLowerCase();

  if (normalized.contains('update_business_staff_entry') ||
      normalized.contains('delete_business_staff_entry')) {
    return 'Fitur edit/hapus staff belum sinkron di database. Jalankan migration Supabase terbaru terlebih dahulu.';
  }

  if (normalized.contains('owner utama tidak bisa dihapus') ||
      normalized.contains('owner utama tidak bisa diubah')) {
    return isDelete
        ? 'Akun owner utama tidak bisa dihapus dari bisnis.'
        : 'Akun owner utama tidak bisa diubah dari halaman ini.';
  }

  return isDelete
      ? 'Gagal menghapus user: $raw'
      : 'Gagal menyimpan perubahan: $raw';
}

class _RoleBadge extends ConsumerWidget {
  const _RoleBadge({required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = switch (role) {
      AppRole.waiter => const Color(0xFFFFA74A),
      AppRole.kitchen => const Color(0xFF7D8FB4),
      AppRole.cashier => const Color(0xFF62A978),
      AppRole.admin => const Color(0xFF7B65C9),
      AppRole.owner => const Color(0xFF3A2412),
      AppRole.customer => const Color(0xFF7A869A),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _roleLabel(role, ref).toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RoleFilterChip extends StatelessWidget {
  const _RoleFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? scheme.surfaceContainerLowest
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? scheme.onSurface : scheme.secondary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final _UserStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF220A00), Color(0xFF3A1806), Color(0xFF5B2B00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistik Tim',
            style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Overview performa staf bisnis',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatsMetric(
                  label: 'Total staf',
                  value: stats.total.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatsMetric(
                  label: 'Aktif sekarang',
                  value: stats.active.toString(),
                  highlight: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatsMetric(
                  label: 'Tim dapur',
                  value: stats.kitchen.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsMetric extends StatelessWidget {
  const _StatsMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: highlight ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: highlight ? const Color(0xFFFFA94D) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyUserState extends ConsumerWidget {
  const _EmptyUserState({required this.selectedRole});

  final AppRole? selectedRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.groups_rounded, size: 40, color: scheme.secondary),
          const SizedBox(height: 12),
          Text(
            'Belum ada user untuk filter ini',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            selectedRole == null
                ? 'Saat ini baru membership yang tersedia yang akan muncul di halaman ini.'
                : 'Belum ada anggota dengan role ${_roleLabel(selectedRole!, ref)}.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.68),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _UserStats {
  const _UserStats({
    required this.total,
    required this.active,
    required this.kitchen,
  });

  final int total;
  final int active;
  final int kitchen;

  factory _UserStats.fromUsers(List<BusinessUser> users) {
    return _UserStats(
      total: users.length,
      active: users.where((user) => user.isActive).length,
      kitchen: users.where((user) => user.role == AppRole.kitchen).length,
    );
  }
}

String _roleLabel(AppRole role, [WidgetRef? ref]) {
  final defaultLabel = switch (role) {
    AppRole.owner => 'Owner',
    AppRole.admin => 'Admin',
    AppRole.cashier => 'Cashier',
    AppRole.waiter => 'Waiter',
    AppRole.kitchen => 'Kitchen',
    AppRole.customer => 'Customer',
  };

  if (ref == null) return defaultLabel;
  final roleLabels = ref
      .read(homeBootstrapProvider)
      .valueOrNull
      ?.business
      ?.roleLabels;
  log(roleLabels.toString());
  if (roleLabels == null || roleLabels.isEmpty) return defaultLabel;
  return roleLabels[role.name] ?? defaultLabel;
}
