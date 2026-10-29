/// Konfigurasi Google Maps & Google Places API
///
/// Untuk mengaktifkan layanan ini di Google Cloud Console:
/// 1. Buka https://console.cloud.google.com
/// 2. Masuk ke "APIs & Services" > "Library"
/// 3. Aktifkan:
///    - **Places API** (atau **Places API (New)**)
///    - **Geocoding API**
///    - **Maps SDK for Android** (opsional untuk peta visual native)
/// 4. Masuk ke "Credentials" > "Create Credentials" > "API Key"
/// 5. Masukkan kunci API ke variabel [apiKey] di bawah ini
///    atau passing via `--dart-define=GOOGLE_MAPS_API_KEY=AIzaSy...`
class GoogleMapsConfig {
  GoogleMapsConfig._();

  /// Google Maps & Places API Key
  static String apiKey = const String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyBJz3CrmMd25JeLm4HuMkCyR63lIX-3fjg',
  );

  /// Cek apakah API key sudah diisi
  static bool get hasApiKey => apiKey.trim().isNotEmpty;
}
