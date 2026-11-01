part of '../auth_repository.dart';

extension AuthRepositoryAuthContext on AuthRepository {
  Future<void> signInWithGoogle() async {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);

    if (isDesktop) {
      debugPrint(
        '[GoogleSignIn] Desktop platform detected, starting local callback server on port 3000...',
      );

      HttpServer? server;
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);
        debugPrint(
          '[GoogleSignIn] Local HTTP server listening on http://localhost:3000',
        );
      } catch (e) {
        debugPrint('[GoogleSignIn] Note: Could not bind port 3000: $e');
      }

      final completer = Completer<Uri>();

      server?.listen((HttpRequest request) async {
        final uri = request.uri;
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write('''
            <!DOCTYPE html>
            <html lang="id">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>Login Berhasil</title>
              <style>
                body {
                  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  height: 100vh;
                  margin: 0;
                  background: #0f172a;
                  color: white;
                }
                .card {
                  background: #1e293b;
                  padding: 40px 48px;
                  border-radius: 20px;
                  box-shadow: 0 10px 30px rgba(0,0,0,0.3);
                  text-align: center;
                  max-width: 400px;
                }
                .icon {
                  font-size: 52px;
                  margin-bottom: 16px;
                  color: #22c55e;
                }
                h1 {
                  font-size: 24px;
                  margin: 0 0 12px 0;
                  color: #f8fafc;
                }
                p {
                  font-size: 15px;
                  color: #94a3b8;
                  margin: 0 0 24px 0;
                  line-height: 1.5;
                }
                .btn {
                  display: inline-block;
                  background: #f97316;
                  color: white;
                  padding: 12px 24px;
                  border-radius: 12px;
                  font-weight: 600;
                  text-decoration: none;
                  cursor: pointer;
                  border: none;
                  font-size: 14px;
                }
              </style>
            </head>
            <body>
              <div class="card">
                <div class="icon">✓</div>
                <h1>Login Berhasil!</h1>
                <p>Otentikasi Google berhasil. Anda dapat kembali ke aplikasi Syupeo sekarang.</p>
                <button class="btn" onclick="window.close()">Tutup Jendela Ini</button>
              </div>
              <script>setTimeout(function(){ window.close(); }, 2500);</script>
            </body>
            </html>
          ''');
        await request.response.close();

        if (!completer.isCompleted) {
          completer.complete(uri);
        }
      });

      try {
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'http://localhost:3000',
          authScreenLaunchMode: LaunchMode.externalApplication,
        );

        final callbackUri = await completer.future.timeout(
          const Duration(minutes: 5),
          onTimeout: () =>
              throw TimeoutException('Waktu login di browser telah habis.'),
        );

        debugPrint('[GoogleSignIn] Received callback URI: $callbackUri');
        final code = callbackUri.queryParameters['code'];
        if (code != null && code.isNotEmpty) {
          await _client.auth.exchangeCodeForSession(code);
        } else {
          await _client.auth.getSessionFromUrl(callbackUri);
        }
        await fetchCurrentProfile();
      } catch (error, stackTrace) {
        debugPrint('[GoogleSignIn] Desktop OAuth failed=$error');
        debugPrintStack(
          label: '[GoogleSignIn] stackTrace',
          stackTrace: stackTrace,
        );
        rethrow;
      } finally {
        await server?.close(force: true);
      }
      return;
    }

    debugPrint('[GoogleSignIn] start');
    debugPrint(
      '[GoogleSignIn] hasWebClientId=${SupabaseConfig.hasGoogleWebClientId}',
    );
    debugPrint(
      '[GoogleSignIn] webClientId=${SupabaseConfig.googleWebClientId}',
    );

    if (!SupabaseConfig.hasGoogleWebClientId) {
      throw StateError(
        'GOOGLE_WEB_CLIENT_ID belum diisi. Pakai Web client ID dari Google Cloud '
        'agar idToken tersedia untuk Supabase signInWithIdToken().',
      );
    }

    try {
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
        }
      } catch (e) {
        debugPrint('[GoogleSignIn] clean session check non-fatal: $e');
      }

      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GoogleSignIn] cancelled by user');
        throw StateError('Login Google dibatalkan user.');
      }

      debugPrint('[GoogleSignIn] account.email=${account.email}');
      debugPrint('[GoogleSignIn] account.id=${account.id}');

      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      debugPrint('[GoogleSignIn] idToken.exists=${idToken != null}');
      debugPrint('[GoogleSignIn] idToken.length=${idToken?.length ?? 0}');
      debugPrint('[GoogleSignIn] accessToken.exists=${accessToken != null}');
      debugPrint(
        '[GoogleSignIn] accessToken.length=${accessToken?.length ?? 0}',
      );

      if (idToken == null || idToken.isEmpty) {
        throw StateError(
          'Google ID token tidak tersedia. Biasanya ini terjadi karena '
          'serverClientId belum memakai Web client ID Google yang benar.',
        );
      }

      debugPrint('[GoogleSignIn] exchanging token with Supabase');
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      debugPrint('[GoogleSignIn] supabase.user=${response.user?.id ?? 'null'}');
      debugPrint('[GoogleSignIn] supabase.session=${response.session != null}');

      // Pastikan profil user sudah siap di database sebelum menyelesaikan auth
      await fetchCurrentProfile();
    } catch (error, stackTrace) {
      debugPrint('[GoogleSignIn] failed=$error');
      debugPrintStack(
        label: '[GoogleSignIn] stackTrace',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (!isDesktop) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
  }

  Future<void> signInWithStaffCredentials({
    required String identifier,
    required String password,
  }) async {
    final trimmedIdentifier = identifier.trim();
    final isEmail = trimmedIdentifier.contains('@');

    // 1. If user entered an email, try direct Supabase Auth first
    if (isEmail) {
      try {
        await _client.auth.signInWithPassword(
          email: trimmedIdentifier,
          password: password,
        );
        return;
      } catch (directSignInError) {
        // Direct email login failed, continue with invitation claim flow below
      }
    }

    final normalizedIdentifier = _normalizedStaffIdentifier(identifier);
    final syntheticEmail = isEmail
        ? normalizedIdentifier
        : _staffSyntheticEmail(normalizedIdentifier);

    try {
      await _client.auth.signInWithPassword(
        email: syntheticEmail,
        password: password,
      );
      return;
    } catch (signInError) {
      // Also try legacy synthetic email domain for previously claimed staff accounts
      if (!isEmail) {
        try {
          await _client.auth.signInWithPassword(
            email: '$normalizedIdentifier@staff.serviceflow.app',
            password: password,
          );
          return;
        } catch (_) {}
      }

      final signInMessage = signInError.toString().toLowerCase();
      final canAttemptClaim =
          signInMessage.contains('invalid login credentials') ||
          signInMessage.contains('email not confirmed') ||
          signInMessage.contains('user not found') ||
          signInMessage.contains('invalid_credentials');

      if (!canAttemptClaim) {
        rethrow;
      }
    }

    try {
      await _client.auth.signUp(email: syntheticEmail, password: password);
    } catch (signUpError) {
      final message = signUpError.toString().toLowerCase();
      final emailRateLimited =
          message.contains('over_email_send_rate_limit') ||
          message.contains('email rate limit exceeded');
      final alreadyExists =
          message.contains('user already registered') ||
          message.contains('already been registered');
      final invalidEmail =
          message.contains('email_address_invalid') ||
          message.contains('is invalid');
      if (emailRateLimited || invalidEmail) {
        throw StateError(
          'Supabase menolak pendaftaran otomatis staf karena "Confirm email" masih aktif. Nonaktifkan "Confirm email" di Supabase Dashboard (Authentication > Providers > Email) lalu coba lagi.',
        );
      }
      if (!alreadyExists) {
        rethrow;
      }
    }

    if (_client.auth.currentSession == null) {
      await _client.auth.signInWithPassword(
        email: syntheticEmail,
        password: password,
      );
    }

    await _client.rpc(
      'claim_staff_invitation',
      params: {
        'target_identifier': normalizedIdentifier,
        'target_initial_password': password,
      },
    );
  }

  Future<AppProfile?> fetchCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    // Coba ambil dari tabel profiles dengan polling/retry singkat (menunggu trigger database Postgres selesai)
    for (int attempt = 0; attempt < 4; attempt++) {
      try {
        final response = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (response != null) {
          return AppProfile.fromMap(response);
        }
      } catch (e) {
        debugPrint('[fetchCurrentProfile] attempt $attempt error: $e');
        if (SupabaseService.isLikelyTransientNetworkError(e) ||
            e.toString().toLowerCase().contains('socketexception') ||
            e.toString().toLowerCase().contains('failed host lookup') ||
            e.toString().toLowerCase().contains('clientexception') ||
            e.toString().toLowerCase().contains('timed out')) {
          break;
        }
      }
      await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
    }

    // Jika trigger on_auth_user_created di database terlambat atau belum selesai,
    // langsung sinkronkan profile dari metadata user agar alur auth tidak tertunda
    final fullName = user.userMetadata?['full_name'] as String? ??
        user.userMetadata?['name'] as String? ??
        user.email?.split('@').first ??
        'User';
    final avatarUrl = user.userMetadata?['avatar_url'] as String?;
    final fallbackProfile = {
      'id': user.id,
      'email': user.email,
      'phone': user.phone,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'role': 'owner',
    };

    try {
      final upserted = await _client
          .from('profiles')
          .upsert(fallbackProfile, onConflict: 'id')
          .select()
          .single();
      return AppProfile.fromMap(upserted);
    } catch (e) {
      debugPrint('[fetchCurrentProfile] fallback upsert warning: $e');
    }

    return AppProfile(
      id: user.id,
      email: user.email,
      fullName: fullName,
      phone: user.phone,
      avatarUrl: avatarUrl,
      defaultRole: AppRole.owner,
      isActive: true,
      onboardingCompleted: false,
    );
  }

  Future<Business?> fetchOwnedBusiness() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    final response = await _client
        .from('businesses')
        .select('*, subscription_plans(*)')
        .eq('owner_user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    final businessType = response['business_type'] as String?;
    if (businessType != null) {
      final templateResponse = await _client
          .from('business_type_templates')
          .select('role_labels, features_config, limits_config')
          .eq('code', businessType)
          .maybeSingle();
      if (templateResponse != null) {
        response['role_labels'] = templateResponse['role_labels'];
        response['features_config'] = templateResponse['features_config'];
        response['limits_config'] = templateResponse['limits_config'];
      }
    }

    return Business.fromMap(response);
  }

  Future<BusinessMember?> fetchOwnerMembership(String businessId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    final response = await _client
        .from('business_members')
        .select()
        .eq('business_id', businessId)
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }
    return BusinessMember.fromMap(response);
  }

  Future<BusinessMember?> fetchActiveMembership() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    final response = await _client
        .from('business_members')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();

    if (response == null) {
      return null;
    }
    return BusinessMember.fromMap(response);
  }

  Future<Business?> fetchBusinessById(String businessId) async {
    final response = await _client
        .from('businesses')
        .select('*, subscription_plans(*)')
        .eq('id', businessId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    final businessType = response['business_type'] as String?;
    if (businessType != null) {
      final templateResponse = await _client
          .from('business_type_templates')
          .select('role_labels, features_config, limits_config')
          .eq('code', businessType)
          .maybeSingle();
      if (templateResponse != null) {
        response['role_labels'] = templateResponse['role_labels'];
        response['features_config'] = templateResponse['features_config'];
        response['limits_config'] = templateResponse['limits_config'];
      }
    }

    return Business.fromMap(response);
  }
}
