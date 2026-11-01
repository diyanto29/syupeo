class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://fgzmwmtssrviptflsjqy.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZnem13bXRzc3J2aXB0ZmxzanF5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA5MzE4ODIsImV4cCI6MjEwNjUwNzg4Mn0.hVmSWNVSmnBuQPt7KvlKk6g9qJbtFUD0F1WeeaAI34s';
  static const String googleWebClientId =
      '384714806025-kiscrufjnkd5i603irmcjff2lmfa72ik.apps.googleusercontent.com';
  static const String googleIosClientId = '';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
  static bool get hasGoogleWebClientId => googleWebClientId.isNotEmpty;
}
