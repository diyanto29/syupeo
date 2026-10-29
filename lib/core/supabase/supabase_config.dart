class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://kjekiseloobdxomicolo.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtqZWtpc2Vsb29iZHhvbWljb2xvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA1OTM3OTMsImV4cCI6MjEwNjE2OTc5M30.csMbrT-zokTlb1SBplh_xRr9_Cpksk46OSJ0BQZTQB0';
  static const String googleWebClientId =
      '617929816223-g6fo9dk64r0nc20gnfaqiqjutlcjotuq.apps.googleusercontent.com';
  static const String googleIosClientId = '';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
  static bool get hasGoogleWebClientId => googleWebClientId.isNotEmpty;
}
