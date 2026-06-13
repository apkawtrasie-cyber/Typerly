import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
  }

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  static String get apiFootballKey => dotenv.env['API_FOOTBALL_KEY'] ?? '';
  static String get apiFootballBaseUrl =>
      dotenv.env['API_FOOTBALL_BASE_URL'] ?? '';

  static String get footballDataToken =>
      dotenv.env['FOOTBALL_DATA_TOKEN'] ?? '';
  
  static String get admobBannerIdAndroid =>
      dotenv.env['ADMOB_BANNER_ID_ANDROID'] ?? '';
  static String get admobBannerIdIOS =>
      dotenv.env['ADMOB_BANNER_ID_IOS'] ?? '';
  static String get admobInterstitialIdAndroid =>
      dotenv.env['ADMOB_INTERSTITIAL_ID_ANDROID'] ?? '';
  static String get admobInterstitialIdIOS =>
      dotenv.env['ADMOB_INTERSTITIAL_ID_IOS'] ?? '';
  
  static String get appName => dotenv.env['APP_NAME'] ?? 'Typerly';
  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';
}
